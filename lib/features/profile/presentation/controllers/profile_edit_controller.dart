import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/patient.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/mock_data/stores/dependants_store.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/application/providers/auth_provider.dart';
import 'field_errors.dart';

/// Field keys for the profile-edit form's errors.
abstract final class ProfileEditField {
  ProfileEditField._();

  static const String firstName = 'firstName';
  static const String lastName = 'lastName';
  static const String dateOfBirth = 'dateOfBirth';
  static const String gender = 'gender';
  static const String bloodGroup = 'bloodGroup';
  static const String email = 'email';
}

/// The editable account identity (CM-47).
///
/// The audit's finding was that "both edit controls show a message instead of
/// opening a form. No editable field and no phone re-verification step
/// exists." Every field here is real, typed data:
///
/// * the name is split into first and last, because that is what the API takes
///   and what "Alexandra" in the home greeting comes from;
/// * [dateOfBirth] is a `DateTime`, never a typed "15/05/1997" string;
/// * gender and blood group are picked from the canonical lists, so a blood
///   group cannot be "o positive".
///
/// [pendingPhone] is the one field that is deliberately *not* applied on save
/// — see [ProfileEditController.stagePhoneChange].
@immutable
class ProfileEditState {
  const ProfileEditState({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.email,
    required this.currentPhone,
    required this.initial,
    this.pendingPhone,
    this.errors = const FieldErrors(),
    this.isSaving = false,
  });

  /// Builds the form's opening state, and remembers it as [initial] so
  /// [isDirty] compares against what was actually loaded.
  factory ProfileEditState.from({
    required String firstName,
    required String lastName,
    required DateTime? dateOfBirth,
    required String? gender,
    required String? bloodGroup,
    required String email,
    required String currentPhone,
  }) {
    final values = ProfileEditValues(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodGroup: bloodGroup,
      email: email,
    );
    return ProfileEditState(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodGroup: bloodGroup,
      email: email,
      currentPhone: currentPhone,
      initial: values,
    );
  }

  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String email;

  /// The number on the account right now. Read-only in this form: changing it
  /// needs an SMS code, so it goes through [pendingPhone].
  final String currentPhone;

  /// A new number the user has entered and which has **not** been verified,
  /// and therefore has **not** been applied. Null when no change is staged.
  final String? pendingPhone;

  /// The values the form opened with — the [isDirty] baseline.
  final ProfileEditValues initial;

  final FieldErrors errors;
  final bool isSaving;

  ProfileEditValues get values => ProfileEditValues(
    firstName: firstName,
    lastName: lastName,
    dateOfBirth: dateOfBirth,
    gender: gender,
    bloodGroup: bloodGroup,
    email: email,
  );

  /// True when something would be lost by leaving — what
  /// `AppUnsavedChangesGuard` watches. A staged phone change counts: it is
  /// entered work, even though it is not applied on save.
  bool get isDirty => values != initial || pendingPhone != null;

  /// "Alexandra Johnson" — what gets written to the account.
  String get fullName => [
    firstName.trim(),
    lastName.trim(),
  ].where((part) => part.isNotEmpty).join(' ');

