/// A static legal / policy document rendered by `/legal/:slug` (CM-02, CM-52).
///
/// Presentation view-model — immutable, no logic. The body is a very small
/// markdown subset, documented on [bodyMarkdownish], so the renderer can be a
/// plain `Text`/`Column` pair and the app needs no markdown package.
class LegalDocument {
  const LegalDocument({
    required this.slug,
    required this.title,
    required this.bodyMarkdownish,
    required this.version,
    required this.lastUpdated,
  });

  /// URL slug: `terms`, `privacy`, `guidelines`.
  final String slug;

  final String title;

  /// The document body, in a deliberately tiny markdown subset:
  ///
  /// * a line starting `## ` is a section heading,
  /// * a line starting `- ` is a bullet,
  /// * a blank line separates paragraphs,
  /// * everything else is a paragraph.
  ///
  /// That is all the renderer has to support, which is why no markdown
  /// dependency is needed.
  final String bodyMarkdownish;

  /// Version the user consents to, stored as
  /// `HiveKeys.acceptedTermsVersion` so a re-consent can be prompted.
  final String version;

  final DateTime lastUpdated;

  /// The document split into renderable blocks.
  List<LegalBlock> get blocks {
    final result = <LegalBlock>[];
    for (final raw in bodyMarkdownish.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('## ')) {
        result.add(LegalBlock.heading(line.substring(3).trim()));
      } else if (line.startsWith('- ')) {
        result.add(LegalBlock.bullet(line.substring(2).trim()));
      } else {
        result.add(LegalBlock.paragraph(line));
      }
    }
    return result;
  }
}

/// What kind of block a line of a [LegalDocument] is.
enum LegalBlockKind { heading, paragraph, bullet }

/// One renderable line of a [LegalDocument].
class LegalBlock {
  const LegalBlock.heading(this.text) : kind = LegalBlockKind.heading;
  const LegalBlock.paragraph(this.text) : kind = LegalBlockKind.paragraph;
  const LegalBlock.bullet(this.text) : kind = LegalBlockKind.bullet;

  final LegalBlockKind kind;
  final String text;
}

/// One question-and-answer pair on the Help / FAQ screen (CM-52).
///
/// Presentation view-model — immutable, no logic.
class FaqEntry {
  const FaqEntry({
    required this.question,
    required this.answer,
    this.category = 'General',
  });

  final String question;
  final String answer;

  /// Grouping for the FAQ list ("Booking", "Payments", "Records").
  final String category;
}

/// An emergency contact on the account (CM-49).
///
/// Presentation view-model — immutable, no logic.
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relation,
    required this.phone,
    this.isPrimary = false,
  });

  final String id;
  final String name;

  /// "Husband", "Mother", "Neighbour".
  final String relation;

  /// Dialable number, with country code.
  final String phone;

  /// The one contact called first. At most one should be primary, and the
  /// store enforces that.
  final bool isPrimary;

  /// "Michael Johnson · Husband".
  String get label => '$name · $relation';

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? relation,
    String? phone,
    bool? isPrimary,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      phone: phone ?? this.phone,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

/// A saved postal address (CM-50) — used for home sample collection and
/// invoices.
///
/// Presentation view-model — immutable, no logic.
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
    this.line2,
    this.isDefault = false,
  });

  final String id;

  /// "Home", "Work", "Mum's place".
  final String label;

  final String line1;
  final String? line2;
  final String city;
  final String state;

  /// 6-digit Indian PIN code (see `Validators.pincode`).
  final String pincode;

  /// The address used unless another is chosen.
  final bool isDefault;

  /// "12 Marine Drive, Ernakulam, Kochi, Kerala 682031" — one line.
  String get singleLine => [
    line1,
    if (line2 != null && line2!.isNotEmpty) line2,
    city,
    state,
    pincode,
  ].join(', ');

  /// The same address as display lines, for a stacked card.
  List<String> get lines => [
    line1,
    if (line2 != null && line2!.isNotEmpty) line2!,
    '$city, $state $pincode',
  ];

  Address copyWith({
    String? id,
    String? label,
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? pincode,
    bool? isDefault,
  }) {
    return Address(
      id: id ?? this.id,
      label: label ?? this.label,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

/// An ambulance operator the emergency screen can dial (CM-44 … CM-46).
///
/// Presentation view-model — immutable, no logic.
class AmbulanceProvider {
  const AmbulanceProvider({
    required this.name,
    required this.phone,
    required this.etaMinutes,
    required this.area,
    this.isGovernment = false,
    this.supportsAdvancedLifeSupport = false,
  });

  final String name;

  /// Dialable number. `108` is the national emergency line.
  final String phone;

  /// Typical arrival time in [area], in minutes.
  final int etaMinutes;

  final String area;

  /// True for state-run services (free at point of use).
  final bool isGovernment;

  /// True when the vehicle carries ALS equipment.
  final bool supportsAdvancedLifeSupport;

  /// "~12 min".
  String get etaLabel => '~$etaMinutes min';

  /// "ALS · Government" — the capability chips, or an empty list.
  List<String> get tags => [
    if (supportsAdvancedLifeSupport) 'ALS',
    if (isGovernment) 'Government',
  ];
}
