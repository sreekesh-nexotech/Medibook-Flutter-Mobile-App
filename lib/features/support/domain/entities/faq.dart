/// `GET /patient/faqs` (§3.3): categories, each with ordered entries.
class FaqCategory {
  const FaqCategory({required this.category, required this.entries});

  /// The wire category key (`booking`, `payments` …). Displayed title-cased.
  final String category;

  /// Sorted by `sort_order` on the wire; kept in that order.
  final List<FaqEntry> entries;

  @override
  bool operator ==(Object other) =>
      other is FaqCategory &&
      other.category == category &&
      _listEquals(other.entries, entries);

  @override
  int get hashCode => Object.hash(category, Object.hashAll(entries));

  static bool _listEquals(List<FaqEntry> a, List<FaqEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// One question and its Markdown answer.
class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.question,
    required this.answerMd,
    required this.category,
    this.sortOrder = 0,
  });

  final String id;
  final String question;

  /// Markdown (`answer_md`). Rendered by the support feature's prose parser.
  final String answerMd;

  /// The owning category key, repeated here so a flat search can group.
  final String category;

  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      other is FaqEntry &&
      other.id == id &&
      other.question == question &&
      other.answerMd == answerMd &&
      other.category == category &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, question, answerMd, category, sortOrder);
}
