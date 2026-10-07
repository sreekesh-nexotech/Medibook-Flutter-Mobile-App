/// A person on the account (§6.1): the account holder (`is_self`) and the
/// dependants they book for.
///
/// Plain immutable entity. Age, minor-ness and the display relation are
/// derived here from stored facts, never typed in.
class Person {
  const Person({
    required this.id,
    required this.firstName,
    required this.relation,
    this.lastName,
    this.isSelf = false,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.allergies = const <String>[],
    this.phoneE164,
    this.guardianNote,
    this.version = 1,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final bool isSelf;
  final String firstName;
  final String? lastName;
  final PersonRelation relation;
  final DateTime? dateOfBirth;
  final Gender? gender;

  /// One of the eight ABO/Rh groups, or null.
  final String? bloodGroup;
  final List<String> allergies;
  final String? phoneE164;
  final String? guardianNote;

  /// Row version — `If-Match` on PATCH (§1.9).
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get name => [
    firstName.trim(),
    (lastName ?? '').trim(),
  ].where((p) => p.isNotEmpty).join(' ');

  /// Whole years, or null without a date of birth.
  int? ageInYears({DateTime? now}) {
    final dob = dateOfBirth;
    if (dob == null) return null;
    final today = now ?? DateTime.now();
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  /// True when under 18. Unknown date of birth counts as not-a-minor so no
  /// control is hidden on a guess.
  bool get isMinor {
    final age = ageInYears();
    return age != null && age < 18;
  }

  /// A dependant who is 18+ may be released to their own account (§5.8).
  bool get canBeReleased {
    if (isSelf) return false;
    final age = ageInYears();
    return age != null && age >= 18;
  }

  /// "Daughter", "Father", "Spouse" … — the wire relation refined by gender.
  String get relationLabel => relation.labelFor(gender);

  bool get hasAllergies => allergies.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is Person &&
      other.id == id &&
      other.isSelf == isSelf &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.relation == relation &&
      other.dateOfBirth == dateOfBirth &&
      other.gender == gender &&
      other.bloodGroup == bloodGroup &&
      other.phoneE164 == phoneE164 &&
      other.guardianNote == guardianNote &&
      other.version == version &&
      _listEquals(other.allergies, allergies);

  @override
  int get hashCode => Object.hash(
    id,
    isSelf,
    firstName,
    lastName,
    relation,
    dateOfBirth,
    gender,
    bloodGroup,
    phoneE164,
    guardianNote,
    version,
    Object.hashAll(allergies),
  );

  /// Id only — never a name in a log.
  @override
  String toString() => 'Person($id)';

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Person `relation` (§17). `self` is never sent on create — the server
/// refuses it — and the picker offers the other five.
///
/// The app's richer labels ("Son", "Mother", "Wife" …) are *derived* from the
/// wire relation plus the person's gender ([labelFor]) rather than stored,
/// because the backend has no field for them.
enum PersonRelation {
  self('self', 'You'),
  spouse('spouse', 'Spouse'),
  child('child', 'Child'),
  parent('parent', 'Parent'),
  sibling('sibling', 'Sibling'),
  other('other', 'Other');

  const PersonRelation(this.wire, this.label);

  final String wire;

  /// The neutral label ("Child"); see [labelFor] for the gendered one.
  final String label;

  /// The five relations a dependant may have.
  static const List<PersonRelation> selectable = [
    spouse,
    child,
    parent,
    sibling,
    other,
  ];

  /// What the picker says under the label.
  String get hint => switch (this) {
    PersonRelation.self => 'Your own record',
    PersonRelation.spouse => 'Husband or wife',
    PersonRelation.child => 'Son or daughter',
    PersonRelation.parent => 'Father or mother',
    PersonRelation.sibling => 'Brother or sister',
    PersonRelation.other => 'Any other family member or ward',
  };

  /// "Daughter" for `child` + female, "Parent" when the gender is unknown.
  String labelFor(Gender? gender) => switch ((this, gender)) {
    (PersonRelation.spouse, Gender.male) => 'Husband',
    (PersonRelation.spouse, Gender.female) => 'Wife',
    (PersonRelation.child, Gender.male) => 'Son',
    (PersonRelation.child, Gender.female) => 'Daughter',
    (PersonRelation.parent, Gender.male) => 'Father',
    (PersonRelation.parent, Gender.female) => 'Mother',
    (PersonRelation.sibling, Gender.male) => 'Brother',
    (PersonRelation.sibling, Gender.female) => 'Sister',
    _ => label,
  };

  static PersonRelation fromWire(String? value) => values.firstWhere(
    (r) => r.wire == value,
    orElse: () => PersonRelation.other,
  );
}

/// `gender` (§17).
enum Gender {
  female('female', 'Female'),
  male('male', 'Male'),
  other('other', 'Other'),
  undisclosed('undisclosed', 'Prefer not to say');

  const Gender(this.wire, this.label);

  final String wire;
  final String label;

  static Gender? fromWire(String? value) {
    for (final gender in values) {
      if (gender.wire == value) return gender;
    }
    return null;
  }
}

/// The eight blood groups (§17), spelled once.
abstract final class BloodGroups {
  BloodGroups._();

  static const List<String> all = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
}

/// What `POST`/`PATCH /patient/me/persons` takes. Every field optional so a
/// PATCH sends only what changed; POST requires [firstName] and [relation].
class PersonDraft {
  const PersonDraft({
    this.firstName,
    this.lastName,
    this.relation,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.allergies,
    this.phoneE164,
    this.guardianNote,
    this.clearLastName = false,
    this.clearDateOfBirth = false,
    this.clearGender = false,
    this.clearBloodGroup = false,
    this.clearPhone = false,
    this.clearGuardianNote = false,
  });

  final String? firstName;
  final String? lastName;
  final PersonRelation? relation;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final String? bloodGroup;
  final List<String>? allergies;
  final String? phoneE164;
  final String? guardianNote;

  /// Explicit nulls: "remove this value" as opposed to "leave it alone".
  final bool clearLastName;
  final bool clearDateOfBirth;
  final bool clearGender;
  final bool clearBloodGroup;
  final bool clearPhone;
  final bool clearGuardianNote;

  bool get isEmpty =>
      firstName == null &&
      lastName == null &&
      relation == null &&
      dateOfBirth == null &&
      gender == null &&
      bloodGroup == null &&
      allergies == null &&
      phoneE164 == null &&
      guardianNote == null &&
      !clearLastName &&
      !clearDateOfBirth &&
      !clearGender &&
      !clearBloodGroup &&
      !clearPhone &&
      !clearGuardianNote;
}

/// `POST …/release/verify` → what moved with the person (§5.8).
class ReleaseResult {
  const ReleaseResult({
    required this.personId,
    required this.userId,
    this.moved = const <String, int>{},
  });

  final String personId;
  final String userId;

  /// `moved` counts: appointments, payments, receipts …
  final Map<String, int> moved;

  int get movedAppointments => moved['appointments'] ?? 0;
}
