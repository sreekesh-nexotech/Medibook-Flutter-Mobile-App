import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/features/common/pagination/domain/entities/paged.dart';
import 'package:medibook/features/common/persons/application/providers/persons_read_provider.dart';
import 'package:medibook/features/common/persons/domain/entities/person_summary.dart';
import 'package:medibook/features/common/persons/domain/repositories/persons_read_repository.dart';
import 'package:medibook/features/records/application/providers/records_provider.dart';
import 'package:medibook/features/records/application/providers/linkable_appointments_provider.dart';
import 'package:medibook/features/records/domain/entities/medical_document.dart';
import 'package:medibook/features/records/presentation/screen/records_screen.dart';

import '../../support/harness.dart';
import 'documents_controllers_test.dart';

/// The Records tab renders each list state from the controller: skeleton,
/// the empty state, the error view with retry, and the content with the
/// stale bar.
void main() {
  late FakeDocumentsRepository repository;

  setUp(() {
    repository = FakeDocumentsRepository();
  });

  // The tab sits in the shell's Scaffold in the app.
  Widget screen({bool online = true}) => screenHarness(
    const Scaffold(body: RecordsScreen()),
    overrides: [
      documentsRepositoryProvider.overrideWithValue(repository),
      personsReadRepositoryProvider.overrideWithValue(_FakePersons()),
      isOnlineProvider.overrideWith((ref) => Stream.value(online)),
      linkableAppointmentsProvider.overrideWithValue(const []),
    ],
  );

  Future<Snapshot<Paged<MedicalDocument>>> savedPage() async => Snapshot(
    value: Paged(
      items: [await repository.document('a')],
      page: 1,
      pageSize: 20,
      total: 1,
      hasNext: false,
    ),
    cachedAt: DateTime.now(),
    fromCache: true,
  );

  // Offline with the saved page on screen: the offline note says it all; the
  // failed refresh adds no second, red "you appear to be offline".
  testWidgets(
    'offline with the saved list shows no note of its own (the app bar says it)',
    (tester) async {
      repository.snapshots = [await savedPage()];
      repository.errorAfterSnapshots = const NetworkFailure();
      await tester.pumpWidget(screen(online: false));
      await tester.pump();
      await tester.pump();
      // The app-wide OfflineBar says it; the screen adds no note of its own.
      expect(
        find.text('You are offline — showing your saved records'),
        findsNothing,
      );
      expect(find.textContaining('appear to be offline'), findsNothing);
      expect(find.text('Doc a'), findsOneWidget);
    },
  );

  testWidgets('online, a failed refresh over a saved list still says so', (
    tester,
  ) async {
    repository.snapshots = [await savedPage()];
    repository.errorAfterSnapshots = const ServerFailure();
    await tester.pumpWidget(screen());
    await tester.pump();
    await tester.pump();
    expect(find.text(const ServerFailure().userMessage), findsOneWidget);
    expect(find.text('Doc a'), findsOneWidget);
  });

  testWidgets('empty library shows the empty state with Add record', (
    tester,
  ) async {
    repository.snapshots = [
      Snapshot(value: const Paged.empty(), cachedAt: DateTime.now()),
    ];
    await tester.pumpWidget(screen());
    await tester.pump();
    await tester.pump();
    expect(find.text('No records yet'), findsOneWidget);
    expect(find.text('Add record'), findsOneWidget);
  });

  // BL-REC-016 (owner decision): Records can be searched by title.
  testWidgets('a title search with no match says so and can be cleared', (
    tester,
  ) async {
    repository.snapshots = [
      Snapshot(value: const Paged.empty(), cachedAt: DateTime.now()),
    ];
    await tester.pumpWidget(screen());
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'zebra');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(repository.watchedQueries.last.search, 'zebra');
    expect(find.text('Search results'), findsOneWidget);
    expect(find.textContaining('“zebra”'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pump();
    await tester.pump();

    expect(repository.watchedQueries.last.search, isNull);
    expect(find.text('zebra'), findsNothing, reason: 'the box is emptied too');
    expect(find.text('No records yet'), findsOneWidget);
  });

  testWidgets('a failed load with no data shows the error view', (
    tester,
  ) async {
    repository.watchError = const NetworkFailure();
    await tester.pumpWidget(screen());
    await tester.pump();
    await tester.pump();
    expect(find.text('We could not load your records'), findsOneWidget);
  });

  testWidgets('a stale cached page shows the amber refresh bar', (
    tester,
  ) async {
    repository.snapshots = [
      Snapshot(
        value: Paged(
          items: [for (var i = 0; i < 1; i++) (await repository.document('a'))],
          page: 1,
          pageSize: 20,
          total: 1,
          hasNext: false,
        ),
        cachedAt: DateTime.now().subtract(const Duration(days: 2)),
        fromCache: true,
        isStale: true,
      ),
    ];
    await tester.pumpWidget(screen());
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Tap to refresh'), findsOneWidget);
    expect(find.text('Doc a'), findsOneWidget);
    expect(find.text('1 record'), findsOneWidget);
  });
}

class _FakePersons implements PersonsReadRepository {
  @override
  Future<List<PersonSummary>> persons({bool forceRefresh = false}) async =>
      const [
        PersonSummary(
          id: 'p1',
          firstName: 'Test',
          relation: 'other',
          isSelf: false,
        ),
      ];
}
