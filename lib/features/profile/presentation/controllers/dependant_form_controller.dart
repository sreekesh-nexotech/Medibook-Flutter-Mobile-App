import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/patient.dart';
import '../../../../core/mock_data/stores/dependants_store.dart';
import '../../../../core/utils/validators.dart';
import 'field_errors.dart';

/// Field keys for the dependant form's errors.
abstract final class DependantField {
  DependantField._();

  static const String name = 'name';
  static const String relation = 'relation';
  static const String dateOfBirth = 'dateOfBirth';
  static const String gender = 'gender';
  static const String bloodGroup = 'bloodGroup';
  static const String phone = 'phone';
}

/// The add/edit-a-dependant form (`/dependants/edit`) — CM-16, CM-48.
///
/// The audit found that "three fixed people can be picked. There is no add,
/// edit or remove control, and no blood group or allergy field." All six
/// fields the record actually has are here, typed: a `DateTime` date of birth
/// (so the age shown beside the name is derived, never typed), a blood group
/// from the canonical eight, and allergies as the `List<String>` the model
/// stores.
@immutable
class DependantFormState {
  const DependantFormState({
    required this.name,
    required this.relation,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.allergies,
    required this.phone,
    required this.isSelf,
    required this.initial,
    this.errors = const FieldErrors(),
    this.isSaving = false,
  });

  /// Builds the opening state and captures it as the [isDirty] baseline.
  factory DependantFormState.from({
    required String name,
    required String? relation,
    required DateTime? dateOfBirth,
    required String? gender,
    required String? bloodGroup,
    required List<String> allergies,
    required String phone,
    required bool isSelf,
  }) {
    return DependantFormState(
      name: name,
      relation: relation,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodGroup: bloodGroup,
      allergies: allergies,
      phone: phone,
      isSelf: isSelf,
      initial: DependantFormValues(
        name: name,
        relation: relation,
        dateOfBirth: dateOfBirth,
        gender: gender,
        bloodGroup: bloodGroup,
        allergies: allergies,
        phone: phone,
      ),
    );
  }

  final String name;
  final String? relation;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final List<String> allergies;

  /// A dependant's own number, when they have one. Optional: a six-year-old
  /// does not.
  final String phone;

  /// True when this form is editing the account holder's own record, whose
  /// relation is fixed and which cannot be deleted.
  final bool isSelf;

  final DependantFormValues initial;
  final FieldErrors errors;
  final bool isSaving;

  DependantFormValues get values => DependantFormValues(
    name: name,
    relation: relation,
    dateOfBirth: dateOfBirth,
    gender: gender,
    bloodGroup: bloodGroup,
    allergies: allergies,
    phone: phone,
  );

  bool get isDirty => values != initial;

  DependantFormState copyWith({
    String? name,
    String? relation,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    List<String>? allergies,
    String? phone,
    FieldErrors? errors,
    bool? isSaving,
  }) {
    return DependantFormState(
      name: name ?? this.name,
      relation: relation ?? this.relation,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      phone: phone ?? this.phone,
      isSelf: isSelf,
      initial: initial,
      errors: errors ?? this.errors,
      isSaving: isSaving ?? this.isSaving,
    );
  }
}

/// The saveable half of [DependantFormState], with value equality so
/// "is this dirty" is one comparison.
@immutable
class DependantFormValues {
  const DependantFormValues({
    required this.name,
    required this.relation,
    required this.dateOfBirth,
    required this.gender,
    required this.bloodGroup,
    required this.allergies,
    required this.phone,
  });

  final String name;
  final String? relation;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final List<String> allergies;
  final String phone;

  @override
  bool operator ==(Object other) =>
      other is DependantFormValues &&
      other.name == name &&
      other.relation == relation &&
      other.dateOfBirth == dateOfBirth &&
      other.gender == gender &&
      other.bloodGroup == bloodGroup &&
      other.phone == phone &&
      listEquals(other.allergies, allergies);

  @override
  int get hashCode => Object.hash(
    name,
    relation,
    dateOfBirth,
    gender,
    bloodGroup,
    phone,
    Object.hashAll(allergies),
  );
}

class DependantFormController extends StateNotifier<DependantFormState> {
  DependantFormController(super.initial) {
    _revalidate();
  }

  void setName(String value) {
    state = state.copyWith(name: value);
    _revalidate();
  }

  void setPhone(String value) {
    state = state.copyWith(phone: value);
    _revalidate();
  }

  void setRelation(String value) {
    state = state.copyWith(
      relation: value,
      errors: state.errors.withTouched(DependantField.relation),
    );
    _revalidate();
  }

  void setDateOfBirth(DateTime value) {
    state = state.copyWith(
      dateOfBirth: value,
      errors: state.errors.withTouched(DependantField.dateOfBirth),
    );
    _revalidate();
  }

  void setGender(String value) {
    state = state.copyWith(
      gender: value,
      errors: state.errors.withTouched(DependantField.gender),
    );
    _revalidate();
  }

  void setBloodGroup(String value) {
    state = state.copyWith(
      bloodGroup: value,
      errors: state.errors.withTouched(DependantField.bloodGroup),
    );
    _revalidate();
  }

  void setAllergies(List<String> value) {
    state = state.copyWith(allergies: value);
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

  void _revalidate() {
    state = state.copyWith(
      errors: state.errors.withErrors({
        DependantField.name: Validators.personName(state.name),
        DependantField.relation: state.relation == null
            ? 'Choose how they are related to you'
            : null,
        DependantField.dateOfBirth: Validators.dateOfBirth(state.dateOfBirth),
        DependantField.gender: state.gender == null ? 'Choose a gender' : null,
        // Optional, but must be a real group if given — a wrong blood group in
        // a hospital is not a cosmetic error.
        DependantField.bloodGroup: state.bloodGroup == null
            ? null
            : Validators.bloodGroup(state.bloodGroup!),
        // Optional: only checked when something has been typed.
        DependantField.phone: state.phone.trim().isEmpty
            ? null
            : Validators.phone(state.phone),
      }),
    );
  }
}

/// One form per patient id, or one "add" form for the null id.
///
/// autoDispose family: ids are minted at runtime, so a keyed cache must not
/// outlive its watcher, and reopening the form must show the record as it is
/// now rather than an abandoned draft.
final dependantFormProvider = StateNotifierProvider.autoDispose
    .family<DependantFormController, DependantFormState, String?>((ref, id) {
      final existing = id == null
          ? null
          : ref.read(dependantsStoreProvider.notifier).byId(id);

      if (existing == null) {
        return DependantFormController(
          DependantFormState.from(
            name: '',
            relation: null,
            dateOfBirth: null,
            gender: null,
            bloodGroup: null,
            allergies: const <String>[],
            phone: '',
            isSelf: false,
          ),
        );
      }

      return DependantFormController(
        DependantFormState.from(
          name: existing.name,
          relation: existing.relation,
          dateOfBirth: existing.dateOfBirth,
          gender: existing.gender,
          bloodGroup: existing.bloodGroup,
          allergies: existing.allergies,
          phone: existing.phone ?? '',
          isSelf: existing.isSelf,
        ),
      );
    });

/// The relation options the form offers, with the account holder's own fixed
/// value included when it is their record being edited.
///
/// `PatientRelations.all` deliberately excludes "Self": only one record may be
/// the account holder, and that is [Patient.isSelf]'s job, not a picker's.
List<String> relationOptionsFor({required bool isSelf}) =>
    isSelf ? const [PatientRelations.self] : PatientRelations.all;
