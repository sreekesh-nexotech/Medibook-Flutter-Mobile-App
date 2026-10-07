/// The city (and optionally area) the patient chose to browse in (CL
/// DISC-001). Home and the Hospitals list are scoped to it until it is
/// cleared.
class LocationScope {
  const LocationScope({required this.city, this.area});

  final String city;

  /// Null or empty means the whole city.
  final String? area;

  bool get hasArea => area != null && area!.isNotEmpty;

  /// "Kadavanthra, Kochi", or just "Kochi".
  String get label => hasArea ? '$area, $city' : city;

  @override
  bool operator ==(Object other) =>
      other is LocationScope && other.city == city && other.area == area;

  @override
  int get hashCode => Object.hash(city, area);
}
