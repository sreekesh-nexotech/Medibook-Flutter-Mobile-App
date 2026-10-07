import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/phone.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/person.dart';
import 'field_errors.dart';

/// Field keys for the profile-edit form's errors. These are the **wire**
/// names from `PATCH /patient/me` (§5.2), so a server `VALIDATION_ERROR`
/// lands on the right field with no translation table.
abstract final class ProfileEditField {
  ProfileEditField._();

  static const String firstName = 'first_name';
  static const String lastName = 'last_name';
  static const String dateOfBirth = 'date_of_birth';
  static const String gender = 'gender';
  static const String bloodGroup = 'blood_group';
  static const String allergies = 'allergies';
  static const String marketingOptIn = 'marketing_opt_in';
}

/// The editable account identity (CM-47) — exactly the fields
/// `PATCH /patient/me` accepts.
///
/// Email and mobile number are **not** here: the API cannot change them on
/// this call (§5.2). The mobile number has its own three-step flow
/// (`/profile/phone`); email is read-only in this build (§18).
@immutable
class ProfileEditState {
  const ProfileEditState({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.allergies,
    required this.marketingOptIn,
    required this.initial,
    this.errors = const FieldErrors(),
    this.isSaving = false,
  });

  /// Builds the form's opening state, and remembers it as [initial] so
  /// [isDirty] compares against what was actually loaded.
  factory ProfileEditState.from({
    required String firstName,
    required String lastName,
    required DateTime? dateOfBirth,
    required Gender? gender,
    required String? bloodGroup,
    required List<String> allergies,
    required bool marketingOptIn,
  }) {
    final values = ProfileEditValues(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodGroup: bloodGroup,
      allergies: allergies,
      marketingOptIn: marketingOptIn,
    );
    return ProfileEditState(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodGroup: bloodGroup,
      allergies: allergies,
      marketingOptIn: marketingOptIn,
      initial: values,
    );
  }

  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final String? bloodGroup;
  final List<String> allergies;
  final bool marketingOptIn;

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
    allergies: allergies,
    marketingOptIn: marketingOptIn,
  );

  /// True when something would be lost by leaving — what
  /// `AppUnsavedChangesGuard` watches.
  bool get isDirty => values != initial;

  /// The PATCH body for these values (the controller diffs it against the
  /// live user before sending, so unchanged fields are dropped).
  ProfileUpdate toUpdate() => ProfileUpdate(
    firstName: firstName.trim(),
    lastName: lastName.trim(),
    clearLastName: lastName.trim().isEmpty,
    dateOfBirth: dateOfBirth,
    gender: gender,
    bloodGroup: bloodGroup,
    // "Not known": the stored group must be removed, not left as it was —
    // without this the save sent nothing and O+ stayed (BL-PROF-005).
    clearBloodGroup: bloodGroup == null,
    allergies: [for (final a in allergies) a.trim()],
    marketingOptIn: marketingOptIn,
  );

  ProfileEditState copyWith({
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    Gender? gender,
    String? bloodGroup,
    bool clearBloodGroup = false,
    List<String>? allergies,
    bool? marketingOptIn,
    ProfileEditValues? initial,
    FieldErrors? errors,
    bool? isSaving,
  }) {
    return ProfileEditState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: clearBloodGroup ? null : (bloodGroup ?? this.bloodGroup),
      allergies: allergies ?? this.allergies,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      initial: initial ?? this.initial,
      errors: errors ?? this.errors,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// The saveable half of [ProfileEditState], with value equality so "is this
/// form dirty" is one comparison.
@immutable
class ProfileEditValues {
  const ProfileEditValues({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.allergies,
    required this.marketingOptIn,
  });

  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final String? bloodGroup;
  final List<String> allergies;
  final bool marketingOptIn;

  @override
  bool operator ==(Object other) =>
      other is ProfileEditValues &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.dateOfBirth == dateOfBirth &&
      other.gender == gender &&
      other.bloodGroup == bloodGroup &&
      other.marketingOptIn == marketingOptIn &&
      listEquals(other.allergies, allergies);

  @override
  int get hashCode => Object.hash(
    firstName,
    lastName,
    dateOfBirth,
    gender,
    bloodGroup,
    marketingOptIn,
    Object.hashAll(allergies),
  );
}

/// Owns the `/profile/edit` form (CM-47).
///
/// Validation follows audit §3.5.4: every setter recomputes the whole error
/// map, and [FieldErrors.visible] decides when the user sees an error — on
/// submit, or once a field has been touched. Server field errors are merged
/// in with [applyServerErrors] and cleared by the next local re-validation
/// of that field.
class ProfileEditController extends StateNotifier<ProfileEditState> {
  ProfileEditController(super.initial) {
    _revalidate();
  }

  /// Server-reported errors that local validation cannot reproduce. Kept
  /// until the field changes.
  Map<String, String> _serverErrors = const {};

  void setFirstName(String value) {
    _forget(ProfileEditField.firstName);
    state = state.copyWith(firstName: value);
    _revalidate();
  }

  void setLastName(String value) {
    _forget(ProfileEditField.lastName);
    state = state.copyWith(lastName: value);
    _revalidate();
  }

  void setDateOfBirth(DateTime value) {
    _forget(ProfileEditField.dateOfBirth);
    state = state.copyWith(
      dateOfBirth: value,
      errors: state.errors.withTouched(ProfileEditField.dateOfBirth),
    );
    _revalidate();
  }

  void setGender(Gender value) {
    _forget(ProfileEditField.gender);
    state = state.copyWith(
      gender: value,
      errors: state.errors.withTouched(ProfileEditField.gender),
    );
    _revalidate();
  }

  void setBloodGroup(String? value) {
    _forget(ProfileEditField.bloodGroup);
    state = state.copyWith(
      bloodGroup: value,
      clearBloodGroup: value == null,
      errors: state.errors.withTouched(ProfileEditField.bloodGroup),
    );
    _revalidate();
  }

  void setAllergies(List<String> value) {
    _forget(ProfileEditField.allergies);
    state = state.copyWith(allergies: value);
    _revalidate();
  }

  void setMarketingOptIn(bool value) =>
      state = state.copyWith(marketingOptIn: value);

  /// Reveals [field]'s error, if it has one — called when a field loses focus.
  void markTouched(String field) {
    state = state.copyWith(errors: state.errors.withTouched(field));
  }

  /// Validates everything and marks the form submitted, so every outstanding
  /// error becomes visible. Returns true when the form can be saved.
  bool validate() {
    _revalidate();
    state = state.copyWith(errors: state.errors.withSubmitted());
    return state.errors.isValid;
  }

  void setSaving(bool value) => state = state.copyWith(isSaving: value);

  /// Lands a server `VALIDATION_ERROR` (or `UNDER_AGE`) on its fields. Keys
  /// are the wire names; unknown keys are ignored (the screen shows the
  /// failure's message instead).
  void applyServerErrors(Map<String, String> errors) {
    _serverErrors = {
      for (final entry in errors.entries)
        if (_known.contains(entry.key)) entry.key: entry.value,
    };
    _revalidate();
    state = state.copyWith(errors: state.errors.withSubmitted());
  }

  /// Re-seeds the form after the account was reloaded (`CONFLICT_VERSION`):
  /// the user's edits are kept; only the dirty baseline moves.
  ///
  /// A field the patient did not touch (still equal to the old baseline)
  /// takes the server's [fresh] value; a field they edited keeps their edit.
  /// Keeping every old value re-sent the stale ones on the next save and
  /// silently undid the other device's change (BL-PROF-010).
  void rebase(ProfileEditValues fresh) {
    final old = state.initial;
    T pick<T>(T current, T before, T now) => current == before ? now : current;
    final allergiesUntouched = _sameStrings(state.allergies, old.allergies);
    final firstName = pick(state.firstName, old.firstName, fresh.firstName);
    final lastName = pick(state.lastName, old.lastName, fresh.lastName);
    final dateOfBirth = pick(
      state.dateOfBirth,
      old.dateOfBirth,
      fresh.dateOfBirth,
    );
    final gender = pick(state.gender, old.gender, fresh.gender);
    final bloodGroup = pick(state.bloodGroup, old.bloodGroup, fresh.bloodGroup);
    final marketing = pick(
      state.marketingOptIn,
      old.marketingOptIn,
      fresh.marketingOptIn,
    );
    state = ProfileEditState(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodGroup: bloodGroup,
      allergies: allergiesUntouched ? fresh.allergies : state.allergies,
      marketingOptIn: marketing,
      initial: fresh,
      errors: state.errors,
      isSaving: state.isSaving,
    );
    _revalidate();
  }

  static bool _sameStrings(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static const Set<String> _known = {
    ProfileEditField.firstName,
    ProfileEditField.lastName,
    ProfileEditField.dateOfBirth,
    ProfileEditField.gender,
    ProfileEditField.bloodGroup,
    ProfileEditField.allergies,
    ProfileEditField.marketingOptIn,
  };

  void _forget(String field) {
    if (!_serverErrors.containsKey(field)) return;
    _serverErrors = Map.of(_serverErrors)..remove(field);
  }

  void _revalidate() {
    state = state.copyWith(
      errors: state.errors.withErrors({
        ProfileEditField.firstName:
            _serverErrors[ProfileEditField.firstName] ??
            Validators.personName(state.firstName),
        // Optional: plenty of people have one name. Checked only when given.
        ProfileEditField.lastName:
            _serverErrors[ProfileEditField.lastName] ??
            (state.lastName.trim().isEmpty
                ? null
                : Validators.personName(state.lastName)),
        // Optional on the wire; when set it must be a real date and the
        // account holder must be an adult (§5.2 `UNDER_AGE`).
        ProfileEditField.dateOfBirth:
            _serverErrors[ProfileEditField.dateOfBirth] ??
            (state.dateOfBirth == null
                ? null
                : (Validators.dateOfBirth(state.dateOfBirth) ??
                      _adultError(state.dateOfBirth!))),
        ProfileEditField.gender: _serverErrors[ProfileEditField.gender],
        ProfileEditField.bloodGroup:
            _serverErrors[ProfileEditField.bloodGroup] ??
            (state.bloodGroup == null
                ? null
                : Validators.bloodGroup(state.bloodGroup!)),
        ProfileEditField.allergies:
            _serverErrors[ProfileEditField.allergies] ??
            _allergiesError(state.allergies),
        ProfileEditField.marketingOptIn:
            _serverErrors[ProfileEditField.marketingOptIn],
      }),
    );
  }

  static String? _adultError(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age < 18
        ? 'Account holders must be 18 or older. Add a minor as a family '
              'member instead.'
        : null;
  }

  /// ≤ 50 items, each ≤ 100 characters (§5.2).
  static String? _allergiesError(List<String> allergies) {
    if (allergies.length > 50) return 'Keep the list to 50 allergies';
    if (allergies.any((a) => a.trim().length > 100)) {
      return 'Each allergy must be under 100 characters';
    }
    return null;
  }
}

/// autoDispose — the draft belongs to one visit to `/profile/edit`, and a
/// freshly opened form must show the account as it is now.
///
/// Seeded from the signed-in [User]. Read, not watched: re-seeding mid-edit
/// would throw away what the user has typed (a `CONFLICT_VERSION` reload
/// goes through [ProfileEditController.rebase] instead).
final profileEditControllerProvider =
    StateNotifierProvider.autoDispose<ProfileEditController, ProfileEditState>((
      ref,
    ) {
      final user = ref.read(currentUserProvider);
      return ProfileEditController(
        ProfileEditState.from(
          firstName: user?.firstName ?? '',
          lastName: user?.lastName ?? '',
          dateOfBirth: user?.dateOfBirth,
          gender: Gender.fromWire(user?.gender),
          bloodGroup: user?.bloodGroup,
          allergies: user?.allergies ?? const <String>[],
          marketingOptIn: user?.marketingOptIn ?? false,
        ),
      );
    });

/// The account identity the Profile tab renders — the signed-in user, with
/// the display strings derived here so the screen renders and nothing else.
@immutable
class ProfileIdentity {
  const ProfileIdentity({
    required this.name,
    required this.email,
    required this.phone,
    required this.alternatePhone,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.allergies,
    this.avatarFileId,
  });

  final String name;
  final String? email;

  /// `profile.avatar_file_id` — the photo, when one is on file. Initials
  /// stand in while it loads, when there is none, or when it cannot be read.
  final String? avatarFileId;
  final String? phone;
  final String? alternatePhone;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final String? bloodGroup;
  final List<String> allergies;

  /// The "Personal Information" rows, in the order the card shows them.
  List<({String key, String value})> get infoRows => [
    (
      key: 'Mobile',
      value: phone == null ? 'Not set' : PhoneFormat.display(phone!),
    ),
    (
      key: 'Alternate number',
      value: alternatePhone == null
          ? 'Not set'
          : PhoneFormat.display(alternatePhone!),
    ),
    (
      key: 'Date of birth',
      value: dateOfBirth == null
          ? 'Not set'
          : AppDates.dayMonthYear(dateOfBirth!),
    ),
    (key: 'Gender', value: gender?.label ?? 'Not set'),
    (key: 'Blood group', value: bloodGroup ?? 'Not set'),
    (
      key: 'Allergies',
      value: allergies.isEmpty ? 'None recorded' : allergies.join(', '),
    ),
  ];
}

/// The live account identity. Watched by the Profile tab.
final profileIdentityProvider = Provider<ProfileIdentity?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ProfileIdentity(
    name: user.name,
    email: user.email,
    phone: user.phoneE164,
    alternatePhone: user.alternatePhoneE164,
    dateOfBirth: user.dateOfBirth,
    gender: Gender.fromWire(user.gender),
    bloodGroup: user.bloodGroup,
    allergies: user.allergies,
    avatarFileId: user.avatarFileId,
  );
});
