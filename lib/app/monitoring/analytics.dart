import '../../core/utils/logger.dart';
import '../config/env.dart';

/// The app's analytics event vocabulary.
///
/// A closed enum rather than free-form strings, because an analytics funnel
/// built on typo-prone literals silently loses steps. Names are
/// `snake_case` on the wire (what every SDK expects) and the enum is the only
/// place they are spelled.
enum AnalyticsEvent {
  appOpened('app_opened'),
  screenViewed('screen_viewed'),

  // Auth
  signUpStarted('sign_up_started'),
  signUpCompleted('sign_up_completed'),
  loginSucceeded('login_succeeded'),
  loginFailed('login_failed'),
  loginLockedOut('login_locked_out'),
  loggedOut('logged_out'),

  // Discovery + booking funnel
  locationSelected('location_selected'),
  departmentSelected('department_selected'),
  doctorViewed('doctor_viewed'),
  slotSelected('slot_selected'),
  bookingStarted('booking_started'),
  bookingConfirmed('booking_confirmed'),
  bookingCancelled('booking_cancelled'),
  bookingRescheduled('booking_rescheduled'),

  // Payments
  paymentStarted('payment_started'),
  paymentSucceeded('payment_succeeded'),
  paymentFailed('payment_failed'),
  refundRequested('refund_requested'),

  // Records / documents
  documentUploaded('document_uploaded'),
  documentDownloaded('document_downloaded'),

  // Support
  notificationOpened('notification_opened'),
  supportContacted('support_contacted'),
  ambulanceRequested('ambulance_requested'),

  /// Fired when a control that cannot do its job yet is tapped. Makes the
  /// stubbed surface measurable instead of invisible.
  stubbedActionTapped('stubbed_action_tapped');

  const AnalyticsEvent(this.wireName);

  /// The `snake_case` name sent to the analytics backend.
  final String wireName;
}

/// Where analytics go. The real SDK (Firebase Analytics, Amplitude, …) becomes
/// one implementation of this; nothing above it changes.
abstract interface class AnalyticsSink {
  void logEvent(String name, Map<String, Object?> parameters);

  /// Associate subsequent events with a user. Pass null on sign-out.
  void setUserId(String? userId);

  /// Set a sticky user property (plan, city). Never PHI.
  void setUserProperty(String name, String? value);

  void setCurrentScreen(String screenName);
}

/// The analytics facade every feature calls.
///
/// Two rules, enforced here rather than trusted to call sites:
/// * **Off by default.** Nothing leaves the device unless
///   `--dart-define=MEDIBOOK_ANALYTICS=true` (see [Env.analyticsEnabled]).
///   Until then events go to the logger, which is itself silent in release.
/// * **No PHI, ever.** [scrub] strips the keys a health app must never send —
///   names, phone numbers, emails, addresses, diagnoses, document contents —
///   so a careless `track()` call cannot exfiltrate patient data. Send ids.
///
/// ```dart
/// Analytics.track(AnalyticsEvent.bookingConfirmed, {
///   'doctor_id': doctor.id,
///   'fee_paise': breakdown.total.paise,
/// });
/// ```
abstract final class Analytics {
  Analytics._();

  /// Swap during bootstrap to install a real SDK.
  static AnalyticsSink sink = const LoggingAnalyticsSink();

  /// Whether events are forwarded to [sink] at all.
  static bool get enabled => Env.analyticsEnabled;

  /// Parameter keys that are dropped before an event is sent. Extend this list
  /// rather than remembering not to pass them.
  static const Set<String> blockedParameterKeys = {
    'name',
    'full_name',
    'patient_name',
    'doctor_name',
    'email',
    'phone',
    'mobile',
    'address',
    'pincode',
    'dob',
    'date_of_birth',
    'blood_group',
    'allergies',
    'diagnosis',
    'notes',
    'prescription',
    'policy_number',
    'file_name',
    'access_token',
    'password',
  };

  /// Record [event].
  static void track(
    AnalyticsEvent event, [
    Map<String, Object?> parameters = const <String, Object?>{},
  ]) {
    final safe = scrub(parameters);
    if (!enabled) {
      AppLogger.debug(
        'analytics (dropped) ${event.wireName} $safe',
        name: 'analytics',
      );
      return;
    }
    sink.logEvent(event.wireName, safe);
  }

  /// Record a screen view. Screen names are route paths from `AppRoutes`.
  static void screen(String screenName) {
    if (!enabled) {
      AppLogger.debug(
        'analytics (dropped) screen $screenName',
        name: 'analytics',
      );
      return;
    }
    sink.setCurrentScreen(screenName);
    sink.logEvent(AnalyticsEvent.screenViewed.wireName, {'screen': screenName});
  }

  /// Identify the signed-in user by **id only**.
  static void identify(String? userId) {
    if (!enabled) return;
    sink.setUserId(userId);
  }

  /// Clear identity and sticky properties (CM-53: logout clears session).
  static void reset() {
    if (!enabled) return;
    sink.setUserId(null);
  }

  static void property(String name, String? value) {
    if (!enabled) return;
    if (blockedParameterKeys.contains(name)) {
      AppLogger.warning(
        'Refused to set PHI-ish user property "$name"',
        name: 'analytics',
      );
      return;
    }
    sink.setUserProperty(name, value);
  }

  /// Remove blocked keys and collapse anything that is not a primitive.
  static Map<String, Object?> scrub(Map<String, Object?> parameters) {
    final result = <String, Object?>{};
    for (final entry in parameters.entries) {
      if (blockedParameterKeys.contains(entry.key)) continue;
      final value = entry.value;
      if (value == null ||
          value is num ||
          value is bool ||
          value is String && value.length <= 100) {
        result[entry.key] = value;
      } else {
        result[entry.key] = value.runtimeType.toString();
      }
    }
    return result;
  }
}

/// The default sink: writes to [AppLogger], which is itself silent in release.
/// Lets the funnel be inspected during development with no SDK and no network.
class LoggingAnalyticsSink implements AnalyticsSink {
  const LoggingAnalyticsSink();

  @override
  void logEvent(String name, Map<String, Object?> parameters) =>
      AppLogger.info('event $name $parameters', name: 'analytics');

  @override
  void setUserId(String? userId) =>
      AppLogger.info('userId=${userId ?? '<cleared>'}', name: 'analytics');

  @override
  void setUserProperty(String name, String? value) =>
      AppLogger.info('property $name=$value', name: 'analytics');

  @override
  void setCurrentScreen(String screenName) =>
      AppLogger.debug('screen $screenName', name: 'analytics');
}

/// A sink that records events in memory, for widget tests that assert a funnel.
class RecordingAnalyticsSink implements AnalyticsSink {
  final List<({String name, Map<String, Object?> parameters})> events =
      <({String name, Map<String, Object?> parameters})>[];

  String? userId;
  String? currentScreen;

  @override
  void logEvent(String name, Map<String, Object?> parameters) =>
      events.add((name: name, parameters: parameters));

  @override
  void setUserId(String? userId) => this.userId = userId;

  @override
  void setUserProperty(String name, String? value) {}

  @override
  void setCurrentScreen(String screenName) => currentScreen = screenName;
}
