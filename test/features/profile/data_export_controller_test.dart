import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/profile/application/providers/data_export_provider.dart';
import 'package:medibook/features/profile/domain/entities/account.dart';
import 'package:medibook/features/profile/infrastructure/repositories/profile_mappers.dart';

import 'profile_test_support.dart';

/// "Download my data" (§5.7): `POST`/`GET /patient/me/data-exports` and the
/// signed download link.
void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;

  setUp(() {
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
  });

  group('DataExportController', () {
    test('request mints one Idempotency-Key, reuses it on retry, clears it on '
        'success and puts the new request first', () async {
      profile.exportRows = [
        DataExportRequest(
          id: 'dsr-old',
          requestNo: 'DSR-2026-0001',
          status: DataExportStatus.completed,
          requestedAt: DateTime.utc(2026, 9, 29),
          completedAt: DateTime.utc(2026, 9, 29),
        ),
      ];
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
      );
      addTearDown(container.dispose);
      keepAlive(container, dataExportsProvider);
      keepAlive(container, dataExportControllerProvider);
      await settle();
      expect(container.read(openDataExportProvider), isNull);

      final notifier = container.read(dataExportControllerProvider.notifier);
      profile.nextFailure = const TimeoutFailure();
      expect(await notifier.request(), isA<TimeoutFailure>());
      expect(
        container.read(dataExportControllerProvider).idempotencyKey,
        isNotNull,
      );

      expect(await notifier.request(), isNull);

      expect(profile.idempotencyKeys, hasLength(2));
      expect(profile.idempotencyKeys.first, profile.idempotencyKeys.last);
      final state = container.read(dataExportControllerProvider);
      expect(state.idempotencyKey, isNull);
      expect(state.isBusy, isFalse);
      expect(container.read(dataExportsProvider).value?.map((r) => r.id), [
        'dsr-new',
        'dsr-old',
      ]);
      // The new request is open, so the screen stops offering another.
      expect(
        container.read(openDataExportProvider)?.requestNo,
        'DSR-2026-0002',
      );
    });

    test(
      'a second request while one is open is the server\'s STATE_CONFLICT',
      () async {
        final container = await authenticatedContainer(
          auth: auth,
          profile: profile,
        );
        addTearDown(container.dispose);
        keepAlive(container, dataExportControllerProvider);
        profile.nextFailure = const ConflictFailure(
          apiCode: ApiErrorCodes.stateConflict,
        );

        final failure = await container
            .read(dataExportControllerProvider.notifier)
            .request();

        expect(failure?.apiCode, ApiErrorCodes.stateConflict);
      },
    );

    test('link returns the signed URL; an expired file is a NotFoundFailure '
        'on the state', () async {
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
      );
      addTearDown(container.dispose);
      keepAlive(container, dataExportControllerProvider);
      final notifier = container.read(dataExportControllerProvider.notifier);

      final link = await notifier.link('dsr-old');
      expect(link?.url, 'https://files.example/dsr-old.zip');
      expect(container.read(dataExportControllerProvider).linkingId, isNull);

      profile.nextFailure = const NotFoundFailure(
        apiCode: ApiErrorCodes.notFound,
      );
      expect(await notifier.link('dsr-old'), isNull);
      final state = container.read(dataExportControllerProvider);
      expect(state.failure, isA<NotFoundFailure>());
      expect(state.isBusy, isFalse);
    });
  });

  group('ProfileMappers — data exports', () {
    // The body staging returned on 2026-10-01 for GET /patient/me/data-exports.
    const row = <String, Object?>{
      'id': '01a0ee2f-b3d6-73d3-a3c5-13e908e5eefb',
      'request_no': 'DSR-2026-0001',
      'kind': 'export',
      'status': 'completed',
      'requested_at': '2026-09-29T17:21:38.767523Z',
      'due_at': '2026-10-29T17:21:38.767523Z',
      'completed_at': '2026-09-29T17:21:38.800738Z',
    };

    test('a page of requests maps to entities', () {
      final rows = ProfileMappers.dataExports({
        'results': [row],
        'page': 1,
        'page_size': 25,
        'total': 1,
        'has_next': false,
      });

      expect(rows, hasLength(1));
      final request = rows.single;
      expect(request.id, '01a0ee2f-b3d6-73d3-a3c5-13e908e5eefb');
      expect(request.requestNo, 'DSR-2026-0001');
      expect(request.status, DataExportStatus.completed);
      expect(request.isReady, isTrue);
      expect(request.isOpen, isFalse);
      expect(request.dueAt, DateTime.utc(2026, 10, 29, 17, 21, 38, 767, 523));
    });

    test('requested / verifying / processing are open; the rest are not', () {
      for (final status in DataExportStatus.values) {
        final request = ProfileMappers.dataExport({
          ...row,
          'status': status.wire,
        });
        expect(
          request.isOpen,
          status == DataExportStatus.requested ||
              status == DataExportStatus.verifying ||
              status == DataExportStatus.processing,
          reason: status.wire,
        );
      }
    });

    test('a row without an id is refused, not half-mapped', () {
      expect(
        () => ProfileMappers.dataExport({...row, 'id': null}),
        throwsA(isA<ResponseFormatException>()),
      );
    });

    test('the download link keeps both expiries', () {
      final link = ProfileMappers.dataExportLink({
        'url': 'https://storage.example/DSR-2026-0001.zip?X-Expires=600',
        'expires_at': '2026-10-01T13:13:08.701894+00:00',
        'file_expires_at': '2026-10-06T17:21:40.160738+00:00',
        'request_no': 'DSR-2026-0001',
      });

      expect(link.url, startsWith('https://storage.example/'));
      expect(link.requestNo, 'DSR-2026-0001');
      expect(link.fileExpiresAt!.isAfter(link.expiresAt!), isTrue);
      expect(
        () => ProfileMappers.dataExportLink({'url': ''}),
        throwsA(isA<ResponseFormatException>()),
      );
    });
  });
}
