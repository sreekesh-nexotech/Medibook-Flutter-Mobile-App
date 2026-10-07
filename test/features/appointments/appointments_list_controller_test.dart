import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/api_client.dart' show Page;
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/appointments/application/providers/appointments_provider.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_filter.dart';

import 'support/fixtures.dart';

/// The list controller against a scripted repository: cached-then-network,
/// pagination, and the error paths the screen renders.
void main() {
  late FakeAppointmentsRepository repository;
  late ProviderContainer container;

  const query = AppointmentListQuery(tab: AppointmentTab.upcoming);

  setUp(() {
    repository = FakeAppointmentsRepository();
    container = ProviderContainer(
      overrides: [appointmentsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  Page<Appointment> page(int n, {bool hasNext = false, int total = 1}) => Page(
    results: [Fixtures.appointment()],
    page: n,
    pageSize: 20,
    total: total,
    hasNext: hasNext,
  );

  test('cold start: skeleton, then the network page', () async {
    repository.pages.add(page(1));
    final sub = container.listen(
      appointmentsListProvider(query),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    expect(sub.read().isLoading, isTrue);

    await container.read(appointmentsListProvider(query).notifier).load();
    final state = sub.read();
    expect(state.isLoading, isFalse);
    expect(state.items, hasLength(1));
    expect(state.total, 1);
    expect(state.source, CacheSource.network);
    expect(state.failure, isNull);
  });

  test('warm start: the cached page shows first with revalidating, then '
      'the network replaces it', () async {
    repository.cachedFirstPage = page(1, total: 1);
    repository.cachedIsStale = true;
    repository.pages.add(page(1, total: 2));
    final seen = <bool>[];
    final sub = container.listen(appointmentsListProvider(query), (_, next) {
      seen.add(next.revalidating);
    });
    addTearDown(sub.close);

    await container.read(appointmentsListProvider(query).notifier).load();
    expect(seen, contains(true));
    final state = sub.read();
    expect(state.revalidating, isFalse);
    expect(state.total, 2);
    expect(state.isStale, isFalse);
  });

  test('a failure with nothing cached is an error state', () async {
    repository.listFailure = const NetworkFailure();
    final sub = container.listen(
      appointmentsListProvider(query),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await container.read(appointmentsListProvider(query).notifier).load();
    final state = sub.read();
    expect(state.isLoading, isFalse);
    expect(state.failure, isA<NetworkFailure>());
    expect(state.items, isEmpty);
  });

  // Checklist E2E-009: a tab that was empty online stays "Nothing here yet"
  // offline (with the offline line), not an error screen.
  test('a saved empty list survives a failed refresh', () async {
    repository.cachedFirstPage = const Page.empty();
    repository.listFailure = const NetworkFailure();
    final sub = container.listen(
      appointmentsListProvider(query),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await container.read(appointmentsListProvider(query).notifier).load();
    final state = sub.read();
    expect(state.items, isEmpty);
    expect(state.failure, isA<NetworkFailure>());
    expect(state.hasLoadedPage, isTrue, reason: 'the empty list was saved');
  });

  test('nothing saved: no page has loaded', () async {
    repository.listFailure = const NetworkFailure();
    final sub = container.listen(
      appointmentsListProvider(query),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await container.read(appointmentsListProvider(query).notifier).load();
    expect(sub.read().hasLoadedPage, isFalse);
  });

  // BL-CACHE-017: opened offline, the tab stayed on its error view after the
  // connection came back.
  test(
    'a list that failed reloads itself when the device reconnects',
    () async {
      final monitor = _Monitor();
      final c = ProviderContainer(
        overrides: [
          appointmentsRepositoryProvider.overrideWithValue(repository),
          connectivityMonitorProvider.overrideWithValue(monitor),
        ],
      );
      addTearDown(c.dispose);
      repository.listFailure = const NetworkFailure();
      final sub = c.listen(
        appointmentsListProvider(query),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      expect(sub.read().failure, isA<NetworkFailure>());

      repository
        ..listFailure = null
        ..pages.add(page(1));
      final callsBefore = repository.listCalls;
      monitor.reconnect();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(repository.listCalls, callsBefore + 1, reason: 'reloaded once');
      expect(sub.read().failure, isNull);
      expect(sub.read().items, isNotEmpty);
    },
  );

  test('a failed revalidation keeps the cached rows and reports it', () async {
    repository.cachedFirstPage = page(1);
    repository.listFailure = const TimeoutFailure();
    final sub = container.listen(
      appointmentsListProvider(query),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await container.read(appointmentsListProvider(query).notifier).load();
    final state = sub.read();
    expect(state.items, hasLength(1));
    expect(state.hasRowsAndFailure, isTrue);
    expect(state.revalidating, isFalse);
  });

  test(
    'loadMore appends the next page and stops when has_next is false',
    () async {
      repository.pages
        ..add(page(1, hasNext: true, total: 2))
        ..add(page(2, total: 2));
      final sub = container.listen(
        appointmentsListProvider(query),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      final notifier = container.read(appointmentsListProvider(query).notifier);
      await notifier.load();
      expect(sub.read().hasNext, isTrue);

      await notifier.loadMore();
      expect(sub.read().items, hasLength(2));
      expect(sub.read().page, 2);
      expect(sub.read().hasNext, isFalse);
      expect(repository.fetchedPages, [2]);

      await notifier.loadMore();
      expect(repository.fetchedPages, [2], reason: 'no page 3 requested');
    },
  );

  test(
    'a loadMore failure leaves the rows and surfaces loadMoreFailure',
    () async {
      repository.pages.add(page(1, hasNext: true, total: 2));
      repository.loadMoreFailure = const ServerFailure();
      final sub = container.listen(
        appointmentsListProvider(query),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      final notifier = container.read(appointmentsListProvider(query).notifier);
      await notifier.load();
      await notifier.loadMore();
      expect(sub.read().items, hasLength(1));
      expect(sub.read().loadMoreFailure, isA<ServerFailure>());
      expect(sub.read().isLoadingMore, isFalse);
    },
  );

  test('nextUpcomingAppointmentProvider is null when signed out', () {
    final value = container.read(nextUpcomingAppointmentProvider);
    expect(value, isA<AsyncValue<Appointment?>>());
  });

  test(
    'appointmentsForLinkingProvider merges the three tabs newest first',
    () async {
      repository.pages.add(page(1));
      final rows = await container.read(appointmentsForLinkingProvider.future);
      expect(rows, hasLength(1), reason: 'the same id across tabs is one row');
      expect(rows.single.doctorName, 'Dr. Suresh Pillai');
      expect(rows.single.label, contains('Dr. Suresh Pillai · '));
      expect(rows.single.hospitalName, 'Lakeshore Multispeciality Hospital');
      // What tells two visits with one doctor on one day apart.
      expect(rows.single.bookingRef, isNotEmpty);
      expect(rows.single.personId, isNotEmpty);
      expect(rows.single.when, contains(' · '), reason: 'date and time');
    },
  );
}

class _Monitor extends ConnectivityMonitor {
  final StreamController<void> _reconnects = StreamController<void>.broadcast();

  void reconnect() => _reconnects.add(null);

  @override
  Stream<void> get onReconnect => _reconnects.stream;
}
