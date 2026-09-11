import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../medibook_seed.dart';
import '../models/patient.dart';

/// Owns the account's patients — the account holder plus their dependants
/// (CM-16, CM-48).
///
/// **Why this is a shared store rather than a feature controller:** booking
/// step 3 picks a patient from this list, and Profile → Family Members edits
/// it. If the list lived in one of those features, adding a dependant in
/// Profile would not appear in the booking picker until a restart.
///
/// The account holder ([Patient.isSelf]) cannot be removed — [remove] refuses,
/// so no screen has to remember that rule.
class DependantsStore extends Notifier<List<Patient>> {
  @override
  List<Patient> build() => MedibookSeed.patients;

  /// The account holder.
  Patient get self =>
      state.firstWhere((p) => p.isSelf, orElse: () => state.first);

  /// Everyone except the account holder.
  List<Patient> get dependants => state.where((p) => !p.isSelf).toList();

  Patient? byId(String id) {
    for (final patient in state) {
      if (patient.id == id) return patient;
    }
    return null;
  }

  /// Add a dependant. Returns the stored record, whose [Patient.id] is minted
  /// here so the caller does not have to invent one.
  Patient add({
    required String name,
    required String relation,
    required DateTime dateOfBirth,
    required String gender,
    String? bloodGroup,
    List<String> allergies = const <String>[],
    String? phone,
  }) {
    final patient = Patient(
      id: 'p-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      relation: relation,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodGroup: bloodGroup,
      allergies: allergies,
      phone: phone,
    );
    state = [...state, patient];
    return patient;
  }

  /// Replace a record wholesale (the edit form's save).
  void update(Patient patient) {
    state = [
      for (final p in state)
        if (p.id == patient.id) patient else p,
    ];
  }

  /// Patch individual fields of the record with [id]. No-op for an unknown id.
  void patch(
    String id, {
    String? name,
    String? relation,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    List<String>? allergies,
    String? phone,
  }) {
    state = [
      for (final p in state)
        if (p.id == id)
          p.copyWith(
            name: name,
            relation: relation,
            dateOfBirth: dateOfBirth,
            gender: gender,
            bloodGroup: bloodGroup,
            allergies: allergies,
            phone: phone,
          )
        else
          p,
    ];
  }

  /// Remove a dependant.
  ///
  /// Returns false — and changes nothing — when [id] is unknown or is the
  /// account holder. Callers must not report success on a false return
  /// (audit §4.1: controls must be honest).
  bool remove(String id) {
    final patient = byId(id);
    if (patient == null || patient.isSelf) return false;
    state = state.where((p) => p.id != id).toList();
    return true;
  }
}

/// The account's patients. Not autoDispose — booking and profile both read it.
final dependantsStoreProvider =
    NotifierProvider<DependantsStore, List<Patient>>(DependantsStore.new);

/// The account holder.
final selfPatientProvider = Provider<Patient>((ref) {
  final patients = ref.watch(dependantsStoreProvider);
  return patients.firstWhere((p) => p.isSelf, orElse: () => patients.first);
});

/// Dependants only (excludes the account holder) — the Family Members list.
final dependantsOnlyProvider = Provider<List<Patient>>((ref) {
  final patients = ref.watch(dependantsStoreProvider);
  return patients.where((p) => !p.isSelf).toList();
});

/// One patient by id. autoDispose family — ids are minted at runtime, so keyed
/// caches must not outlive their watchers.
final patientByIdProvider = Provider.autoDispose.family<Patient?, String>((
  ref,
  id,
) {
  final patients = ref.watch(dependantsStoreProvider);
  for (final patient in patients) {
    if (patient.id == id) return patient;
  }
  return null;
});
