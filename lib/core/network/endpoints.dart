/// The complete path registry for the Medibook patient API
/// (`docs-flutter/FLUTTER_API_INTEGRATION.md`).
///
/// Paths only — no host, no client, no serialization. Every path is relative
/// to `/api/v1` (which `ApiClient` prefixes), carries its surface segment
/// (`/patient`, `/shared`) and has **no trailing slash** (§1.1).
///
/// Rules for this file:
/// * every path appears exactly once, as a constant or a builder;
/// * builders percent-encode their segments, so an id with a `/` cannot escape
///   its position in the path;
/// * nothing here reads state.
abstract final class Endpoints {
  Endpoints._();

  /// Prefix `ApiClient` joins onto the host. Paths below start after it.
  static const String apiPrefix = '/api/v1';

  /// WebSocket prefix (`wss://<host>/ws/patient/…`).
  static const String wsPrefix = '/ws';

  static const String _p = '/patient';
  static const String _s = '/shared';

  static String _seg(String value) => Uri.encodeComponent(value);

  // ---- App start and content (§3) — public ----
  static const String appConfig = '$_s/app-config';
  static const String health = '$_s/health';
  static const String faqs = '$_p/faqs';
  static String legalDocument(String slug) => '$_p/legal/${_seg(slug)}';

  // ---- Authentication (§4) ----
  static const String signupStart = '$_p/auth/signup/start';
  static const String signupVerify = '$_p/auth/signup/verify';
  static const String loginOtpStart = '$_p/auth/login/otp/start';
  static const String loginOtpVerify = '$_p/auth/login/otp/verify';
  static const String loginPassword = '$_p/auth/login/password';
  static const String otpResend = '$_p/auth/otp/resend';
  static const String forgotStart = '$_p/auth/password/forgot/start';
  static const String forgotVerify = '$_p/auth/password/forgot/verify';
  static const String passwordReset = '$_p/auth/password/reset';
  static const String tokenRefresh = '$_p/auth/token/refresh';
  static const String logout = '$_p/auth/logout';
  static const String logoutAll = '$_p/auth/logout-all';
  static const String sessions = '$_p/auth/sessions';
  static String session(String id) => '$_p/auth/sessions/${_seg(id)}';

  // ---- Account and profile (§5) ----
  static const String me = '$_p/me';
  static const String mePassword = '$_p/me/password';
  static const String phoneChangeStart = '$_p/me/phone/change/start';
  static const String phoneChangeConfirmOld = '$_p/me/phone/change/confirm-old';
  static const String phoneChangeVerifyNew = '$_p/me/phone/change/verify-new';
  static const String alternatePhone = '$_p/me/alternate-phone';
  static const String deletionRequests = '$_p/me/deletion-requests';
  static String deletionRequest(String requestNo) =>
      '$_p/me/deletion-requests/${_seg(requestNo)}';
  static const String reactivate = '$_p/me/reactivate';

  /// The patient's own personal-data export requests: `GET` lists them,
  /// `POST` (with `Idempotency-Key`) opens one. A `completed` request's `id`
  /// is the `dsr_id` of [dataExportDownloadUrl].
  static const String dataExports = '$_p/me/data-exports';
  static String dataExportDownloadUrl(String dsrId) =>
      '$_s/data-exports/${_seg(dsrId)}/download-url';
  static const String consents = '$_p/me/consents';

  // ---- Persons, addresses, contacts, insurance (§6) ----
  static const String persons = '$_p/me/persons';
  static String person(String id) => '$_p/me/persons/${_seg(id)}';
  static String personRelease(String id) =>
      '$_p/me/persons/${_seg(id)}/release';
  static String personReleaseVerify(String id) =>
      '$_p/me/persons/${_seg(id)}/release/verify';

  static const String addresses = '$_p/me/addresses';
  static String address(String id) => '$_p/me/addresses/${_seg(id)}';
  static String addressDefault(String id) =>
      '$_p/me/addresses/${_seg(id)}/default';

  static const String emergencyContacts = '$_p/me/emergency-contacts';
  static String emergencyContact(String id) =>
      '$_p/me/emergency-contacts/${_seg(id)}';
  static String emergencyContactPrimary(String id) =>
      '$_p/me/emergency-contacts/${_seg(id)}/primary';

  static const String insurancePolicies = '$_p/me/insurance-policies';
  static String insurancePolicy(String id) =>
      '$_p/me/insurance-policies/${_seg(id)}';
  static String insurancePolicyDocuments(String id) =>
      '$_p/me/insurance-policies/${_seg(id)}/documents';
  static String insurancePolicyDocument(String id, String fileId) =>
      '$_p/me/insurance-policies/${_seg(id)}/documents/${_seg(fileId)}';

