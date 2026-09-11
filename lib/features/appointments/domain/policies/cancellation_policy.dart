import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';

/// What a change to an appointment is: a cancellation or a reschedule. The
/// cut-off differs, so the policy needs to know which one it is being asked
/// about.
enum AppointmentChange {
  cancel('Cancel'),
  reschedule('Reschedule');

  const AppointmentChange(this.label);

  final String label;
}

/// Where the patient stands relative to the cut-off.
enum PolicyWindow {
  /// Comfortably before the cut-off — the change is free.
  beforeCutoff,

  /// Past the cut-off but before the slot — allowed for a cancellation, at a
  /// cost; not allowed for a reschedule.
  insideCutoff,

  /// The slot has started or passed — nothing can be changed from the app.
  slotStarted,

  /// The appointment is already closed (completed / cancelled / no-show).
  closed,
}

/// How much money comes back.
enum RefundTier {
  full('Full refund'),
  partial('Partial refund'),
  none('No refund'),
  nothingPaid('Nothing paid yet');

  const RefundTier(this.label);

  final String label;
}

/// The answer the UI renders: which window the patient is in, what it costs,
/// and whether the action may proceed at all.
///
/// Every field is derived — nothing here is a typed-in string, and every amount
/// is [Money] (paise), so the number in the dialog is the number that would be
/// refunded.
class PolicyOutcome {
  const PolicyOutcome({
    required this.change,
    required this.window,
    required this.tier,
    required this.cutoff,
    required this.scheduledAt,
    required this.paid,
    required this.refund,
    required this.retained,
  });

  final AppointmentChange change;
  final PolicyWindow window;
  final RefundTier tier;

  /// The instant after which the free window closes.
  final DateTime cutoff;

  /// The appointment's slot.
  final DateTime scheduledAt;

  /// What the patient has actually paid (zero for an unsettled payment).
  final Money paid;

  /// What would come back.
  final Money refund;

  /// What the hospital keeps.
  final Money retained;

  /// True when the app may go ahead with the change.
  bool get isAllowed =>
      window == PolicyWindow.beforeCutoff ||
      (window == PolicyWindow.insideCutoff &&
          change == AppointmentChange.cancel);

  /// Why the action is unavailable, for a disabled control's `semanticLabel`
  /// and for the inline notice. Null when [isAllowed].
  String? get blockedReason => switch (window) {
    PolicyWindow.beforeCutoff => null,
    PolicyWindow.insideCutoff =>
      change == AppointmentChange.cancel
          ? null
          : 'Reschedule closes ${_windowLabel(CancellationPolicy.rescheduleCutoff)} '
                'before the slot. You can still cancel.',
    PolicyWindow.slotStarted =>
      'This appointment has already started. The hospital front desk has to '
          'change it now.',
    PolicyWindow.closed =>
      'This appointment is closed, so there is nothing left to change.',
  };

  /// "Today · 6:30 AM" — the cut-off, in words.
  String get cutoffLabel => AppDates.dayAndTime(cutoff);

  /// "in 3h 12m" / "passed 40m ago" — how far the cut-off is from now.
  String timeToCutoffLabel({DateTime? now}) {
    final reference = now ?? DateTime.now();
    final delta = cutoff.difference(reference);
    if (delta.isNegative) {
      return 'passed ${_durationLabel(-delta)} ago';
    }
    return 'in ${_durationLabel(delta)}';
  }

  /// The one-line verdict for the policy panel ("Inside the 4-hour cut-off").
  String get windowLabel => switch (window) {
    PolicyWindow.beforeCutoff =>
      'Before the ${_windowLabel(_cutoffWindow)} cut-off',
    PolicyWindow.insideCutoff =>
      'Inside the ${_windowLabel(_cutoffWindow)} cut-off',
    PolicyWindow.slotStarted => 'The slot has started',
    PolicyWindow.closed => 'Closed',
  };

  /// The sentence `showAppConfirmDialog` requires — what this does to the
  /// patient's money, in full, before they commit.
  ///
  /// This is the CM-25 / CM-26 finding in one string: both actions worked, but
  /// "no cut-off, no policy window and no refund consequence is ever shown to
  /// the patient".
  String get consequence {
    final slot = AppDates.dayAndTime(scheduledAt);
    if (change == AppointmentChange.reschedule) {
      final moneyNote = paid.isZero
          ? 'Nothing has been paid yet, so there is no charge for the move.'
          : 'The ${paid.format()} already paid moves with the booking — there '
                'is nothing more to pay.';
      return 'Your $slot slot is released and given to someone else. '
          '$moneyNote';
    }
    return switch (tier) {
      RefundTier.full =>
        'Cancelling now is before the ${_windowLabel(_cutoffWindow)} cut-off '
            '($cutoffLabel), so the full ${paid.format()} is refunded to the '
            'original payment method in 5-7 working days. Your $slot slot is '
            'released.',
      RefundTier.partial =>
        'Your slot is $slot, inside the ${_windowLabel(_cutoffWindow)} '
            'cut-off, so '
            '${CancellationPolicy.lateCancellationRefundPercent.round()}% '
            '(${refund.format()}) is refunded and ${retained.format()} is '
            'kept as a late-cancellation charge.',
      RefundTier.none =>
        'The $slot slot has started, so no refund is due on the '
            '${paid.format()} paid.',
      RefundTier.nothingPaid =>
        'Nothing has been paid for this appointment, so there is no refund to '
            'process. Your $slot slot is released.',
    };
  }

