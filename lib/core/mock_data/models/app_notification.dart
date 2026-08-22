/// The action a notification button triggers. The Notifications screen maps
/// each kind to an `onPressed` (navigation / toast) in the UI layer — models
/// stay free of navigation logic.
enum NotificationAction {
  rescheduleTodayAppt,
  viewTodayApptDetail,
  viewRecords,
  downloadPrescription,
  remindLater,
  scheduleBooking,
}

/// A notification card. Actions are optional; when present the card renders a
/// two-button row (secondary + primary pill).
///
/// Presentation view-model — immutable, no logic.
class AppNotification {
  const AppNotification({
    required this.title,
    required this.body,
    required this.ago,
    this.action1Label,
    this.action1,
    this.action2Label,
    this.action2,
  });

  final String title;
  final String body;

  /// Relative time ("2 hours ago").
  final String ago;

  final String? action1Label;
  final NotificationAction? action1;
  final String? action2Label;
  final NotificationAction? action2;

  bool get hasActions => action1Label != null;
}