  ProfileEditState copyWith({
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? email,
    String? currentPhone,
    String? pendingPhone,
    bool clearPendingPhone = false,
    FieldErrors? errors,
    bool? isSaving,
  }) {
    return ProfileEditState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      email: email ?? this.email,
      currentPhone: currentPhone ?? this.currentPhone,
      pendingPhone: clearPendingPhone
          ? null
          : (pendingPhone ?? this.pendingPhone),
      initial: initial,
      errors: errors ?? this.errors,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// The saveable half of [ProfileEditState], with value equality so "is this
/// form dirty" is one comparison rather than six.
@immutable
class ProfileEditValues {
  const ProfileEditValues({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.email,
  });

  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String email;

  @override
  bool operator ==(Object other) =>
      other is ProfileEditValues &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.dateOfBirth == dateOfBirth &&
      other.gender == gender &&
      other.bloodGroup == bloodGroup &&
      other.email == email;

  @override
  int get hashCode =>
      Object.hash(firstName, lastName, dateOfBirth, gender, bloodGroup, email);
}

/// Owns the `/profile/edit` form (CM-47).
///
/// Validation follows audit §3.5.4: every setter recomputes the whole error
/// map, and [FieldErrors.visible] decides when the user sees an error — on
/// submit, or once a field has been touched. So an error clears when the value
/// is actually fixed, not on the first keystroke.
class ProfileEditController extends StateNotifier<ProfileEditState> {
  ProfileEditController(super.initial) {
    // Compute the truth about the loaded values immediately; nothing is shown
    // until a field is touched or submit is pressed.
    _revalidate();
  }

  void setFirstName(String value) {
    state = state.copyWith(firstName: value);
    _revalidate();
  }

  void setLastName(String value) {
    state = state.copyWith(lastName: value);
    _revalidate();
  }

  void setEmail(String value) {
    state = state.copyWith(email: value);
    _revalidate();
  }

  void setDateOfBirth(DateTime value) {
    state = state.copyWith(
      dateOfBirth: value,
      errors: state.errors.withTouched(ProfileEditField.dateOfBirth),
    );
    _revalidate();
  }

  void setGender(String value) {
    state = state.copyWith(
      gender: value,
      errors: state.errors.withTouched(ProfileEditField.gender),
    );
    _revalidate();
  }

  void setBloodGroup(String value) {
    state = state.copyWith(
      bloodGroup: value,
      errors: state.errors.withTouched(ProfileEditField.bloodGroup),
    );
    _revalidate();
  }

  /// Reveals [field]'s error, if it has one — called when a field loses focus.
  void markTouched(String field) {
    state = state.copyWith(errors: state.errors.withTouched(field));
  }

  /// Records a new mobile number as *staged*, not applied.
  ///
  /// A mobile number is a sign-in credential: applying it without an SMS code
  /// would let anyone holding an unlocked phone move the account's second
  /// factor. So this only remembers the number, and the screen shows it as
  /// unverified until the verify step exists. See the screen's doc comment for
  /// the `VerifyPurpose` case this flow needs.
  void stagePhoneChange(String e164) {
    state = state.copyWith(pendingPhone: e164);
  }

  /// Abandons a staged number.
  void discardPhoneChange() {
    state = state.copyWith(clearPendingPhone: true);
  }

  /// Validates everything and marks the form submitted, so every outstanding
  /// error becomes visible. Returns true when the form can be saved.
  bool validate() {
    _revalidate();
    state = state.copyWith(errors: state.errors.withSubmitted());
    return state.errors.isValid;
  }

  void setSaving(bool value) => state = state.copyWith(isSaving: value);

  void _revalidate() {
    state = state.copyWith(
      errors: state.errors.withErrors({
        ProfileEditField.firstName: Validators.personName(state.firstName),
        // Optional: plenty of people have one name. Checked only when given,
        // so the form does not invent a requirement the account does not have.
        ProfileEditField.lastName: state.lastName.trim().isEmpty
            ? null
            : Validators.personName(state.lastName),
        ProfileEditField.email: Validators.email(state.email),
        ProfileEditField.dateOfBirth: Validators.dateOfBirth(state.dateOfBirth),
        ProfileEditField.gender: state.gender == null
            ? 'Choose a gender'
            : null,
        // Optional, but if it is on file it has to be one of the eight groups —
        // a wrong blood group in a hospital is not a cosmetic error.
        ProfileEditField.bloodGroup: state.bloodGroup == null
            ? null
            : Validators.bloodGroup(state.bloodGroup!),
      }),
    );
  }
}

/// autoDispose — the draft belongs to one visit to `/profile/edit`, and a
/// freshly opened form must show the account as it is now.
///
/// Seeded from the signed-in [User] where there is one, and otherwise from the
/// account holder's own patient record (`selfPatientProvider`), which is the
/// typed source for date of birth, gender and blood group. Read, not watched:
/// re-seeding mid-edit would throw away what the user has typed.
final profileEditControllerProvider =
    StateNotifierProvider.autoDispose<ProfileEditController, ProfileEditState>((
      ref,
    ) {
      final user = ref.read(currentUserProvider);
      final self = ref.read(selfPatientProvider);
      final name = (user?.name ?? self.name).trim();
      final space = name.indexOf(' ');

      return ProfileEditController(
        ProfileEditState.from(
          firstName: space == -1 ? name : name.substring(0, space),
          lastName: space == -1 ? '' : name.substring(space + 1).trim(),
          dateOfBirth: user?.dateOfBirth ?? self.dateOfBirth,
          gender: user?.gender ?? self.gender,
          bloodGroup: user?.bloodGroup ?? self.bloodGroup,
          email: user?.email ?? ref.read(userEmailProvider),
          currentPhone: user?.phone ?? ref.read(userPhoneProvider),
        ),
      );
    });

/// The account identity the Profile tab renders.
///
/// Profile used to read `userNameProvider` / `profileInfoProvider` straight
/// from the seed, which meant a saved edit was invisible — audit §2.1's "no
/// screen state that shows the user's data changing". This provider layers the
/// live sources over the seed in the same order the edit form loads them, so a
/// save is visible immediately.
@immutable
class ProfileIdentity {
  const ProfileIdentity({
    required this.name,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
  });

  final String name;
  final String email;
  final String phone;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;

  /// The "Personal Information" rows, in the order the card shows them.
  ///
  /// Derived here from typed values rather than stored as strings, so the date
  /// of birth is formatted once, in one place.
  List<({String key, String value})> get infoRows => [
    (key: 'Phone', value: phone),
    (
      key: 'Date of Birth',
      value: dateOfBirth == null
          ? 'Not set'
          : Patient(
              id: 'display',
              name: name,
              relation: PatientRelations.self,
              dateOfBirth: dateOfBirth!,
              gender: gender ?? '',
            ).dateOfBirthLabel,
    ),
    (key: 'Gender', value: gender ?? 'Not set'),
    (key: 'Blood Group', value: bloodGroup ?? 'Not set'),
  ];
}

/// The live account identity. Watched by the Profile tab.
final profileIdentityProvider = Provider<ProfileIdentity>((ref) {
  final user = ref.watch(currentUserProvider);
  final self = ref.watch(selfPatientProvider);
  return ProfileIdentity(
    name: user?.name ?? self.name,
    email: user?.email ?? ref.watch(userEmailProvider),
    phone: user?.phone ?? ref.watch(userPhoneProvider),
    dateOfBirth: user?.dateOfBirth ?? self.dateOfBirth,
    gender: user?.gender ?? self.gender,
    bloodGroup: user?.bloodGroup ?? self.bloodGroup,
  );
});

/// Applies a validated [ProfileEditState] to both places the identity lives.
///
/// The signed-in [User] is the account; the account holder's [Patient] record
/// is what booking and records read. Writing only one would make the two
/// disagree — the booking patient picker would still show the old name.
/// Takes the screen's [WidgetRef] because this is the save the *screen*
/// performs — it touches two stores and the auth notifier, which is more than
/// one controller owns.
///
/// Returns true when the signed-in account record was updated as well as the
/// patient record — false means there was no session to write the email and
/// name onto, and the caller must not claim the account itself changed.
bool saveProfileEdit(WidgetRef ref, ProfileEditState form) {
  final self = ref.read(selfPatientProvider);
  final dateOfBirth = form.dateOfBirth ?? self.dateOfBirth;

  ref
      .read(dependantsStoreProvider.notifier)
      .patch(
        self.id,
        name: form.fullName,
        dateOfBirth: dateOfBirth,
        gender: form.gender,
        bloodGroup: form.bloodGroup,
      );

  final user = ref.read(currentUserProvider);
  if (user == null) return false;

  ref
      .read(authProvider.notifier)
      .updateUser(
        user.copyWith(
          name: form.fullName,
          email: form.email.trim(),
          dateOfBirth: dateOfBirth,
          gender: form.gender,
          bloodGroup: form.bloodGroup,
        ),
      );
  return true;
}
