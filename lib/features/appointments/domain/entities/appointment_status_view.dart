import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/mock_data/models/queue_status.dart';

/// The **five canonical appointment statuses** (`CANONICAL_MASTER_DATA` §4).
///
/// The two apps disagreed on the basics: the patient app modelled three states
/// (`Confirmed` / `Completed` / `Cancelled`) while the hospital console modelled
/// five. The canonical set is the console's, so the patient app has to render
/// all five — and `Confirmed` is renamed `Scheduled`.
///
/// `core/mock_data/models/appointment.dart` still stores the three-value
/// [AppointmentStatus] (core is frozen this round), so this is the presentation
/// view of that field: a *derived* status that combines the stored value with
/// the appointment's real [Appointment.scheduledAt] and the clinic's live
/// [QueueStatus]. See [AppointmentStatusViews.of] for the derivation and the
/// note on what the backend should send instead.
enum AppointmentStatusView {
  /// Booked and confirmed for a future slot (the old `Confirmed`).
  scheduled('Scheduled', 'Confirmed for the slot below.'),

  /// The patient is in today's queue at the doctor's desk.
  inQueue('In Queue', "You are in today's queue — watch your token."),

  /// The consultation happened.
  completed('Completed', 'This consultation is closed.'),

  /// Cancelled by the patient or the hospital.
  cancelled('Cancelled', 'This appointment was cancelled.'),

  /// The slot passed without the patient being seen.
  noShow('No-show', 'The slot passed without a consultation.');

  const AppointmentStatusView(this.label, this.hint);

  /// Human label shown in the status pill. Exactly the canonical spelling.
  final String label;

  /// One line of context for the detail screen, so the pill is not the only
  /// explanation the patient gets.
  final String hint;

  /// Canonical bucketing (`CANONICAL_MASTER_DATA` §4):
  /// upcoming = {Scheduled, In Queue}; past = {Completed, Cancelled, No-show}.
  AppointmentBucket get bucket => switch (this) {
    AppointmentStatusView.scheduled ||
    AppointmentStatusView.inQueue => AppointmentBucket.upcoming,
    AppointmentStatusView.completed ||
    AppointmentStatusView.cancelled ||
    AppointmentStatusView.noShow => AppointmentBucket.past,
  };

  bool get isUpcoming => bucket == AppointmentBucket.upcoming;

  /// Whether the patient may still change this appointment at all. Only a
  /// [scheduled] appointment can be cancelled or rescheduled — an in-queue one
  /// is already at the desk, and the three past states are closed.
  ///
  /// The *time-based* cut-off is a separate question, answered by
  /// `CancellationPolicy`.
  bool get allowsChange => this == AppointmentStatusView.scheduled;

  /// Whether a receipt can exist for this appointment (a cancelled booking
  /// still has one — it is what the refund is measured against).
  bool get hasBillableHistory => this != AppointmentStatusView.scheduled;
}

/// Derives an [AppointmentStatusView] from the data the app actually has.
abstract final class AppointmentStatusViews {
  AppointmentStatusViews._();

  /// How long after a slot a confirmed appointment is still just "Scheduled"
  /// rather than a no-show. Local demo rule; see the class note.
  static const Duration noShowGrace = Duration(minutes: 30);

  /// Every status, in canonical order — the filter surface renders this list.
  static const List<AppointmentStatusView> all = AppointmentStatusView.values;

  /// The canonical status for [appointment].
  ///
  /// Derivation, in order:
  ///
  /// 1. stored `cancelled` / `completed` map straight through;
  /// 2. a confirmed appointment **today** whose doctor publishes a live
  ///    (non-paused) queue is [AppointmentStatusView.inQueue] — the patient is
  ///    in the day's running order whether or not their slot time has arrived;
  /// 3. a confirmed appointment whose slot has passed by more than
  ///    [noShowGrace] with no completion is [AppointmentStatusView.noShow];
  /// 4. anything else confirmed is [AppointmentStatusView.scheduled].
  ///
  /// **Backend note:** steps 2 and 3 are inferences the client should not have
  /// to make. The hospital owns both events — a check-in ("in queue") and a
  /// desk-marked no-show — so the appointment payload should carry the
  /// canonical status verbatim, and this function should collapse to a parse.
  static AppointmentStatusView of(
    Appointment appointment, {
    QueueStatus? queue,
    DateTime? now,
  }) {
    switch (appointment.status) {
      case AppointmentStatus.cancelled:
        return AppointmentStatusView.cancelled;
      case AppointmentStatus.completed:
        return AppointmentStatusView.completed;
      case AppointmentStatus.confirmed:
        final reference = now ?? DateTime.now();
        final isLiveQueue = queue != null && !queue.isPaused;
        if (appointment.isToday && isLiveQueue) {
          return AppointmentStatusView.inQueue;
        }
        final missedAfter = appointment.scheduledAt.add(noShowGrace);
        if (reference.isAfter(missedAfter)) {
          return AppointmentStatusView.noShow;
        }
        return AppointmentStatusView.scheduled;
    }
  }
}
