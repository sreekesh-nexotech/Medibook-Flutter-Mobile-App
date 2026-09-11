import '../../../core/utils/date_utils.dart';

/// The Pay-at-Hospital counter-confirmation window (CM-18).
///
/// The audit's finding was that paying at the hospital *"is not presented as a
/// choice, and there is no counter-confirmation window"* — the booking simply
/// said payment happens at the desk, with no deadline, so a patient had no way
/// to know when the slot stops being theirs.
///
/// The rule this encodes: a counter booking must be confirmed at reception at
/// least [leadTime] before the slot, and the desk stops confirming once the
/// slot has started. Both ends are derived from the appointment instant, so
/// there is no second source of truth to drift.
abstract final class CounterPaymentWindow {
  CounterPaymentWindow._();

  /// How far ahead of the slot the desk must have taken payment.
  static const Duration leadTime = Duration(minutes: 30);

  /// The moment after which reception will no longer confirm the booking.
  static DateTime deadlineFor(DateTime scheduledAt) =>
      scheduledAt.subtract(leadTime);

  /// True when there is still time to reach the desk.
  static bool isOpen(DateTime scheduledAt, {DateTime? now}) =>
      deadlineFor(scheduledAt).isAfter(now ?? DateTime.now());

  /// One sentence naming the window, for the method tile and the pending
  /// result screen. Never promises a window that has already closed.
  static String noticeFor(DateTime scheduledAt, {DateTime? now}) {
    final deadline = deadlineFor(scheduledAt);
    if (!deadline.isAfter(now ?? DateTime.now())) {
      return 'The confirmation window for this slot has closed. Pay online '
          'to keep it, or pick another time.';
    }
    return 'Pay at the reception desk by '
        '${AppDates.timeLabel(deadline)} on '
        '${AppDates.dayMonth(deadline)} '
        '(${leadTime.inMinutes} minutes before your slot). '
        'Unconfirmed bookings are released to the next patient.';
  }
}
