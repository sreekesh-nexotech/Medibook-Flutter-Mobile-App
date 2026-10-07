import '../../../../core/utils/date_utils.dart';

/// Hospital-zone wall-clock helpers (`FLUTTER_API_INTEGRATION.md` §1.11).
///
/// Slot and appointment instants arrive in UTC and must be displayed in the
/// **hospital's** zone (`timezone` on the slot grid and on hospital detail,
/// `Asia/Kolkata` by default) — never the device's. Offsets come from
/// [HospitalZones]; a zone it does not list falls back to the device zone.
/// Pure Dart, no Flutter, so the application layer can call it directly.
abstract final class HospitalClock {
  HospitalClock._();

  /// The default zone when a hospital does not say.
  static const String defaultTimezone = HospitalZones.defaultTimezone;

  /// True when [timezone] is one this helper can shift exactly.
  static bool isSupported(String? timezone) =>
      HospitalZones.isSupported(timezone);

  /// [instant] re-expressed as a wall-clock time in [timezone].
  ///
  /// The result is flagged UTC and carries the zone's wall-clock fields, so
  /// `DateFormat` renders the hospital's hours and minutes and no further
  /// conversion happens. Compare instants, not these values.
  static DateTime wallClock(DateTime instant, {String? timezone}) {
    final offset = HospitalZones.offsetOf(timezone);
    if (offset == null) return instant.toLocal();
    return instant.toUtc().add(offset);
  }

  /// The hospital-local calendar day (`YYYY-MM-DD`) [instant] falls on.
  static String localDate(DateTime instant, {String? timezone}) =>
      formatDate(wallClock(instant, timezone: timezone));

  /// `YYYY-MM-DD` for the wire (§1.11).
  static String formatDate(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  /// Parses a `YYYY-MM-DD` hospital-local date into a zone-less midnight, or
  /// null when malformed. Use it only for labels and day arithmetic.
  static DateTime? parseDate(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// Today in the hospital's zone, as `YYYY-MM-DD`.
  static String today({String? timezone, DateTime? now}) =>
      localDate(now ?? DateTime.now(), timezone: timezone);
}
