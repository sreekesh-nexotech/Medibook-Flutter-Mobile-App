import '../../utils/date_utils.dart';

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

/// What kind of event a notification reports (CM-40 … CM-43). Drives the
/// leading icon and the filter chips.
enum NotificationKind {
  confirmation('Confirmation'),
  reminder('Reminder'),
  change('Change'),
  cancellation('Cancellation'),
  general('General');

  const NotificationKind(this.label);

  final String label;
}

/// A notification card. Actions are optional; when present the card renders a
/// two-button row (secondary + primary pill).
///
/// Presentation view-model — immutable, no logic.
///
/// ## The read flag (audit §3.1.3)
///
/// The audit found "Mark all as read reports success and changes nothing — the
/// notification record has no read flag". It has one now ([read]), plus an
/// [id] to address a single record and a real [createdAt] instead of the
/// typed-in "2 hours ago". `String get ago` derives the same label, so
/// `notification_card.dart` compiles untouched.
///
/// Mutating [read] goes through `stores/notifications_store.dart` — a model
/// stays immutable, so "mark as read" produces a new record via [copyWith].
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.kind = NotificationKind.general,
    this.read = false,
    this.appointmentId,
    this.action1Label,
    this.action1,
    this.action2Label,
    this.action2,
  });

  /// Stable id — what "mark this one read" addresses.
  final String id;

  final String title;
  final String body;

  /// When the event happened. Real instant, so the list can sort and group.
  final DateTime createdAt;

  final NotificationKind kind;

  /// Whether the user has seen it. Drives the unread dot and the badge count.
  final bool read;

  /// The appointment this notification is about, when it has one — lets the
  /// card deep-link without the screen guessing.
  final String? appointmentId;

  final String? action1Label;
  final NotificationAction? action1;
  final String? action2Label;
  final NotificationAction? action2;

  bool get hasActions => action1Label != null;

  /// True when the record has not been read yet.
  bool get unread => !read;

  /// Relative time ("2 hours ago"). Unchanged public API, now derived.
  String get ago => AppDates.relativeAgo(createdAt);

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? createdAt,
    NotificationKind? kind,
    bool? read,
    String? appointmentId,
    String? action1Label,
    NotificationAction? action1,
    String? action2Label,
    NotificationAction? action2,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      kind: kind ?? this.kind,
      read: read ?? this.read,
      appointmentId: appointmentId ?? this.appointmentId,
      action1Label: action1Label ?? this.action1Label,
      action1: action1 ?? this.action1,
      action2Label: action2Label ?? this.action2Label,
      action2: action2 ?? this.action2,
    );
  }
}
