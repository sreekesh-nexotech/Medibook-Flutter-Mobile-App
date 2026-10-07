import '../../../common/persons/domain/entities/person_summary.dart'
    show personRelationLabel;

/// The little the booking flow needs to know about a family member (§6.1):
/// who they are, so the "Appointment for" picker can name them. The full
/// `Person` lives in the profile feature; this is a read-only projection.
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

  /// `self` | `spouse` | `child` | `parent` | `sibling` | `other`.
  final String relation;
  final bool isSelf;

  /// `YYYY-MM-DD`, or null.
  final String? dateOfBirth;
  final String? gender;

  String get fullName => [
    firstName,
    if (lastName != null && lastName!.isNotEmpty) lastName,
  ].join(' ');

  /// "Wife" / "Son" / "Parent" — worded as Family Members words it, from
  /// the relation and gender (it said "Spouse" / "Child" here only).
  String get relationLabel => personRelationLabel(relation, gender);
}
