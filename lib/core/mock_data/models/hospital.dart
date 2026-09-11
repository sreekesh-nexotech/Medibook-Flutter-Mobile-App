/// A hospital or clinic — the facility a doctor practises at and the anchor for
/// location-first discovery (CM-10, CM-11, CM-25).
///
/// Presentation view-model — immutable, no logic. Maps onto the future
/// `domain/entities` Hospital entity.
class Hospital {
  const Hospital({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.area,
    required this.departments,
    required this.rating,
    required this.distanceKm,
    required this.openingHours,
    this.latitude,
    this.longitude,
    this.imageAsset,
    this.phone,
  });

  final String id;
  final String name;

  /// Street address, one line.
  final String address;

  /// City ("Kochi") — the coarse location filter.
  final String city;

  /// Neighbourhood ("Kakkanad") — the fine location filter.
  final String area;

  /// Coordinates, when known. Null for facilities not yet geocoded, so the
  /// map/distance affordances must handle their absence.
  final double? latitude;
  final double? longitude;

  /// Hero image; null → the UI falls back to a tinted initial block.
  final String? imageAsset;

  /// Department names offered here (match [Department.name]).
  final List<String> departments;

  /// Rating out of 5.
  final double rating;

  /// Distance from the user, in km. Seeded as a plausible constant; the real
  /// value comes from the device location.
  final double distanceKm;

  /// Human opening hours ("Open 24 hours", "8:00 AM – 9:00 PM").
  final String openingHours;

  /// Reception number, E.164-ish for `tel:` links.
  final String? phone;

  /// "Kakkanad, Kochi" — the one-line location label.
  String get locationLabel => '$area, $city';

  /// "2.4 km away".
  String get distanceLabel => '${distanceKm.toStringAsFixed(1)} km away';

  /// True when this facility can be pinned on a map.
  bool get hasCoordinates => latitude != null && longitude != null;

  /// Whether this facility offers [department].
  bool offers(String department) => departments.contains(department);
}

/// The canonical hospital directory.
///
/// This exists so `Doctor.hospital` can be a *derived* name rather than a
/// duplicated string (audit finding: the same facility name was repeated on
/// every doctor row, with nothing keeping the copies in sync). `Doctor` stores
/// only [Doctor.hospitalId]; the display name is looked up here.
///
/// The list lives beside the model rather than in `medibook_seed.dart` purely
/// so the model can resolve a name without importing the seed file (which
/// imports the models). `MedibookSeed.hospitals` re-exports [all], so screens
/// still read seed data through the providers as before.
abstract final class Hospitals {
  Hospitals._();

  static const Hospital apollo = Hospital(
    id: 'apollo',
    name: 'Apollo Hospital',
    address: 'NH 544, Seaport-Airport Road, Kakkanad',
    city: 'Kochi',
    area: 'Kakkanad',
    latitude: 10.0159,
    longitude: 76.3419,
    imageAsset: 'assets/images/hospital.jpg',
    departments: ['General', 'Cardiology', 'Orthopedics'],
    rating: 4.7,
    distanceKm: 2.4,
    openingHours: 'Open 24 hours',
    phone: '+914842345678',
  );

  static const Hospital cityCare = Hospital(
    id: 'city-care',
    name: 'City Care Clinic',
    address: '2nd Floor, Pallimukku Junction, MG Road',
    city: 'Kochi',
    area: 'Ernakulam South',
    latitude: 9.9658,
    longitude: 76.2853,
    departments: ['General', 'Cardiology', 'Dermatology'],
    rating: 4.4,
    distanceKm: 5.1,
    openingHours: '8:00 AM – 9:00 PM',
    phone: '+914842456789',
  );

  static const Hospital lakeshore = Hospital(
    id: 'lakeshore',
    name: 'Lakeshore Medical Centre',
    address: 'NH Bypass, Maradu',
    city: 'Kochi',
    area: 'Maradu',
    latitude: 9.9312,
    longitude: 76.3157,
    departments: ['General', 'Orthopedics', 'Dermatology'],
    rating: 4.6,
    distanceKm: 7.8,
    openingHours: 'Open 24 hours',
    phone: '+914842567890',
  );

  static const Hospital greenLeaf = Hospital(
    id: 'green-leaf',
    name: 'Green Leaf Family Clinic',
    address: 'Chittoor Road, Near North Railway Station',
    city: 'Kochi',
    area: 'Kaloor',
    // Deliberately un-geocoded: the map/distance UI must survive a facility
    // with no coordinates.
    imageAsset: null,
    departments: ['General', 'Dermatology'],
    rating: 4.2,
    distanceKm: 3.6,
    openingHours: '9:00 AM – 7:00 PM · Closed Sunday',
  );

  static const Hospital sunriseChildren = Hospital(
    id: 'sunrise-children',
    name: "Sunrise Children's Hospital",
    address: 'Panampilly Nagar, Ernakulam',
    city: 'Kochi',
    area: 'Panampilly Nagar',
    latitude: 9.9535,
    longitude: 76.2972,
    departments: ['General'],
    rating: 4.8,
    distanceKm: 6.2,
    openingHours: 'Open 24 hours',
    phone: '+914842678901',
  );

  /// Every facility, in display order.
  static const List<Hospital> all = [
    apollo,
    cityCare,
    lakeshore,
    greenLeaf,
    sunriseChildren,
  ];

  /// Look up by id; falls back to the first facility so a bad id renders
  /// something rather than throwing inside a `build`.
  static Hospital byId(String id) =>
      all.firstWhere((h) => h.id == id, orElse: () => all.first);

  /// The display name for [id] — what `Doctor.hospital` returns.
  static String nameOf(String id) => byId(id).name;
}
