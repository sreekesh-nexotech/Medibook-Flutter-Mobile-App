import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';
import 'package:medibook/features/auth/domain/entities/user.dart';
import 'package:medibook/features/profile/application/providers/account_deletion_provider.dart';
import 'package:medibook/features/profile/application/providers/profile_mutations_provider.dart';
import 'package:medibook/features/profile/application/providers/profile_provider.dart';
import 'package:medibook/features/profile/domain/entities/account.dart';

import 'profile_test_support.dart';

/// Delete account (§5.6), consents (§5.9) and sessions (§4.9).
void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;

  setUp(() {
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
  });

  group('AccountDeletionController', () {
    test('request mints one Idempotency-Key, reuses it on retry, clears it on '
        'success', () async {
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        accountDeletionControllerProvider.notifier,
      );
      profile.nextFailure = const TimeoutFailure();

      expect(await notifier.request(reason: 'moving'), isA<TimeoutFailure>());
      final keyAfterFailure = container
          .read(accountDeletionControllerProvider)
          .idempotencyKey;
      expect(keyAfterFailure, isNotNull);

      auth.user = testUser.copyWith(status: UserStatus.pendingDeletion);
      expect(await notifier.request(reason: 'moving'), isNull);

      expect(profile.idempotencyKeys, hasLength(2));
      expect(profile.idempotencyKeys.first, profile.idempotencyKeys.last);
      final state = container.read(accountDeletionControllerProvider);
      expect(state.idempotencyKey, isNull);
      expect(state.lastRequest?.requestNo, 'DSR-2026-000001');
      // /me was re-read: the session user is now pending deletion.
      expect(container.read(currentUserProvider)?.isPendingDeletion, isTrue);
    });

    test(
      'a second request while one is open is the server\'s STATE_CONFLICT',
      () async {
        final container = await authenticatedContainer(
          auth: auth,
          profile: profile,
        );
        addTearDown(container.dispose);
        profile.nextFailure = const ConflictFailure(
          apiCode: ApiErrorCodes.stateConflict,
        );

        final failure = await container
            .read(accountDeletionControllerProvider.notifier)
            .request();

        expect(failure?.apiCode, ApiErrorCodes.stateConflict);
      },
    );

    test('withdraw and reactivate bring the account back', () async {
      auth.user = testUser.copyWith(status: UserStatus.pendingDeletion);
      profile.deletionRows = [
        DeletionRequest(
          requestNo: 'DSR-1',
          status: DeletionStatus.coolingOff,
          requestedAt: DateTime.now(),
        ),
      ];
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
      );
      addTearDown(container.dispose);
      keepAlive(container, deletionRequestsProvider);
      await settle();
      expect(container.read(openDeletionRequestProvider)?.requestNo, 'DSR-1');

      final notifier = container.read(
        accountDeletionControllerProvider.notifier,
      );
      expect(await notifier.withdraw('DSR-1'), isNull);
      expect(container.read(openDeletionRequestProvider), isNull);

      expect(await notifier.reactivate(), isNull);
      expect(container.read(currentUserProvider)?.status, UserStatus.active);
      expect(
        profile.calls,
        containsAll(['withdrawDeletion:DSR-1', 'reactivate']),
      );
    });
  });

  group('ConsentController', () {
    test('accepts every pending document at its current version', () async {
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
      );
      addTearDown(container.dispose);
      keepAlive(container, consentsProvider);
      await settle();

      final failure = await container
          .read(consentControllerProvider.notifier)
          .acceptAll(const [
            PendingConsent(
              slug: 'terms',
              currentVersion: 3,
              acceptedVersion: 2,
            ),
            PendingConsent(slug: 'guidelines', currentVersion: 1),
          ]);

      expect(failure, isNull);
      expect(profile.calls, [
        'acceptConsent:terms:3',
        'acceptConsent:guidelines:1',
      ]);
      final rows = container.read(consentsProvider).value!;
      expect(
        rows.map((c) => c.documentSlug),
        containsAll(['terms', 'guidelines']),
      );
    });
  });

  group('SessionsController', () {
    test('revoke drops the session from the list', () async {
      profile.sessionRows = const [
        AccountSession(id: 's-current', isCurrent: true),
        AccountSession(
          id: 's-other',
          isCurrent: false,
          userAgent: 'curl/8.7.1',
        ),
      ];
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
      );
      addTearDown(container.dispose);
      keepAlive(container, sessionsProvider);
      await settle();

      final failure = await container
          .read(sessionsControllerProvider.notifier)
          .revoke('s-other');

      expect(failure, isNull);
      expect(container.read(sessionsProvider).value?.map((s) => s.id), [
        's-current',
      ]);
    });

    test('a 404 on a dead session is a NotFoundFailure', () async {
      profile.sessionRows = const [
        AccountSession(id: 's-other', isCurrent: false),
      ];
      profile.nextFailure = const NotFoundFailure(
        apiCode: ApiErrorCodes.notFound,
      );
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
      );
      addTearDown(container.dispose);
      keepAlive(container, sessionsProvider);
      await settle();

      final failure = await container
          .read(sessionsControllerProvider.notifier)
          .revoke('s-other');

      expect(failure, isA<NotFoundFailure>());
    });
  });
}
