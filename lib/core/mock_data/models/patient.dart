/// A patient in the account (self + family), shown in booking step 3.
///
/// Presentation view-model — immutable, no logic.
class Patient {
  const Patient({
    required this.name,
    required this.meta,
    required this.relation,
  });

  final String name;

  /// "29 years · Female".
  final String meta;

  /// Relation chip ("Self", "Husband", "Daughter").
  final String relation;
}
