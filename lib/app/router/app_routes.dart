/// Central route path + name registry. Screens navigate with these constants
/// (via `context.go` / `context.push`) so paths live in exactly one place.
///
/// The four shell tabs (home / appointments / records / profile) render inside
/// a bottom-nav [StatefulShellRoute]; everything else is a pushed full-screen
/// route. Payloads are passed as path/query params (strings) rather than
/// `extra` objects so deep links and the future guards stay simple.
abstract final class AppRoutes {
  AppRoutes._();

  // ---- Auth ----
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgot = '/forgot';
  static const String verify = '/verify';
  static const String reset = '/reset';

  // ---- Shell tabs ----
  static const String home = '/home';
  static const String appointments = '/appointments';
  static const String records = '/records';
  static const String profile = '/profile';

  // ---- Pushed ----
  static const String search = '/search';
  static const String notifications = '/notifications';

  /// Booking flow. Query: `step` (1-4), `dept`, `doctor`, `origin`
  /// (home|appointments). e.g. `/booking?step=3&doctor=anya&origin=home`.
  static const String booking = '/booking';

  /// Doctor detail. `/doctor/:id?return=booking|search|home`.
  static const String doctor = '/doctor';
  static String doctorPath(String id, {String returnTo = 'home'}) =>
      '/doctor/$id?return=$returnTo';

  /// Booking success. `/success?appt=<appointmentId>`.
  static const String success = '/success';
  static String successPath(String appointmentId) => '/success?appt=$appointmentId';

  /// Appointment detail. `/appointment/:id`.
  static const String appointmentDetail = '/appointment';
  static String appointmentDetailPath(String id) => '/appointment/$id';

  /// Reschedule. `/reschedule/:id`.
  static const String reschedule = '/reschedule';
  static String reschedulePath(String id) => '/reschedule/$id';

  /// Build a booking entry path from typed params.
  static String bookingPath({
    int step = 1,
    String? dept,
    String? doctor,
    String origin = 'home',
  }) {
    final q = <String>['step=$step', 'origin=$origin'];
    if (dept != null) q.add('dept=${Uri.encodeQueryComponent(dept)}');
    if (doctor != null) q.add('doctor=$doctor');
    return '$booking?${q.join('&')}';
  }
}

/// Bottom-nav tab keys (must match the design-system `BottomNav` keys and the
/// shell branch order).
enum AppTab { home, appointments, records, profile }
