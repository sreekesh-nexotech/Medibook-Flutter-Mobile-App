import '../../../../core/utils/date_utils.dart';

/// Renders UTC instants in the hospital's zone (§1.11: show appointment and
/// slot times in the hospital's time zone — never the device's).
///
/// The zone is the one the server names on the appointment
/// (`hospital.timezone`, §10); pass it as `timezone`. A payload without one
/// reads as `Asia/Kolkata`, and a zone [HospitalZones] cannot shift exactly
/// falls back to the device's zone.
///
/// Pure functions — no Flutter — so both the application layer (list labels
/// for other features) and the presentation layer can call them.
abstract final class HospitalTime {
  HospitalTime._();

  /// [instant] re-expressed as a wall-clock [DateTime] whose fields read in
  /// hospital-local time. The result is only for formatting and same-day
  /// comparisons; do not send it back to the API.
  static DateTime wallClock(DateTime instant, {String? timezone}) {
    final offset = HospitalZones.offsetOf(timezone);
    final shifted = offset == null
        ? instant.toLocal()
        : instant.toUtc().add(offset);
    return DateTime(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
    );
  }

  /// The hospital's "now", for "Today" / "Tomorrow" labels.
  static DateTime now({String? timezone}) =>
      wallClock(DateTime.now(), timezone: timezone);

  /// "10:30 AM".
  static String time(DateTime instant, {String? timezone}) =>
      AppDates.timeLabel(wallClock(instant, timezone: timezone));

  /// "Today" / "Tomorrow" / "12 Aug 2026".
  static String day(DateTime instant, {String? timezone}) =>
      AppDates.relativeDay(
        wallClock(instant, timezone: timezone),
        now: now(timezone: timezone),
      );

  /// "12 Aug 2026".
  static String dayMonthYear(DateTime instant, {String? timezone}) =>
      AppDates.dayMonthYear(wallClock(instant, timezone: timezone));

  /// "Today · 10:30 AM".
  static String dayAndTime(DateTime instant, {String? timezone}) =>
      '${day(instant, timezone: timezone)} · '
      '${time(instant, timezone: timezone)}';

  /// "12 Aug 2026 · 10:32 AM" — for issued-at / paid-at stamps.
  static String dateAndTime(DateTime instant, {String? timezone}) =>
      '${dayMonthYear(instant, timezone: timezone)} · '
      '${time(instant, timezone: timezone)}';

  static bool isToday(DateTime instant, {String? timezone}) =>
      AppDates.isSameDay(
        wallClock(instant, timezone: timezone),
        now(timezone: timezone),
      );
}
