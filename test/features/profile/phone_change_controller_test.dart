import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';
import 'package:medibook/features/profile/application/providers/phone_change_provider.dart';
import 'package:medibook/features/profile/application/providers/release_provider.dart';
import 'package:medibook/features/profile/application/states/phone_change_state.dart';
import 'package:medibook/features/profile/application/states/release_state.dart';
import 'package:medibook/features/profile/domain/entities/person.dart';

import 'profile_test_support.dart';

/// The three-call phone change (§5.3) and the two-call release (§5.8).
void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;

  setUp(() {
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
  });

  group('PhoneChangeController', () {
    test(
      'walks start → confirm-old → verify-new and updates the user',
      () async {
        final container = await authenticatedContainer(
          auth: auth,
          profile: profile,
        );
        addTearDown(container.dispose);
        final notifier = container.read(phoneChangeControllerProvider.notifier);

        expect(await notifier.start('+919812345678'), isNull);
        var state = container.read(phoneChangeControllerProvider);
        expect(state.step, PhoneChangeStep.confirmOld);
        expect(state.challenge?.challengeId, 'old-challenge');
        expect(state.challenge?.destinationMasked, '+91******90');
        expect(state.deadline, isNotNull);

        expect(await notifier.confirmOld('1234'), isNull);
        state = container.read(phoneChangeControllerProvider);
        expect(state.step, PhoneChangeStep.verifyNew);
        expect(state.challenge?.challengeId, 'new-challenge');

        expect(await notifier.verifyNew('5678'), isNull);
        state = container.read(phoneChangeControllerProvider);
        expect(state.step, PhoneChangeStep.done);
        expect(container.read(currentUserProvider)?.phoneE164, '+919812345678');
        expect(container.read(currentUserProvider)?.version, 3);
        expect(profile.calls, [
          'startPhoneChange',
          'confirmOldPhone:old-challenge:1234',
          'verifyNewPhone:new-challenge:5678',
        ]);
      },
    );

    test('a wrong code keeps the step and records attempts', () async {
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
      );
      addTearDown(container.dispose);
      final notifier = container.read(phoneChangeControllerProvider.notifier);
      await notifier.start('+919812345678');
      profile.nextFailure = const UnauthorizedFailure(
        sessionExpired: false,
        apiCode: ApiErrorCodes.authOtpInvalid,
        meta: {'attempts_remaining': 2},
      );

      final failure = await notifier.confirmOld('0000');

      expect(failure, isA<UnauthorizedFailure>());
      final state = container.read(phoneChangeControllerProvider);
      expect(state.step, PhoneChangeStep.confirmOld);
      expect(state.attemptsRemaining, 2);
      expect(state.isBusy, isFalse);
    });

    test('an expired code sends the user back to the number step', () async {
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
      );
      addTearDown(container.dispose);
      final notifier = container.read(phoneChangeControllerProvider.notifier);
      await notifier.start('+919812345678');
      profile.nextFailure = const UnauthorizedFailure(
        sessionExpired: false,
        apiCode: ApiErrorCodes.authOtpExpired,
      );

      await notifier.confirmOld('1234');

      expect(
        container.read(phoneChangeControllerProvider).step,
        PhoneChangeStep.enterNumber,
      );
    });

    test(
      'a 400 on new_phone_e164 is a validation failure on that field',
      () async {
        final container = await authenticatedContainer(
          auth: auth,
          profile: profile,
        );
        addTearDown(container.dispose);
        profile.nextFailure = const ValidationFailure(
          fieldErrors: {'new_phone_e164': 'This is already your number.'},
        );

        final failure = await container
            .read(phoneChangeControllerProvider.notifier)
            .start('+919705571090');

        expect(failure, isA<ValidationFailure>());
        expect(
          (failure! as ValidationFailure).forField('new_phone_e164'),
          'This is already your number.',
        );
        expect(
          container.read(phoneChangeControllerProvider).step,
          PhoneChangeStep.enterNumber,
        );
      },
    );

    test('resend replaces the challenge through the auth repository', () async {
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
      );
      addTearDown(container.dispose);
      final notifier = container.read(phoneChangeControllerProvider.notifier);
      await notifier.start('+919812345678');

      expect(await notifier.resend(), isNull);
      expect(
        container.read(phoneChangeControllerProvider).challenge?.challengeId,
        'resent-old-challenge',
      );
    });
  });

  group('ReleaseController', () {
    final adult = Person(
      id: 'p-adult',
      firstName: 'Meera',
      relation: PersonRelation.child,
      dateOfBirth: DateTime(2000, 1, 1),
    );

    test('start → verify removes the person from the list', () async {
      final family = FakeFamilyRepository(rows: [adult]);
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
        family: family,
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        releaseControllerProvider('p-adult').notifier,
      );

      expect(await notifier.start('+919812345678'), isNull);
      expect(
        container.read(releaseControllerProvider('p-adult')).step,
        ReleaseStep.verify,
      );
      expect(family.idempotencyKeys, hasLength(1));

      expect(await notifier.verify('1234'), isNull);
      final state = container.read(releaseControllerProvider('p-adult'));
      expect(state.step, ReleaseStep.done);
      expect(state.result?.movedAppointments, 2);
    });

    // BL-FAM-013: "Change number" then Send Code reused the first key, and
    // the server answered "That request is already being processed".
    test('a corrected number is sent with a new key', () async {
      final family = FakeFamilyRepository(rows: [adult]);
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
        family: family,
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        releaseControllerProvider('p-adult').notifier,
      );

      expect(await notifier.start('+919123456795'), isNull);
      notifier.backToNumber();
      expect(await notifier.start('+919123456796'), isNull);

      expect(family.idempotencyKeys, hasLength(2));
      expect(family.idempotencyKeys.first, isNot(family.idempotencyKeys.last));
    });

    test('the idempotency key is reused on a retried start', () async {
      final family = FakeFamilyRepository(rows: [adult]);
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
        family: family,
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        releaseControllerProvider('p-adult').notifier,
      );
      family.nextFailure = const TimeoutFailure();

      expect(await notifier.start('+919812345678'), isA<TimeoutFailure>());
      expect(await notifier.start('+919812345678'), isNull);

      expect(family.idempotencyKeys, hasLength(2));
      expect(family.idempotencyKeys.first, family.idempotencyKeys.last);
    });

    test('UNDER_AGE stays on the number step with the failure', () async {
      final family = FakeFamilyRepository(rows: [adult]);
      final container = await authenticatedContainer(
        auth: auth,
        profile: profile,
        family: family,
      );
      addTearDown(container.dispose);
      family.nextFailure = const ConflictFailure(
        apiCode: ApiErrorCodes.underAge,
      );

      final failure = await container
          .read(releaseControllerProvider('p-adult').notifier)
          .start('+919812345678');

      expect(failure?.apiCode, ApiErrorCodes.underAge);
      expect(
        container.read(releaseControllerProvider('p-adult')).step,
        ReleaseStep.enterNumber,
      );
    });
  });
}
