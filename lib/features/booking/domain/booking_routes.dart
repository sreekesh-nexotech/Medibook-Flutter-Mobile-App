import '../../../app/router/app_routes.dart';
import '../../../core/mock_data/models/location.dart';

/// The discovery funnel's route composition (CM-10, CM-11).
///
/// `AppRoutes` owns every *path*; this owns the two query shapes the funnel
/// added on top of them, so no screen hand-writes a query string:
///
/// * `/hospitals?city=&area=&dept=` — the hospital list, optionally narrowed
///   to a location and a department.
/// * `/booking?…&hospital=` — the booking flow entered through a facility.
///
/// It lives in `domain/` rather than in `lib/app/router/`, which the
/// orchestrator owns, and it *wraps* `AppRoutes.bookingPath` rather than
/// re-implementing it — so `step` / `dept` / `doctor` / `origin` stay spelled
/// in exactly one place and this file can only ever add to them.
abstract final class BookingRoutes {
  BookingRoutes._();

  /// The booking flow, optionally entered at a facility.
  ///
  /// With [hospital] null this returns `AppRoutes.bookingPath(...)` verbatim,
  /// so the department-first entry from Home and Search is byte-for-byte what
  /// it was before CM-11.
  static String booking({
    int step = 1,
    String? hospital,
    String? dept,
    String? doctor,
    String origin = 'home',
  }) {
    final base = AppRoutes.bookingPath(
      step: step,
      dept: dept,
      doctor: doctor,
      origin: origin,
    );
    return hospital == null ? base : '$base&hospital=$hospital';
  }

  /// The hospital list, narrowed to a city/area and/or a department.
  static String hospitals({String? city, String? area, String? dept}) {
    final query = <String>[
      if (city != null) 'city=${Uri.encodeQueryComponent(city)}',
      if (area != null) 'area=${Uri.encodeQueryComponent(area)}',
      if (dept != null) 'dept=${Uri.encodeQueryComponent(dept)}',
    ];
    return query.isEmpty
        ? AppRoutes.hospitals
        : '${AppRoutes.hospitals}?${query.join('&')}';
  }

  /// [hospitals] for a picked [Location].
  static String hospitalsIn(Location location, {String? dept}) =>
      hospitals(city: location.city, area: location.area, dept: dept);
}
