import '../../../app/router/app_routes.dart';
import '../domain/entities/location.dart';

/// The discovery funnel's route composition (CM-10, CM-11).
///
/// `AppRoutes` owns every *path*; this owns the query shapes the funnel adds
/// on top of them, so no screen hand-writes a query string:
///
/// * `/hospitals?city=&area=&dept=` — the hospital list, optionally narrowed
///   to a location and a department **code**.
/// * `/booking?…&hospital=&slot=` — the booking flow entered through a
///   facility, optionally with a slot **id** already chosen.
///
/// It lives in `domain/` rather than in `lib/app/router/`, which the
/// orchestrator owns, and it *wraps* `AppRoutes.bookingPath` rather than
/// re-implementing it.
abstract final class BookingRoutes {
  BookingRoutes._();

  /// The booking flow, optionally entered at a facility. [resume] keeps the
  /// booking already in progress (department, hospital, doctor, patient,
  /// notes) and only moves to [step] — "Book again" after a lapsed payment
  /// (BL-PAY-028).
  /// [dept] is a
  /// department code; [doctor] a doctor id; [slot] a slot id (§8.2).
  static String booking({
    int step = 1,
    String? hospital,
    String? dept,
    String? doctor,
    String origin = 'home',
    String? slot,
    bool resume = false,
  }) {
    final base = AppRoutes.bookingPath(
      step: step,
      dept: dept,
      doctor: doctor,
      origin: origin,
    );
    return [
      base,
      if (hospital != null) 'hospital=${Uri.encodeQueryComponent(hospital)}',
      if (slot != null) 'slot=${Uri.encodeQueryComponent(slot)}',
      if (resume) 'resume=1',
    ].join('&');
  }

  /// The hospital list, narrowed to a city/area and/or a department code.
  static String hospitals({String? city, String? area, String? dept}) {
    final query = <String>[
      if (city != null) 'city=${Uri.encodeQueryComponent(city)}',
      if (area != null && area.isNotEmpty)
        'area=${Uri.encodeQueryComponent(area)}',
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

/// The `status` values `/booking/payment/result` renders (§9.3–§9.6), on top
/// of the three `AppRoutes.paymentStatus*` constants the router declares.
abstract final class PaymentResultStatus {
  PaymentResultStatus._();

  /// Paid; the appointment is scheduled.
  static const String success = AppRoutes.paymentStatusSuccess;

  /// The gateway declined, the signature failed, or the sheet was closed.
  static const String failed = AppRoutes.paymentStatusFailed;

  /// Paid; the hospital confirms online bookings by hand.
  static const String pendingApproval = AppRoutes.paymentStatusPending;

  /// Money arrived after the deadline: cancelled, refund initiated.
  static const String late = 'late';

  /// The 5 minutes ran out before a payment was made.
  static const String expired = 'expired';

  static const List<String> all = [
    success,
    failed,
    pendingApproval,
    late,
    expired,
  ];
}
