/// The little the appointments feature needs from a person (§6.1): enough to
/// print "For Aarav (Son)" next to a booking and to offer a patient filter.
///
/// The full person entity belongs to the profile feature; this is a
/// read-model, so the two features do not have to share a type.
class PersonSummary {
  const PersonSummary({
    required this.id,
    required this.name,
    required this.relation,
    this.isSelf = false,
  });

  final String id;

  /// "Aarav Nair".
  final String name;

  /// `self | spouse | child | parent | sibling | other`.
  final String relation;
  final bool isSelf;

  /// "Aarav Nair (Child)", or the bare name for the account holder.
  String get forLabel {
    if (isSelf || relation == 'self') return name;
    final rel = relation.isEmpty
        ? ''
        : '${relation[0].toUpperCase()}${relation.substring(1)}';
    return rel.isEmpty ? name : '$name ($rel)';
  }
}
