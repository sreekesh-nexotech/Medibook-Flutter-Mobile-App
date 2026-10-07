import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import 'profile_provider.dart';
import '../../domain/entities/person.dart';
import 'field_errors.dart';

/// Field keys for the dependant form's errors — the **wire** names from
/// `POST`/`PATCH /patient/me/persons` (§6.1), so a server `VALIDATION_ERROR`
/// lands on the right field.
abstract final class DependantField {
  DependantField._();

  static const String firstName = 'first_name';
  static const String lastName = 'last_name';
  static const String relation = 'relation';
  static const String dateOfBirth = 'date_of_birth';
  static const String gender = 'gender';
  static const String bloodGroup = 'blood_group';
  static const String allergies = 'allergies';
  static const String phone = 'phone_e164';
  static const String guardianNote = 'guardian_note';
}

/// `guardian_note` is at most this long on the wire (§6.1).
const int guardianNoteMaxLength = 1000;

/// The add/edit-a-family-member form (`/dependants/edit`) — CM-16, CM-48.
///
/// Typed data throughout: a `DateTime` date of birth (so the age beside the
/// name is derived), a [PersonRelation] from the five the API accepts, a
/// [Gender] from the four, and a blood group from the canonical eight.
@immutable
class DependantFormState {
  const DependantFormState({
    required this.firstName,
    required this.lastName,
    required this.relation,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.allergies,
    required this.phone,
    required this.guardianNote,
    required this.isSelf,
    required this.version,
    required this.initial,
    this.errors = const FieldErrors(),
    this.isSaving = false,
  });

  /// Builds the opening state and captures it as the [isDirty] baseline.
  factory DependantFormState.from({
    required String firstName,
    required String lastName,
    required PersonRelation? relation,
    required DateTime? dateOfBirth,
    required Gender? gender,
    required String? bloodGroup,
    required List<String> allergies,
    required String phone,
    required String guardianNote,
    required bool isSelf,
    required int version,
  }) {
    return DependantFormState(
      firstName: firstName,
      lastName: lastName,
      relation: relation,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodGroup: bloodGroup,
      allergies: allergies,
      phone: phone,
      guardianNote: guardianNote,
      isSelf: isSelf,
      version: version,
      initial: DependantFormValues(
        firstName: firstName,
        lastName: lastName,
        relation: relation,
        dateOfBirth: dateOfBirth,
        gender: gender,
        bloodGroup: bloodGroup,
        allergies: allergies,
        phone: phone,
        guardianNote: guardianNote,
      ),
    );
  }

  final String firstName;
  final String lastName;
  final PersonRelation? relation;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final String? bloodGroup;
  final List<String> allergies;

  /// A dependant's own number in E.164, or empty. Optional: a six-year-old
  /// does not have one.
  final String phone;

  /// `guardian_note` (§6.1): free text about who looks after them, or
  /// empty. Optional, at most [guardianNoteMaxLength] characters.
  final String guardianNote;

  /// True when this form is editing the account holder's own record, whose
  /// relation is fixed and which cannot be deleted.
  final bool isSelf;

  /// The row version for `If-Match`; 0 for a new person.
  final int version;

  final DependantFormValues initial;
  final FieldErrors errors;
  final bool isSaving;

  DependantFormValues get values => DependantFormValues(
    firstName: firstName,
    lastName: lastName,
    relation: relation,
    dateOfBirth: dateOfBirth,
    gender: gender,
    bloodGroup: bloodGroup,
    allergies: allergies,
    phone: phone,
    guardianNote: guardianNote,
  );

  bool get isDirty => values != initial;

  String get fullName =>
      [firstName.trim(), lastName.trim()].where((p) => p.isNotEmpty).join(' ');

  /// The POST body — every field the user filled in.
  PersonDraft toCreateDraft() => PersonDraft(
    firstName: firstName.trim(),
    lastName: lastName.trim().isEmpty ? null : lastName.trim(),
    relation: relation,
    dateOfBirth: dateOfBirth,
    gender: gender,
    bloodGroup: bloodGroup,
    allergies: allergies,
    phoneE164: phone.trim().isEmpty ? null : phone.trim(),
    guardianNote: guardianNote.trim().isEmpty ? null : guardianNote.trim(),
  );

