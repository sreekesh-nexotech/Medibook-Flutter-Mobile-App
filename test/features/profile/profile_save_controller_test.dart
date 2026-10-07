import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/auth/application/providers/auth_provider.dart';
import 'package:medibook/features/profile/application/providers/profile_mutations_provider.dart';
import 'package:medibook/features/profile/domain/entities/account.dart';
import 'package:medibook/features/profile/domain/entities/person.dart';

import 'profile_test_support.dart';

/// `PATCH /patient/me` through [ProfileSaveController] (§5.2, §1.9).
void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;

  setUp(() {
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
  });

  test('sends only the changed fields with If-Match = user.version', () async {
    final container = await authenticatedContainer(
      auth: auth,
      profile: profile,
    );
    addTearDown(container.dispose);

    final failure = await container
        .read(profileSaveControllerProvider.notifier)
        .save(
          const ProfileUpdate(
            firstName: 'Anita', // unchanged
            lastName: 'Nair', // changed
            gender: Gender.female, // unchanged
            marketingOptIn: false, // unchanged
          ),
        );

    expect(failure, isNull);
    expect(profile.ifMatches, [2]);
    final sent = profile.updates.single;
    expect(sent.firstName, isNull);
    expect(sent.lastName, 'Nair');
    expect(sent.gender, isNull);
    expect(sent.marketingOptIn, isNull);
    // The session now holds the server's answer (new version).
    expect(container.read(currentUserProvider)?.lastName, 'Nair');
    expect(container.read(currentUserProvider)?.version, 3);
  });

  test('a no-op save makes no request', () async {
    final container = await authenticatedContainer(
      auth: auth,
      profile: profile,
    );
    addTearDown(container.dispose);

    final failure = await container
        .read(profileSaveControllerProvider.notifier)
        .save(const ProfileUpdate(firstName: 'Anita'));

    expect(failure, isNull);
    expect(profile.calls, isEmpty);
  });

  test('CONFLICT_VERSION reloads /me and flags the conflict', () async {
    final container = await authenticatedContainer(
      auth: auth,
      profile: profile,
    );
    addTearDown(container.dispose);
    profile.nextFailure = const ConflictFailure(
      apiCode: ApiErrorCodes.conflictVersion,
      meta: {'current': 5},
    );
    auth.user = testUser.copyWith(version: 5);
    final before = auth.fetchMeCalls;

    final failure = await container
        .read(profileSaveControllerProvider.notifier)
        .save(const ProfileUpdate(lastName: 'Nair'));

    expect(failure, isA<ConflictFailure>());
    expect(failure!.apiCode, ApiErrorCodes.conflictVersion);
    expect(auth.fetchMeCalls, before + 1);
    expect(container.read(currentUserProvider)?.version, 5);
    expect(container.read(profileSaveControllerProvider).hasConflict, isTrue);
    expect(container.read(profileSaveControllerProvider).isSaving, isFalse);
  });

  test('UNDER_AGE lands on date_of_birth as a validation failure', () async {
    final container = await authenticatedContainer(
      auth: auth,
      profile: profile,
    );
    addTearDown(container.dispose);
    profile.nextFailure = const ConflictFailure(
      apiCode: ApiErrorCodes.underAge,
      userMessage: 'Account holders must be 18 or older.',
    );

    final failure = await container
        .read(profileSaveControllerProvider.notifier)
        .save(ProfileUpdate(dateOfBirth: DateTime(2020, 1, 1)));

    expect(failure, isA<ValidationFailure>());
    expect(
      (failure! as ValidationFailure).forField('date_of_birth'),
      contains('18 or older'),
    );
  });

  test('server field errors pass through untouched', () async {
    final container = await authenticatedContainer(
      auth: auth,
      profile: profile,
    );
    addTearDown(container.dispose);
    profile.nextFailure = const ValidationFailure(
      apiCode: ApiErrorCodes.validationError,
      fieldErrors: {'blood_group': '"Z+" is not a valid choice.'},
    );

    final failure = await container
        .read(profileSaveControllerProvider.notifier)
        .save(const ProfileUpdate(bloodGroup: 'Z+'));

    expect(failure, isA<ValidationFailure>());
    expect(
      (failure! as ValidationFailure).fieldErrors['blood_group'],
      contains('not a valid choice'),
    );
  });

  test('alternate phone set / remove merge into the session user', () async {
    final container = await authenticatedContainer(
      auth: auth,
      profile: profile,
    );
    addTearDown(container.dispose);

    final notifier = container.read(alternatePhoneControllerProvider.notifier);
    expect(await notifier.set('+919800000000'), isNull);
    expect(
      container.read(currentUserProvider)?.alternatePhoneE164,
      '+919800000000',
    );
    // Profile fields the bare User response lacks are kept.
    expect(container.read(currentUserProvider)?.gender, 'female');

    expect(await notifier.remove(), isNull);
    expect(container.read(currentUserProvider)?.alternatePhoneE164, isNull);
  });
}
