/// A selectable city + area pair — the top of the discovery funnel
/// (`FLUTTER_API_INTEGRATION.md` §7.1).
///
/// Domain entity: immutable, no JSON, no Flutter. Coordinates arrive as
/// decimal strings or null (§1.11), so they are kept as strings here and
/// parsed only where a number is needed.
class Location {
  const Location({
    required this.id,
    required this.city,
    required this.area,
    required this.state,
    this.lat,
    this.lng,
    this.isPopular = false,
  });

  final String id;
  final String city;
  final String area;
  final String state;
  final String? lat;
  final String? lng;

  /// Surfaced in the "Popular" shortcut row above the full list.
  final bool isPopular;

  /// "Kadavanthra, Kochi" — the chip and header label.
  String get label => '$area, $city';

  @override
  bool operator ==(Object other) => other is Location && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
