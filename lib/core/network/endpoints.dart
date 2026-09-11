/// The complete path registry for the Medibook patient API.
///
/// Paths only — no host, no client, no serialization. The base URL comes from
/// `app/config/env.dart` and is joined by [ApiClient]; keeping the two apart is
/// what lets dev/staging/prod differ by one `--dart-define`.
///
/// Rules for this file:
/// * every path appears exactly once, as a constant or a builder;
/// * builders percent-encode their segments, so an id with a `/` cannot escape
///   its position in the path;
/// * nothing here reads state.
abstract final class Endpoints {
  Endpoints._();

  /// Version prefix applied by [ApiClient] rather than repeated below.
  static const String apiVersion = 'v1';

  static String _seg(String value) => Uri.encodeComponent(value);

  // ---- Auth (CM-01 … CM-08, CM-53) ----
  static const String login = '/auth/login';
  static const String loginWithOtp = '/auth/login/otp';
  static const String requestOtp = '/auth/otp/request';
  static const String verifyOtp = '/auth/otp/verify';
  static const String signup = '/auth/signup';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/password/forgot';
  static const String resetPassword = '/auth/password/reset';
  static const String changePassword = '/auth/password/change';
  static const String deleteAccount = '/auth/account';

  // ---- Profile / account (CM-47 … CM-51) ----
  static const String me = '/me';
  static const String profile = '/me/profile';
  static const String addresses = '/me/addresses';
  static String address(String id) => '/me/addresses/${_seg(id)}';
  static const String emergencyContacts = '/me/emergency-contacts';
  static String emergencyContact(String id) =>
      '/me/emergency-contacts/${_seg(id)}';

  // ---- Dependants (CM-16, CM-48) ----
  static const String dependants = '/me/dependants';
  static String dependant(String id) => '/me/dependants/${_seg(id)}';

  // ---- Discovery (CM-10, CM-11, CM-25 … CM-31) ----
  static const String locations = '/locations';
  static const String hospitals = '/hospitals';
  static String hospital(String id) => '/hospitals/${_seg(id)}';
  static const String departments = '/departments';
  static const String doctors = '/doctors';
  static String doctor(String id) => '/doctors/${_seg(id)}';
  static const String search = '/search';

  /// Slot availability for a doctor on one day (CM-12).
  /// `GET /doctors/{id}/slots?date=2026-08-12`
  static String doctorSlots(String doctorId) =>
      '/doctors/${_seg(doctorId)}/slots';

  // ---- Appointments (CM-13 … CM-24) ----
  static const String appointments = '/appointments';
  static String appointment(String id) => '/appointments/${_seg(id)}';
  static String cancelAppointment(String id) =>
      '/appointments/${_seg(id)}/cancel';
  static String rescheduleAppointment(String id) =>
      '/appointments/${_seg(id)}/reschedule';
  static String appointmentReceipt(String id) =>
      '/appointments/${_seg(id)}/receipt';

  /// Live queue / token progress for a doctor (CM-09, CM-24).
  static String queueStatus(String doctorId) =>
      '/doctors/${_seg(doctorId)}/queue';

  // ---- Fees & payments (CM-13, CM-17 … CM-22) ----
  static const String feeQuote = '/payments/quote';
  static const String applyCoupon = '/payments/coupon';
  static const String payments = '/payments';
  static String payment(String id) => '/payments/${_seg(id)}';
  static String refund(String paymentId) =>
      '/payments/${_seg(paymentId)}/refund';

  // ---- Records & documents (CM-32 … CM-36) ----
  static const String documents = '/documents';
  static String document(String id) => '/documents/${_seg(id)}';
  static const String documentUpload = '/documents/upload';
  static String documentDownload(String id) =>
      '/documents/${_seg(id)}/download';

  // ---- Insurance (CM-37 … CM-39) ----
  static const String insurancePolicies = '/insurance/policies';
  static String insurancePolicy(String id) => '/insurance/policies/${_seg(id)}';

  // ---- Notifications (CM-40 … CM-43) ----
  static const String notifications = '/notifications';
  static String notification(String id) => '/notifications/${_seg(id)}';
  static const String notificationsReadAll = '/notifications/read-all';
  static const String notificationPreferences = '/notifications/preferences';
  static const String devicePushToken = '/notifications/device';

  // ---- Ambulance (CM-44 … CM-46) ----
  static const String ambulanceProviders = '/ambulance/providers';
  static const String ambulanceRequests = '/ambulance/requests';

  // ---- Content (CM-02, CM-52) ----
  static const String faqs = '/content/faqs';
  static const String promoBanners = '/content/banners';
  static const String supportTickets = '/support/tickets';

  /// Terms / privacy / guidelines, addressed by slug.
  static String legalDocument(String slug) => '/content/legal/${_seg(slug)}';

  // ---- Query builders ----

  /// Joins [path] with [query], dropping null values, so callers never
  /// hand-assemble a query string.
  ///
  /// ```dart
  /// Endpoints.withQuery(Endpoints.doctors, {'city': 'Kochi', 'page': 1});
  /// // '/doctors?city=Kochi&page=1'
  /// ```
  static String withQuery(String path, Map<String, Object?> query) {
    final pairs = <String, String>{};
    for (final entry in query.entries) {
      final value = entry.value;
      if (value == null) continue;
      pairs[entry.key] = value.toString();
    }
    if (pairs.isEmpty) return path;
    return Uri(path: path, queryParameters: pairs).toString();
  }

  /// Standard pagination query. Page numbers are 1-based server-side.
  static Map<String, Object?> page(int page, {int? size}) => {
    'page': page,
    'per_page': size,
  };
}
