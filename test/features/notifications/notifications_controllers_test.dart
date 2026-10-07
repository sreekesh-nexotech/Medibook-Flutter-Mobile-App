import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/api_client.dart' show Page;
import 'package:medibook/core/network/realtime/ws_client.dart';
import 'package:medibook/features/notifications/application/providers/notifications_provider.dart';
import 'package:medibook/features/notifications/domain/entities/notification.dart';
import 'package:medibook/features/notifications/domain/entities/push_device.dart';

import 'support/fixtures.dart';

/// The list controller (read state comes from the server's answer), the
/// inbox owner (badge from REST then socket frames) and push registration.
void main() {
  late FakeNotificationsRepository repository;
  late ProviderContainer container;
  const query = NotificationListQuery();

  setUp(() {
    repository = FakeNotificationsRepository();
    container = ProviderContainer(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('NotificationsListController', () {
    test('loads the first page', () async {
      repository.pages.add(
        Page(
          results: [NotificationFixtures.notification()],
          page: 1,
          pageSize: 25,
          total: 1,
          hasNext: false,
        ),
      );
      final sub = container.listen(
        notificationsListProvider(query),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await container.read(notificationsListProvider(query).notifier).load();
      expect(sub.read().items, hasLength(1));
      expect(sub.read().unreadInList, 1);
      expect(sub.read().isLoading, isFalse);
    });

    // BL-NOTIF-009: on the Unread tab a read row stayed until a reload.
    test(
      'on the Unread tab a notification marked read leaves the list',
      () async {
        const unreadOnly = NotificationListQuery(unread: true);
        repository.pages.add(
          Page(
            results: [NotificationFixtures.notification()],
            page: 1,
            pageSize: 25,
            total: 1,
            hasNext: false,
          ),
        );
        final sub = container.listen(
          notificationsListProvider(unreadOnly),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);
        final notifier = container.read(
          notificationsListProvider(unreadOnly).notifier,
        );
        await notifier.load();
        expect(sub.read().items, hasLength(1));

        await notifier.markRead(NotificationFixtures.id);

        expect(sub.read().items, isEmpty);
        expect(sub.read().total, 0);
      },
    );

    test('markRead replaces the row with the server answer', () async {
      repository.pages.add(
        Page(
          results: [NotificationFixtures.notification()],
          page: 1,
          pageSize: 25,
          total: 1,
          hasNext: false,
        ),
      );
      final sub = container.listen(
        notificationsListProvider(query),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      final notifier = container.read(
        notificationsListProvider(query).notifier,
      );
      await notifier.load();
      final failure = await notifier.markRead(NotificationFixtures.id);
      expect(failure, isNull);
      expect(repository.readIds, [NotificationFixtures.id]);
      expect(sub.read().items.single.read, isTrue);
      expect(sub.read().busyIds, isEmpty);
    });

    test(
      'a failed mutation leaves the row untouched and returns the failure',
      () async {
        repository.pages.add(
          Page(
            results: [NotificationFixtures.notification()],
            page: 1,
            pageSize: 25,
            total: 1,
            hasNext: false,
          ),
        );
        final sub = container.listen(
          notificationsListProvider(query),
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);
        final notifier = container.read(
          notificationsListProvider(query).notifier,
        );
        await notifier.load();
        repository.mutationFailure = const NetworkFailure();
        final failure = await notifier.dismiss(NotificationFixtures.id);
        expect(failure, isA<NetworkFailure>());
        expect(sub.read().items, hasLength(1));
      },
    );

    test('dismiss removes the row only after the server agreed', () async {
      repository.pages.add(
        Page(
          results: [NotificationFixtures.notification()],
          page: 1,
          pageSize: 25,
          total: 1,
          hasNext: false,
        ),
      );
      final sub = container.listen(
        notificationsListProvider(query),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      final notifier = container.read(
        notificationsListProvider(query).notifier,
      );
      await notifier.load();
      expect(await notifier.dismiss(NotificationFixtures.id), isNull);
      expect(repository.dismissedIds, [NotificationFixtures.id]);
      expect(sub.read().items, isEmpty);
      expect(sub.read().total, 0);
    });

    test('markAllRead reports updated_count and flips the rows', () async {
      repository.pages.add(
        Page(
          results: [
            NotificationFixtures.notification(id: 'a'),
            NotificationFixtures.notification(
              id: 'b',
              readAt: '2026-09-30T08:09:50Z',
            ),
          ],
          page: 1,
          pageSize: 25,
          total: 2,
          hasNext: false,
        ),
      );
      repository.readAllResult = 1;
      final sub = container.listen(
        notificationsListProvider(query),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      final notifier = container.read(
        notificationsListProvider(query).notifier,
      );
      await notifier.load();
      final result = await notifier.markAllRead();
      expect(result.updated, 1);
      expect(result.failure, isNull);
      expect(sub.read().unreadInList, 0);
    });

    test('a list failure is an error state', () async {
      repository.listFailure = const ServerFailure();
      final sub = container.listen(
        notificationsListProvider(query),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      await container.read(notificationsListProvider(query).notifier).load();
      expect(sub.read().failure, isA<ServerFailure>());
    });
  });

  group('InboxController', () {
    late List<FakeInboxSocket> sockets;

    setUp(() => sockets = []);

    InboxController build({bool enabled = true}) => InboxController(
      repository: repository,
      openSocket: (path) {
        final socket = FakeInboxSocket(path);
        sockets.add(socket);
        return socket;
      },
      refreshSession: () async {},
      enabled: enabled,
    );

    test('fetches the unread count and opens the inbox socket', () async {
      repository.unreadCountValue = 3;
      final inbox = build();
      addTearDown(inbox.dispose);
      await settle();
      expect(inbox.state.unreadCount, 3);
      expect(sockets.single.path, '/ws/patient/inbox');
      expect(inbox.state.isLive, isTrue);
    });

    // Checklist PERF-008: in the background the socket is closed and the
    // server's idle drops are not retried; returning reconnects and re-reads.
    test(
      'pause closes the socket and stops retrying; resume reconnects',
      () async {
        repository.unreadCountValue = 3;
        final inbox = build();
        addTearDown(inbox.dispose);
        await settle();
        final calls = repository.unreadCountCalls;

        inbox.pause();
        await settle();
        expect(sockets.single.disposed, isTrue);
        expect(inbox.state.isLive, isFalse);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(sockets, hasLength(1), reason: 'no reconnect in the background');

        inbox.resume();
        await settle();
        expect(sockets, hasLength(2));
        expect(inbox.state.isLive, isTrue);
        expect(repository.unreadCountCalls, greaterThan(calls));
      },
    );

    test('does nothing while signed out', () async {
      final inbox = build(enabled: false);
      addTearDown(inbox.dispose);
      await settle();
      expect(repository.unreadCountCalls, 0);
      expect(sockets, isEmpty);
      expect(inbox.state.unreadCount, 0);
    });

    test(
      'unread_count frames drive the badge; notification.created bumps it',
      () async {
        final inbox = build();
        addTearDown(inbox.dispose);
        await settle();
        sockets.single.emit('unread_count', {'n': 4});
        await settle();
        expect(inbox.state.unreadCount, 4);
        sockets.single.emit('notification.created', {
          'id': 'n-9',
          'kind': 'reminder',
          'title': 'Reminder',
        });
        await settle();
        expect(inbox.state.unreadCount, 5);
        expect(inbox.state.lastCreatedId, 'n-9');
      },
    );

    test('a count that failed to load offline is re-read when the device '
        'is back online', () async {
      repository.unreadCountFailure = const NetworkFailure();
      final inbox = build();
      addTearDown(inbox.dispose);
      await settle();
      expect(inbox.state.unreadCount, 0);
      expect(inbox.state.failure, isA<NetworkFailure>());

      repository
        ..unreadCountFailure = null
        ..unreadCountValue = 33;
      inbox.resume();
      await settle();

      expect(inbox.state.unreadCount, 33);
      expect(inbox.state.failure, isNull);
      // The socket was already up: resume re-reads, it does not reconnect.
      expect(sockets, hasLength(1));
    });

    test(
      'a reconnect after a drop re-reads the count the socket missed',
      () async {
        repository.unreadCountValue = 2;
        final inbox = build();
        addTearDown(inbox.dispose);
        await settle();
        expect(repository.unreadCountCalls, 1);

        sockets.first.close(WsCloseReason.unauthorized);
        repository.unreadCountValue = 5;
        await settle();
        await settle();

        expect(sockets, hasLength(2));
        expect(inbox.state.isLive, isTrue);
        expect(inbox.state.unreadCount, 5);
      },
    );

    test('a 4401 reconnects with a fresh socket', () async {
      final inbox = build();
      addTearDown(inbox.dispose);
      await settle();
      sockets.first.close(WsCloseReason.unauthorized);
      await settle();
      await settle();
      expect(sockets, hasLength(2));
      expect(sockets.first.disposed, isTrue);
    });

    test('the unread-count provider follows the inbox', () async {
      repository.unreadCountValue = 2;
      final scoped = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(repository),
          inboxProvider.overrideWith((ref) => build()),
        ],
      );
      addTearDown(scoped.dispose);
      final sub = scoped.listen(unreadNotificationCountProvider, (_, _) {});
      addTearDown(sub.close);
      await settle();
      expect(sub.read(), 2);
      scoped.read(inboxProvider.notifier).adjust(-1);
      expect(sub.read(), 1);
      scoped.read(inboxProvider.notifier).adjust(-5);
      expect(sub.read(), 0, reason: 'never negative');
    });
  });

  group('PushDeviceController', () {
    test('register stores the device id; unregister deletes it', () async {
      final sub = container.listen(pushDeviceProvider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(pushDeviceProvider.notifier);
      final failure = await notifier.register(
        platform: DevicePlatform.android,
        pushToken: 'fcm-token',
        appVersion: '1.0.0',
      );
      expect(failure, isNull);
      expect(sub.read().deviceId, 'dev-1');
      expect(repository.registeredTokens, ['fcm-token']);

      await notifier.unregister();
      expect(repository.deletedDevices, ['dev-1']);
      expect(sub.read().deviceId, isNull);
    });
  });
}
