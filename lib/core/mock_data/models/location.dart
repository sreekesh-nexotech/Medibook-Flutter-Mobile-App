/// A selectable city + area pair — the top of the discovery funnel (CM-10:
/// "location-first discovery").
///
/// Presentation view-model — immutable, no logic. The picker groups by [city]
/// and lists [area] beneath it, so a city with one area still reads correctly.
class Location {
  const Location({
    required this.city,
    required this.area,
    this.isPopular = false,
  });

  final String city;
  final String area;

  /// Surfaced in the "Popular" shortcut row above the full list.
  final bool isPopular;

  /// "Kakkanad, Kochi" — the chip and header label.
  String get label => '$area, $city';

  /// Stable key for selection state and the `?city=&area=` query.
  String get key => '$city/$area';

  @override
  bool operator ==(Object other) =>
      other is Location && other.city == city && other.area == area;

  @override
  int get hashCode => Object.hash(city, area);

  @override
  String toString() => 'Location($label)';
}