  /// The PATCH body — only what changed since [initial].
  PersonDraft toPatchDraft() => PersonDraft(
    firstName: firstName.trim() == initial.firstName.trim()
        ? null
        : firstName.trim(),
    lastName:
        lastName.trim() == initial.lastName.trim() || lastName.trim().isEmpty
        ? null
        : lastName.trim(),
    clearLastName:
        lastName.trim().isEmpty && initial.lastName.trim().isNotEmpty,
    relation: isSelf || relation == initial.relation ? null : relation,
    dateOfBirth: dateOfBirth == initial.dateOfBirth ? null : dateOfBirth,
    gender: gender == initial.gender ? null : gender,
    bloodGroup: bloodGroup == initial.bloodGroup || bloodGroup == null
        ? null
        : bloodGroup,
    clearBloodGroup: bloodGroup == null && initial.bloodGroup != null,
    allergies: listEquals(allergies, initial.allergies) ? null : allergies,
    phoneE164: phone.trim() == initial.phone.trim() || phone.trim().isEmpty
        ? null
        : phone.trim(),
    clearPhone: phone.trim().isEmpty && initial.phone.trim().isNotEmpty,
    guardianNote:
        guardianNote.trim() == initial.guardianNote.trim() ||
            guardianNote.trim().isEmpty
        ? null
        : guardianNote.trim(),
    clearGuardianNote:
        guardianNote.trim().isEmpty && initial.guardianNote.trim().isNotEmpty,
  );

