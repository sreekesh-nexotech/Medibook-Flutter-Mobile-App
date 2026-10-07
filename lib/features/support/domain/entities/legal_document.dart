/// `GET /patient/legal/{slug}` (§3.2): one published policy document.
///
/// `slug` ∈ `terms` | `privacy` | `guidelines`. [bodyMd] is Markdown; the
/// presentation layer renders the small subset the documents use (headings,
/// paragraphs, bullets, bold) without a markdown package.
class LegalDocument {
  const LegalDocument({
    required this.slug,
    required this.version,
    required this.title,
    required this.bodyMd,
    this.publishedAt,
  });

  final String slug;

  /// The published version — what `POST /patient/me/consents` accepts.
  final int version;

  final String title;
  final String bodyMd;

  /// Null when the server has no publication date.
  final DateTime? publishedAt;

  @override
  bool operator ==(Object other) =>
      other is LegalDocument &&
      other.slug == slug &&
      other.version == version &&
      other.title == title &&
      other.bodyMd == bodyMd &&
      other.publishedAt == publishedAt;

  @override
  int get hashCode => Object.hash(slug, version, title, bodyMd, publishedAt);

  @override
  String toString() => 'LegalDocument($slug v$version)';
}
