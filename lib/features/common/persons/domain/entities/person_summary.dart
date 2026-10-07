/// A person on the account (`FLUTTER_API_INTEGRATION.md` §6.1), reduced to
/// what a picker needs: who they are and whether they are the account holder.
///
/// Read-only. The profile feature owns the full `Person` and its CRUD; this
/// summary exists so records and insurance can offer "whose document / whose
/// policy" without depending on that feature.
class PersonSummary {
  const PersonSummary({
    required this.id,
    required this.firstName,
    required this.relation,
    required this.isSelf,
    this.lastName,
    this.dateOfBirth,
    this.gender,
  });

  final String id;
  final String firstName;
  final String? lastName;

  /// `self | spouse | child | parent | sibling | other`, as the wire spells it.
  final String relation;
  final bool isSelf;
  final DateTime? dateOfBirth;
  final String? gender;

  /// "Arjun Nair" / "Arjun".
  String get fullName {
    final last = lastName;
    return last == null || last.isEmpty ? firstName : '$firstName $last';
  }

  /// How they are related to the account holder — "You", "Wife", "Son",
  /// "Parent" … — from the wire [relation] and [gender]; see
  /// [personRelationLabel].
  String get relationLabel => personRelationLabel(relation, gender);
}

/// How a person is related to the account holder — "You", "Wife", "Son",
/// "Parent" … — from the wire `relation` and `gender`, worded the way the
/// Family Members screen words it. "Family member" for `other` or a value
/// this build does not know. Shared by every picker that names a person, so
/// booking does not say "Spouse" where Family Members says "Wife".
String personRelationLabel(String relation, String? gender) {
  final isMale = gender == 'male';
  final isFemale = gender == 'female';
  return switch (relation) {
    'self' => 'You',
    'spouse' => isMale ? 'Husband' : (isFemale ? 'Wife' : 'Spouse'),
    'child' => isMale ? 'Son' : (isFemale ? 'Daughter' : 'Child'),
    'parent' => isMale ? 'Father' : (isFemale ? 'Mother' : 'Parent'),
    'sibling' => isMale ? 'Brother' : (isFemale ? 'Sister' : 'Sibling'),
    _ => 'Family member',
  };
}