  // ---- Discovery (§7) — public ----
  static const String locations = '$_p/locations';
  static const String hospitals = '$_p/hospitals';
  static String hospital(String id) => '$_p/hospitals/${_seg(id)}';
  static String hospitalBanners(String id) =>
      '$_p/hospitals/${_seg(id)}/banners';
  static String hospitalDepartments(String id) =>
      '$_p/hospitals/${_seg(id)}/departments';
  static String hospitalDoctors(String id) =>
      '$_p/hospitals/${_seg(id)}/doctors';
  static const String departments = '$_p/departments';
  static String doctor(String id) => '$_p/doctors/${_seg(id)}';
  static const String search = '$_p/search';

  // ---- Availability, slots, fee quote (§8) ----
  static String doctorAvailability(String doctorId) =>
      '$_p/doctors/${_seg(doctorId)}/availability';
  static String doctorSlots(String doctorId) =>
      '$_p/doctors/${_seg(doctorId)}/slots';
  static const String feeQuotes = '$_p/fee-quotes';

  // ---- Booking and payment (§9) ----
  static const String appointments = '$_p/appointments';
  static String paymentOrder(String orderId) =>
      '$_p/payments/orders/${_seg(orderId)}';
  static String paymentOrderVerify(String orderId) =>
      '$_p/payments/orders/${_seg(orderId)}/verify';
  static String paymentOrderRetry(String orderId) =>
      '$_p/payments/orders/${_seg(orderId)}/retry';

  // ---- Appointments (§10) ----
  static String appointment(String id) => '$_p/appointments/${_seg(id)}';
  static String appointmentEvents(String id) =>
      '$_p/appointments/${_seg(id)}/events';
  static String appointmentTokenCard(String id) =>
      '$_p/appointments/${_seg(id)}/token-card';
  static String appointmentQueue(String id) =>
      '$_p/appointments/${_seg(id)}/queue';
  static String appointmentCancellationPreview(String id) =>
      '$_p/appointments/${_seg(id)}/cancellation-preview';
  static String appointmentCancel(String id) =>
      '$_p/appointments/${_seg(id)}/cancel';
  static String appointmentReceipt(String id) =>
      '$_p/appointments/${_seg(id)}/receipt';
  static String appointmentReceiptPdf(String id) =>
      '$_p/appointments/${_seg(id)}/receipt.pdf';
  static String appointmentCalendar(String id) =>
      '$_p/appointments/${_seg(id)}/calendar.ics';
  static String appointmentReview(String id) =>
      '$_p/appointments/${_seg(id)}/review';
  static const String payments = '$_p/payments';
  static const String refunds = '$_p/refunds';

  // ---- Medical documents and files (§11) ----
  static const String fileUploads = '$_s/files/uploads';
  static String file(String id) => '$_s/files/${_seg(id)}';
  static String fileComplete(String id) => '$_s/files/${_seg(id)}/complete';
  static String fileUrl(String id) => '$_s/files/${_seg(id)}/url';
  static const String documents = '$_p/documents';
  static String document(String id) => '$_p/documents/${_seg(id)}';
  static String documentDownloadUrl(String id) =>
      '$_p/documents/${_seg(id)}/download-url';

  // ---- Notifications and push devices (§12) ----
  static const String notifications = '$_p/notifications';
  static const String notificationsUnreadCount =
      '$_p/notifications/unread-count';
  static const String notificationsReadAll = '$_p/notifications/read-all';
  static String notification(String id) => '$_p/notifications/${_seg(id)}';
  static String notificationRead(String id) =>
      '$_p/notifications/${_seg(id)}/read';
  static String notificationUnread(String id) =>
      '$_p/notifications/${_seg(id)}/unread';
  static const String devices = '$_p/me/devices';
  static String device(String id) => '$_p/me/devices/${_seg(id)}';

  // ---- Support (§13) ----
  static const String supportTickets = '$_p/support/tickets';
  static String supportTicket(String id) => '$_p/support/tickets/${_seg(id)}';
  static String supportTicketMessages(String id) =>
      '$_p/support/tickets/${_seg(id)}/messages';

  // ---- Ambulance (§14) — public ----
  static const String ambulanceProviders = '$_p/ambulance/providers';

  // ---- WebSockets (§15) — relative to [wsPrefix] ----
  static String wsSession(String appointmentId) =>
      '$wsPrefix/patient/session/${_seg(appointmentId)}';
  static const String wsInbox = '$wsPrefix/patient/inbox';

  // ---- Query builders ----

  /// Standard pagination query (§1.6). Page numbers are 1-based; the maximum
  /// page size is 100.
  static Map<String, Object?> page(int page, {int? size}) => {
    'page': page,
    'page_size': size,
  };
}