  DependantFormState copyWith({
    String? firstName,
    String? lastName,
    PersonRelation? relation,
    DateTime? dateOfBirth,
    Gender? gender,
    String? bloodGroup,
    bool clearBloodGroup = false,
    List<String>? allergies,
    String? phone,
    String? guardianNote,
    FieldErrors? errors,
    bool? isSaving,
  }) {
    return DependantFormState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      relation: relation ?? this.relation,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: clearBloodGroup ? null : (bloodGroup ?? this.bloodGroup),
      allergies: allergies ?? this.allergies,
      phone: phone ?? this.phone,
      guardianNote: guardianNote ?? this.guardianNote,
      isSelf: isSelf,
      version: version,
      initial: initial,
      errors: errors ?? this.errors,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// The saveable half of [DependantFormState], with value equality so "is
/// this dirty" is one comparison.
@immutable
class DependantFormValues {
  const DependantFormValues({
    required this.firstName,
    required this.lastName,
    required this.relation,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.allergies,
    required this.phone,
    required this.guardianNote,
  });

  final String firstName;
  final String lastName;
  final PersonRelation? relation;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final String? bloodGroup;
  final List<String> allergies;
  final String phone;
  final String guardianNote;

  @override
  bool operator ==(Object other) =>
      other is DependantFormValues &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.relation == relation &&
      other.dateOfBirth == dateOfBirth &&
      other.gender == gender &&
      other.bloodGroup == bloodGroup &&
      other.phone == phone &&
      other.guardianNote == guardianNote &&
      listEquals(other.allergies, allergies);

  @override
  int get hashCode => Object.hash(
    firstName,
    lastName,
    relation,
    dateOfBirth,
    gender,
    bloodGroup,
    phone,
    guardianNote,
    Object.hashAll(allergies),
  );
}

class DependantFormController extends StateNotifier<DependantFormState> {
  DependantFormController(super.initial) {
    _revalidate();
  }

  Map<String, String> _serverErrors = const {};

  void setFirstName(String value) {
    _forget(DependantField.firstName);
    state = state.copyWith(firstName: value);
    _revalidate();
  }

  void setLastName(String value) {
    _forget(DependantField.lastName);
    state = state.copyWith(lastName: value);
    _revalidate();
  }

  /// [value] is E.164 (from the phone field's country code + digits), or
  /// empty.
  void setPhone(String value) {
    _forget(DependantField.phone);
    state = state.copyWith(phone: value);
    _revalidate();
  }

  void setGuardianNote(String value) {
    _forget(DependantField.guardianNote);
    state = state.copyWith(guardianNote: value);
    _revalidate();
  }

  void setRelation(PersonRelation value) {
    _forget(DependantField.relation);
    state = state.copyWith(
      relation: value,
      errors: state.errors.withTouched(DependantField.relation),
    );
    _revalidate();
  }

  void setDateOfBirth(DateTime value) {
    _forget(DependantField.dateOfBirth);
    state = state.copyWith(
      dateOfBirth: value,
      errors: state.errors.withTouched(DependantField.dateOfBirth),
    );
    _revalidate();
  }

  void setGender(Gender value) {
    _forget(DependantField.gender);
    state = state.copyWith(
      gender: value,
      errors: state.errors.withTouched(DependantField.gender),
    );
    _revalidate();
  }

  void setBloodGroup(String? value) {
    _forget(DependantField.bloodGroup);
    state = state.copyWith(
      bloodGroup: value,
      clearBloodGroup: value == null,
      errors: state.errors.withTouched(DependantField.bloodGroup),
    );
    _revalidate();
  }

  void setAllergies(List<String> value) {
    _forget(DependantField.allergies);
    state = state.copyWith(allergies: value);
    _revalidate();
  }

  void markTouched(String field) {
    state = state.copyWith(errors: state.errors.withTouched(field));
  }

  bool validate() {
    _revalidate();
    state = state.copyWith(errors: state.errors.withSubmitted());
    return state.errors.isValid;
  }

  void setSaving(bool value) => state = state.copyWith(isSaving: value);

  /// Lands a server `VALIDATION_ERROR` on its fields (wire keys).
  void applyServerErrors(Map<String, String> errors) {
    _serverErrors = {
      for (final entry in errors.entries)
        if (_known.contains(entry.key)) entry.key: entry.value,
    };
    _revalidate();
    state = state.copyWith(errors: state.errors.withSubmitted());
  }

  static const Set<String> _known = {
    DependantField.firstName,
    DependantField.lastName,
    DependantField.relation,
    DependantField.dateOfBirth,
    DependantField.gender,
    DependantField.bloodGroup,
    DependantField.allergies,
    DependantField.phone,
    DependantField.guardianNote,
  };

  void _forget(String field) {
    if (!_serverErrors.containsKey(field)) return;
    _serverErrors = Map.of(_serverErrors)..remove(field);
  }

  void _revalidate() {
    state = state.copyWith(
      errors: state.errors.withErrors({
        DependantField.firstName:
            _serverErrors[DependantField.firstName] ??
            Validators.personName(state.firstName),
        DependantField.lastName:
            _serverErrors[DependantField.lastName] ??
            (state.lastName.trim().isEmpty
                ? null
                : Validators.personName(state.lastName)),
        DependantField.relation:
            _serverErrors[DependantField.relation] ??
            (state.relation == null && !state.isSelf
                ? 'Choose how they are related to you'
                : null),
        // Optional on the wire, but the booking flow and the age badge need
        // it, and "not in the future" is the server's rule too.
        DependantField.dateOfBirth:
            _serverErrors[DependantField.dateOfBirth] ??
            Validators.dateOfBirth(state.dateOfBirth),
        DependantField.gender: _serverErrors[DependantField.gender],
        DependantField.bloodGroup:
            _serverErrors[DependantField.bloodGroup] ??
            (state.bloodGroup == null
                ? null
                : Validators.bloodGroup(state.bloodGroup!)),
        DependantField.allergies: _serverErrors[DependantField.allergies],
        DependantField.phone:
            _serverErrors[DependantField.phone] ??
            (state.phone.trim().isEmpty
                ? null
                : Validators.phoneE164(state.phone)),
        DependantField.guardianNote:
            _serverErrors[DependantField.guardianNote] ??
            (state.guardianNote.trim().length > guardianNoteMaxLength
                ? 'Keep the note under $guardianNoteMaxLength characters'
                : null),
      }),
    );
  }
}

/// One form per person id, or one "add" form for the null id.
///
/// autoDispose family: ids are minted server-side, so a keyed cache must not
/// outlive its watcher, and reopening the form must show the record as it is
/// now rather than an abandoned draft. Seeded from `personByIdProvider`
/// (read once — re-seeding mid-edit would discard typing).
final dependantFormProvider = StateNotifierProvider.autoDispose
    .family<DependantFormController, DependantFormState, String?>((ref, id) {
      final existing = id == null ? null : ref.read(personByIdProvider(id));

      if (existing == null) {
        return DependantFormController(
          DependantFormState.from(
            firstName: '',
            lastName: '',
            relation: null,
            dateOfBirth: null,
            gender: null,
            bloodGroup: null,
            allergies: const <String>[],
            phone: '',
            guardianNote: '',
            isSelf: false,
            version: 0,
          ),
        );
      }

      return DependantFormController(
        DependantFormState.from(
          firstName: existing.firstName,
          lastName: existing.lastName ?? '',
          relation: existing.relation,
          dateOfBirth: existing.dateOfBirth,
          gender: existing.gender,
          bloodGroup: existing.bloodGroup,
          allergies: existing.allergies,
          phone: existing.phoneE164 ?? '',
          guardianNote: existing.guardianNote ?? '',
          isSelf: existing.isSelf,
          version: existing.version,
        ),
      );
    });
