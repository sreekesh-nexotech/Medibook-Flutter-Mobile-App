import '../../utils/date_utils.dart';

/// A patient in the account — the account holder plus their dependants
/// (CM-16, CM-48). Shown in booking step 3 and managed from Profile.
///
/// Presentation view-model — immutable, no logic.
///
/// Audit follow-through: the record used to be three strings, with the
/// "29 years · Female" line *typed in*, so a birthday never changed it and
/// nothing could sort by age or check a dependant's eligibility. It now stores
/// [dateOfBirth] and [gender]; `String get meta` derives the same label, so
/// existing screens (`patient_card.dart`, booking step 3) compile untouched.
class Patient {
  const Patient({
    required this.id,
    required this.name,
    required this.relation,
    required this.dateOfBirth,
    required this.gender,
    this.bloodGroup,
    this.allergies = const <String>[],
    this.isSelf = false,
    this.phone,
  });

  /// Stable id — the key for booking-for, document ownership and CRUD.
  final String id;

  final String name;

  /// Relation chip ("Self", "Husband", "Daughter").
  final String relation;

  final DateTime dateOfBirth;

  /// "Female" / "Male" / "Other".
  final String gender;

  /// ABO/Rh group, when on file.
  final String? bloodGroup;

  /// Known allergies — surfaced on the appointment detail for the doctor.
  final List<String> allergies;

  /// True for the account holder. Exactly one seeded patient sets this, and
  /// the UI must not offer to delete them.
  final bool isSelf;

  /// Contact number, for dependants who have their own.
  final String? phone;

  /// Age in whole years, recomputed from [dateOfBirth] every time.
  int get age => AppDates.ageInYears(dateOfBirth);

  /// "29 years · Female" — unchanged public API, now derived.
  String get meta => '$age years · $gender';

  /// "15 May 1997" — the profile detail row.
  String get dateOfBirthLabel => AppDates.dayMonthYear(dateOfBirth);

  /// True when this dependant is under 18 (paediatric flows, consent).
  bool get isMinor => age < 18;

  bool get hasAllergies => allergies.isNotEmpty;

  /// "Peanuts, Penicillin" or "None recorded".
  String get allergiesLabel =>
      allergies.isEmpty ? 'None recorded' : allergies.join(', ');

  Patient copyWith({
    String? id,
    String? name,
    String? relation,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    List<String>? allergies,
    bool? isSelf,
    String? phone,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      isSelf: isSelf ?? this.isSelf,
      phone: phone ?? this.phone,
    );
  }
}

/// The relation options a dependant form offers (CM-48).
abstract final class PatientRelations {
  PatientRelations._();

  static const String self = 'Self';

  static const List<String> all = [
    'Spouse',
    'Husband',
    'Wife',
    'Son',
    'Daughter',
    'Father',
    'Mother',
    'Brother',
    'Sister',
    'Other',
  ];
}

/// The gender options a patient form offers.
abstract final class PatientGenders {
  PatientGenders._();

  static const List<String> all = ['Female', 'Male', 'Other'];
}
