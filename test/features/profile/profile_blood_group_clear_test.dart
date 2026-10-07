import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/profile/domain/entities/person.dart';
import 'package:medibook/features/profile/application/providers/profile_edit_controller.dart';

import 'profile_test_support.dart';

/// BL-PROF-005: "Not known" on a profile with O+ must remove the blood
/// group; the save used to send nothing for it, so O+ stayed.
void main() {
  test('Not known clears a stored blood group', () {
    final stored = testUser.copyWith(bloodGroup: 'O+');
    final form = ProfileEditState.from(
      firstName: stored.firstName,
      lastName: stored.lastName ?? '',
      dateOfBirth: stored.dateOfBirth,
      gender: Gender.female,
      bloodGroup: null, // the patient chose "Not known"
      allergies: stored.allergies,
      marketingOptIn: stored.marketingOptIn,
    );
    final changes = form.toUpdate().diffAgainst(stored);
    expect(changes.clearBloodGroup, isTrue);
    expect(changes.isEmpty, isFalse);
  });

  test('no blood group before and after is no change', () {
    final stored = testUser.copyWith(bloodGroup: null);
    final form = ProfileEditState.from(
      firstName: stored.firstName,
      lastName: stored.lastName ?? '',
      dateOfBirth: stored.dateOfBirth,
      gender: Gender.female,
      bloodGroup: null,
      allergies: stored.allergies,
      marketingOptIn: stored.marketingOptIn,
    );
    expect(form.toUpdate().diffAgainst(stored).clearBloodGroup, isFalse);
  });

  // BL-PROF-010: after "changed elsewhere", fields the patient did not touch
  // take the server's values; their own edits are kept.
  test('a reloaded profile replaces only the untouched fields', () {
    final controller = ProfileEditController(
      ProfileEditState.from(
        firstName: 'Anita',
        lastName: 'Menon',
        dateOfBirth: null,
        gender: Gender.female,
        bloodGroup: 'O+',
        allergies: const ['Penicillin'],
        marketingOptIn: false,
      ),
    );
    addTearDown(controller.dispose);
    controller.setLastName('Nair'); // the patient's own edit

    // Another device cleared blood group and allergies.
    controller.rebase(
      const ProfileEditValues(
        firstName: 'Anita',
        lastName: 'Menon',
        dateOfBirth: null,
        gender: Gender.female,
        bloodGroup: null,
        allergies: <String>[],
        marketingOptIn: false,
      ),
    );

    final state = controller.state;
    expect(state.lastName, 'Nair', reason: 'the edit is kept');
    expect(state.bloodGroup, isNull, reason: 'the other device wins');
    expect(state.allergies, isEmpty);
  });
}