  Duration get _cutoffWindow => change == AppointmentChange.cancel
      ? CancellationPolicy.cancellationCutoff
      : CancellationPolicy.rescheduleCutoff;

  static String _windowLabel(Duration window) {
    final hours = window.inHours;
    if (hours >= 1) return '$hours-hour';
    return '${window.inMinutes}-minute';
  }

  static String _durationLabel(Duration delta) {
    if (delta.inMinutes < 60) return '${delta.inMinutes}m';
    final hours = delta.inHours;
    final minutes = delta.inMinutes.remainder(60);
    if (hours < 24) return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
    final days = delta.inDays;
    final restHours = delta.inHours.remainder(24);
    return restHours == 0 ? '${days}d' : '${days}d ${restHours}h';
  }
}

/// The cancellation / reschedule rulebook (CM-25, CM-26).
///
/// ## Where the real rule has to come from
///
/// These three constants are a **documented app-wide default, not the truth**.
/// A cancellation cut-off is a per-hospital, and in practice per-department,
/// commercial term: a 24-hour rule for a surgical consult and a 1-hour rule for
/// a walk-in clinic are both normal. The hospital console already owns hospital
/// and department master data, so the rule belongs there and must reach this
/// app as data on the booking:
///
/// ```jsonc
/// // GET /appointments/:id → policy
/// {
///   "cancellationCutoffMinutes": 240,
///   "rescheduleCutoffMinutes": 120,
///   "lateCancellationRefundPercent": 50,
///   "refundSettlementDays": 7,
///   "policyUrl": "https://…/apollo/cancellation-policy"
/// }
/// ```
///
/// Until that field exists, every screen reads these constants — one place to
/// change, and one place for the backend team to delete. Nothing in the UI
/// hardcodes a window or a percentage of its own.
abstract final class CancellationPolicy {
  CancellationPolicy._();

  /// Free-cancellation window before the slot. Default: 4 hours.
  static const Duration cancellationCutoff = Duration(hours: 4);

  /// Reschedule window before the slot. Default: 2 hours — tighter than
  /// cancellation, because the released slot has to be re-offered.
  static const Duration rescheduleCutoff = Duration(hours: 2);

  /// Share of the paid amount returned for a cancellation inside the cut-off.
  static const double lateCancellationRefundPercent = 50;

  /// What the patient is told about settlement timing.
  static const int refundSettlementDays = 7;

  /// The cut-off instant for [scheduledAt].
  static DateTime cutoffFor(DateTime scheduledAt, AppointmentChange change) =>
      scheduledAt.subtract(
        change == AppointmentChange.cancel
            ? cancellationCutoff
            : rescheduleCutoff,
      );

  /// Evaluate [change] against [appointment].
  ///
  /// [paid] is what the patient has actually settled — pass [Money.zero] for a
  /// pending or failed payment, so the dialog never promises a refund of money
  /// the ledger never took.
  ///
  /// [isClosed] comes from the canonical status view (completed / cancelled /
  /// no-show), which is the only thing that knows the appointment is closed.
  static PolicyOutcome evaluate({
    required Appointment appointment,
    required Money paid,
    required AppointmentChange change,
    bool isClosed = false,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final scheduledAt = appointment.scheduledAt;
    final cutoff = cutoffFor(scheduledAt, change);

    final PolicyWindow window;
    if (isClosed) {
      window = PolicyWindow.closed;
    } else if (!reference.isBefore(scheduledAt)) {
      window = PolicyWindow.slotStarted;
    } else if (reference.isBefore(cutoff)) {
      window = PolicyWindow.beforeCutoff;
    } else {
      window = PolicyWindow.insideCutoff;
    }

    final (RefundTier tier, Money refund) = switch ((change, window, paid)) {
      // A reschedule moves the money with the booking; no refund is computed.
      (AppointmentChange.reschedule, _, _) => (
        paid.isZero ? RefundTier.nothingPaid : RefundTier.full,
        Money.zero,
      ),
      (_, _, final amount) when amount.isZero => (
        RefundTier.nothingPaid,
        Money.zero,
      ),
      (_, PolicyWindow.beforeCutoff, final amount) => (
        RefundTier.full,
        amount,
      ),
      (_, PolicyWindow.insideCutoff, final amount) => (
        RefundTier.partial,
        amount.percent(lateCancellationRefundPercent),
      ),
      (_, PolicyWindow.slotStarted, _) ||
      (_, PolicyWindow.closed, _) => (RefundTier.none, Money.zero),
    };

    return PolicyOutcome(
      change: change,
      window: window,
      tier: tier,
      cutoff: cutoff,
      scheduledAt: scheduledAt,
      paid: paid,
      refund: refund,
      retained: paid.minusFloored(refund),
    );
  }
}
