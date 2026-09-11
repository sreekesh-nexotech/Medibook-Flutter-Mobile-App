/// Central route path + name registry. Screens navigate with these constants
/// (via `context.go` / `context.push`) so paths live in exactly one place.
///
/// The four shell tabs (home / appointments / records / profile) render inside
/// a bottom-nav [StatefulShellRoute]; everything else is a pushed full-screen
/// route. Payloads are passed as path/query params (strings) rather than
/// `extra` objects so deep links and the future guards stay simple.
///
/// ## Deep links (audit §3.7.3)
///
/// Neither platform declared a link scheme, so nothing could open the app at a
/// screen — not a push notification, not an appointment-reminder SMS, not a
/// support email. Both platforms now declare:
///
/// * the custom scheme `medibook://…` (host-less), and
/// * Android App Links / iOS Universal Links for `https://medibook.app/…`.
///
/// [AppRoutes.fromDeepLink] maps either shape onto an in-app path. It lives
/// here rather than in `app_router.dart` so the mapping is testable without a
/// router, and so the router only has to call one function.
abstract final class AppRoutes {
  AppRoutes._();

  // ---- Auth ----
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgot = '/forgot';
  static const String verify = '/verify';
  static const String reset = '/reset';

  /// Sign-in lockout (CM-05). Query: `until` (ISO-8601) so the countdown
  /// survives a route rebuild. e.g. `/lockout?until=2026-09-11T10:31:00Z`.
  static const String lockout = '/lockout';
  static String lockoutPath(DateTime until) =>
      '$lockout?until=${Uri.encodeQueryComponent(until.toIso8601String())}';

  /// Change password for a signed-in user (CM-51).
  static const String changePassword = '/change-password';

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
  static String successPath(String appointmentId) =>
      '/success?appt=$appointmentId';

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

  // ---- Legal & support (CM-02, CM-52) ----

  /// Terms / Privacy / Guidelines. `/legal/:slug`, slug ∈
  /// [legalTerms] | [legalPrivacy] | [legalGuidelines].
  static const String legal = '/legal';
  static String legalPath(String slug) => '$legal/$slug';

  static const String legalTerms = 'terms';
  static const String legalPrivacy = 'privacy';
  static const String legalGuidelines = 'guidelines';

  /// The slugs `/legal/:slug` accepts — anything else is a not-found.
  static const List<String> legalSlugs = [
    legalTerms,
    legalPrivacy,
    legalGuidelines,
  ];

  static const String help = '/help';
  static const String faq = '/faq';
  static const String support = '/support';

  // ---- Profile & account (CM-47 … CM-51) ----
  static const String profileEdit = '/profile/edit';
  static const String profilePassword = '/profile/password';
  static const String profileAddress = '/profile/address';
  static const String profileEmergency = '/profile/emergency';

  /// Family members list (CM-16, CM-48).
  static const String dependants = '/dependants';

  /// Add or edit a dependant. `/dependants/edit?id=<patientId>`; omit `id` to
  /// add.
  static const String dependantEdit = '/dependants/edit';
  static String dependantEditPath([String? id]) =>
      id == null ? dependantEdit : '$dependantEdit?id=$id';

  // ---- Insurance (CM-37 … CM-39) ----
  static const String insurance = '/insurance';
  static const String insuranceAdd = '/insurance/add';

  /// Policy detail. `/insurance/:id`.
  static String insurancePath(String id) => '$insurance/$id';

  // ---- Documents (CM-32 … CM-36) ----
  static const String documentUpload = '/documents/upload';

  /// Document detail / preview. `/documents/:id`.
  static const String documents = '/documents';
  static String documentPath(String id) => '$documents/$id';

  // ---- Discovery (CM-10, CM-11, CM-25) ----
  static const String locations = '/locations';
  static const String hospitals = '/hospitals';

  /// Hospital detail. `/hospital/:id`.
  static const String hospital = '/hospital';
  static String hospitalPath(String id) => '$hospital/$id';

  // ---- Payment (CM-17 … CM-22) ----
  static const String bookingPayment = '/booking/payment';

  /// Payment outcome. `/booking/payment/result?status=success|failed|pending`.
  static const String bookingPaymentResult = '/booking/payment/result';
  static String bookingPaymentResultPath(
    String status, {
    String? appointmentId,
  }) {
    final q = <String>['status=$status'];
    if (appointmentId != null) q.add('appt=$appointmentId');
    return '$bookingPaymentResult?${q.join('&')}';
  }

  static const String paymentStatusSuccess = 'success';
  static const String paymentStatusFailed = 'failed';
  static const String paymentStatusPending = 'pending';

  /// Receipt / GST invoice. `/receipt/:appointmentId` (CM-21).
  static const String receipt = '/receipt';
  static String receiptPath(String appointmentId) => '$receipt/$appointmentId';

  // ---- Appointments search & filter (CM-23) ----
  static const String appointmentsSearch = '/appointments/search';
  static const String appointmentsFilter = '/appointments/filter';

