import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/slots.dart';
import '../../domain/entities/hospital_clock.dart';

/// Presentation labels for slots and hospital-local dates. Every instant is
/// rendered in the **hospital's** zone (§1.11) via [HospitalClock].
abstract final class SlotLabels {
  SlotLabels._();

  /// "10:30 AM".
  static String time(DateTime instant, {String? timezone}) =>
      AppDates.timeLabel(HospitalClock.wallClock(instant, timezone: timezone));

  /// "10:30 AM – 10:45 AM".
  static String range(Slot slot, {String? timezone}) =>
      '${time(slot.startsAt, timezone: timezone)} – '
      '${time(slot.endsAt, timezone: timezone)}';

  /// "Today · 22 Sep" / "Tomorrow · 23 Sep" / "Wed · 24 Sep" for a
  /// hospital-local `YYYY-MM-DD`.
  static String dayShort(String date, {String? timezone}) {
    final day = HospitalClock.parseDate(date);
    if (day == null) return date;
    final relative = _relative(day, timezone: timezone);
    final lead = relative ?? AppDates.weekdayLong(day).substring(0, 3);
    return '$lead · ${AppDates.dayMonth(day)}';
  }

  /// "Today · 22 Sep 2026" / "Wed, 24 Sep 2026". The full date follows only
  /// a relative lead; after a weekday it would repeat the day and month
  /// ("Fri, 9 Oct · 9 Oct 2026", Screen Coverage pass).
  static String dayLong(String date, {String? timezone}) {
    final day = HospitalClock.parseDate(date);
    if (day == null) return date;
    final relative = _relative(day, timezone: timezone);
    if (relative != null) return '$relative · ${AppDates.dayMonthYear(day)}';
    return '${AppDates.weekdayLong(day).substring(0, 3)}, '
        '${AppDates.dayMonthYear(day)}';
  }

  /// "today" / "tomorrow" / "on Wed, 24 Sep" — the tail of a sentence.
  static String dayInSentence(String date, {String? timezone}) {
    final day = HospitalClock.parseDate(date);
    if (day == null) return 'on $date';
    final relative = _relative(day, timezone: timezone);
    if (relative != null) return relative.toLowerCase();
    return 'on ${AppDates.weekdayLong(day).substring(0, 3)}, '
        '${AppDates.dayMonth(day)}';
  }

  /// "Next free 09:00 AM today" from a UTC `next_available_at`, or
  /// "No free slot published" when null.
  static String nextAvailable(DateTime? instant, {String? timezone}) {
    if (instant == null) return 'No free slot published';
    final date = HospitalClock.localDate(instant, timezone: timezone);
    return 'Next free ${time(instant, timezone: timezone)} '
        '${dayInSentence(date, timezone: timezone)}';
  }

  /// The same fact, day first, for a narrow card: "Tomorrow, 9:00 AM" /
  /// "Wed 24 Sep, 9:00 AM" / "No free slot". Day first so that if the line
  /// is ever cut short, it is the time that goes, never the day.
  static String nextAvailableShort(DateTime? instant, {String? timezone}) {
    if (instant == null) return 'No free slot';
    final date = HospitalClock.localDate(instant, timezone: timezone);
    final day = HospitalClock.parseDate(date);
    final lead = day == null
        ? date
        : _relative(day, timezone: timezone) ??
              '${AppDates.weekdayLong(day).substring(0, 3)} '
                  '${AppDates.dayMonth(day)}';
    return '$lead, ${time(instant, timezone: timezone)}';
  }

  /// Why a slot cannot be picked, from its server `state` — what a screen
  /// reader hears after the time ("9:00 AM, passed"). Every one used to
  /// read "taken".
  static String unavailableNote(SlotState state) => switch (state) {
    SlotState.booked => 'taken',
    SlotState.held => 'being booked',
    SlotState.blocked => 'not open for booking',
    SlotState.past => 'passed',
    SlotState.available => 'available',
  };

  /// The toast for a tap on a slot that cannot be picked, from its state.
  static String unavailableMessage(SlotState state) => switch (state) {
    SlotState.booked => 'That slot is already taken.',
    SlotState.held => 'Someone else is booking that slot right now.',
    SlotState.blocked => 'That slot is not open for booking.',
    SlotState.past => 'That time has already passed.',
    SlotState.available => 'That slot is free.',
  };

  /// The toast when a slot chosen earlier is no longer free, from its
  /// server state — it said "has just been taken" for every reason.
  static String noLongerFree(SlotState state, String time) => switch (state) {
    SlotState.held =>
      'Someone else is booking the $time slot right now. Pick another.',
    SlotState.blocked =>
      'The $time slot is no longer open for booking. Pick another.',
    SlotState.past => 'The $time slot has passed. Pick another.',
    SlotState.booked ||
    SlotState.available => 'The $time slot has just been taken. Pick another.',
  };

  /// When an unpaid booking must be paid: "by 10:31 PM" from its
  /// `booking_deadline_at`, in the hospital's zone; "before the hold runs
  /// out" only when the booking has no deadline.
  static String payBefore(DateTime? deadline, {String? timezone}) =>
      deadline == null
      ? 'before the hold runs out'
      : 'by ${time(deadline, timezone: timezone)}';

  /// "Today" / "Tomorrow" relative to the hospital's calendar, else null.
  static String? _relative(DateTime day, {String? timezone}) {
    final today = HospitalClock.parseDate(
      HospitalClock.today(timezone: timezone),
    );
    if (today == null) return null;
    final delta = day.difference(today).inDays;
    return switch (delta) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => null,
    };
  }
}