  // ---- Live queue (CM-09, CM-24) ----

  /// Token progress. `/queue/:doctorId`.
  static const String queue = '/queue';
  static String queuePath(String doctorId) => '$queue/$doctorId';

  // ---- Emergency (CM-44 … CM-46) ----
  static const String ambulance = '/ambulance';

  // ---- Fallback ----

  /// The designed "page not found" screen (audit §3.2.4). Also what
  /// `GoRouter.errorBuilder` should render.
  static const String notFound = '/notfound';

  // ---- Deep links ----

  /// The custom URL scheme declared on both platforms.
  static const String deepLinkScheme = 'medibook';

  /// The verified App Links / Universal Links host.
  static const String deepLinkHost = 'medibook.app';

  /// Maps an incoming deep link onto an in-app path, or null when it does not
  /// address a known screen.
  ///
  /// Accepts both declared shapes, which differ in where the path starts:
  ///
  /// ```text
  /// medibook://appointment/42          → host='appointment', path='/42'
  /// https://medibook.app/appointment/42 → host='medibook.app', path='/appointment/42'
  /// ```
  ///
  /// so the segments are normalised before matching. Query parameters are
  /// carried through unchanged.
  ///
  /// A null return means "show the not-found screen", **not** "ignore" — a
  /// link that silently does nothing is worse than one that explains itself.
  ///
  /// Wiring (in `app_router.dart`, which this file does not touch):
  ///
  /// ```dart
  /// GoRouter(
  ///   redirect: (context, state) {
  ///     final mapped = AppRoutes.fromDeepLink(state.uri);
  ///     return mapped == state.uri.toString() ? null : mapped;
  ///   },
  /// );
  /// ```
  static String? fromDeepLink(Uri uri) {
    final segments = _deepLinkSegments(uri);
    if (segments.isEmpty) return home;

    final query = uri.query.isEmpty ? '' : '?${uri.query}';
    final first = segments.first;
    final second = segments.length > 1 ? segments[1] : null;

    // Paths whose first segment is the whole route.
    const simple = <String, String>{
      'home': home,
      'login': login,
      'signup': signup,
      'appointments': appointments,
      'records': records,
      'profile': profile,
      'notifications': notifications,
      'search': search,
      'booking': booking,
      'locations': locations,
      'hospitals': hospitals,
      'dependants': dependants,
      'insurance': insurance,
      'documents': documents,
      'help': help,
      'faq': faq,
      'support': support,
      'ambulance': ambulance,
    };

    switch (first) {
      // Single-id detail routes.
      case 'appointment':
        return second == null
            ? appointments
            : '${appointmentDetailPath(second)}$query';
      case 'doctor':
        return second == null ? booking : '/doctor/$second$query';
      case 'hospital':
        return second == null ? hospitals : '${hospitalPath(second)}$query';
      case 'queue':
        return second == null ? home : '${queuePath(second)}$query';
      case 'receipt':
        return second == null ? appointments : '${receiptPath(second)}$query';
      case 'reschedule':
        return second == null
            ? appointments
            : '${reschedulePath(second)}$query';
      case 'legal':
        // An unknown slug is a not-found, not a silent redirect to Terms.
        if (second == null) return legalPath(legalTerms);
        return legalSlugs.contains(second) ? legalPath(second) : null;
      case 'documents':
        return second == null ? documents : '${documentPath(second)}$query';
      case 'insurance':
        if (second == null) return insurance;
        if (second == 'add') return insuranceAdd;
        return insurancePath(second);
    }

    final matched = simple[first];
    if (matched == null) return null;

    // Preserve any deeper path we recognise verbatim (e.g. /profile/edit).
    if (segments.length > 1) {
      final full = '/${segments.join('/')}';
      return _knownNestedPaths.contains(full) ? '$full$query' : null;
    }
    return '$matched$query';
  }

  /// Nested paths a deep link may address directly.
  static const List<String> _knownNestedPaths = [
    profileEdit,
    profilePassword,
    profileAddress,
    profileEmergency,
    dependantEdit,
    insuranceAdd,
    documentUpload,
    bookingPayment,
    bookingPaymentResult,
    appointmentsSearch,
    appointmentsFilter,
  ];

  /// Path segments of [uri], normalised across the two link shapes.
  ///
  /// A custom-scheme link puts its first segment in the *host* (`medibook://
  /// appointment/42` parses as host `appointment`, path `/42`), so that host is
  /// prepended. An `https://medibook.app/...` link keeps its host as a host and
  /// contributes only its path.
  static List<String> _deepLinkSegments(Uri uri) {
    final segments = <String>[...uri.pathSegments.where((s) => s.isNotEmpty)];
    final host = uri.host;
    if (uri.scheme == deepLinkScheme && host.isNotEmpty) {
      segments.insert(0, host);
    }
    return segments;
  }
}

/// Bottom-nav tab keys (must match the design-system `BottomNav` keys and the
/// shell branch order).
enum AppTab { home, appointments, records, profile }
