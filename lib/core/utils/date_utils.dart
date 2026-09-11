import 'package:intl/intl.dart';

/// A single selectable day chip for the booking / reschedule date rows.
class DateChip {
  const DateChip({
    required this.dow,
    required this.day,
    required this.full,
    required this.date,
  });

  /// Day-of-week label ("Today" for index 0, else "Mon", "Tue"…).
  final String dow;

  /// Day-of-month number, e.g. "22".
  final String day;

  /// Full human date used in confirmation rows ("Today" or "22 Aug 2026").
  final String full;

  /// The real day this chip stands for, normalised to midnight.
  ///
  /// Audit §3.8.3: the chips used to carry only their labels, so a picked date
  /// reached the booking as the *word* "Today". Callers should prefer this and
  /// treat [full] / [dow] as presentation.
  final DateTime date;
}

/// Date helpers. Pure functions — no UI dependency — so the future application
/// layer can call them directly.
///
/// Audit §3.8.3: appointment dates used to be stored as display strings
/// ("Today"), which cannot be sorted, compared or grouped. The models now store
/// a real [DateTime] and call [relativeDay] / [timeLabel] in a getter, so the
/// display API screens already use is unchanged while the storage became real.
abstract final class AppDates {
  AppDates._();

  static final DateFormat _dow = DateFormat('EEE'); // Mon, Tue…
  static final DateFormat _dayMonthYear = DateFormat('d MMM yyyy');
  static final DateFormat _dayMonth = DateFormat('d MMM');
  static final DateFormat _time = DateFormat('h:mm a');
  static final DateFormat _monthYear = DateFormat('MMMM yyyy');
  static final DateFormat _weekdayLong = DateFormat('EEEE');

  /// Build [count] day chips starting from [from] (defaults to today).
  static List<DateChip> upcomingChips({int count = 5, DateTime? from}) {
    final base = startOfDay(from ?? DateTime.now());
    return List<DateChip>.generate(count, (i) {
      final d = DateTime(base.year, base.month, base.day + i);
      final isToday = i == 0;
      return DateChip(
        dow: isToday ? 'Today' : _dow.format(d),
        day: d.day.toString(),
        full: isToday ? 'Today' : _dayMonthYear.format(d),
        date: d,
      );
    });
  }

  // ---- Formatting ----

  /// "Today" / "Tomorrow" / "Yesterday" when [when] is within a day of [now],
  /// else "12 Aug 2026". This is what `Appointment.date` returns, so the
  /// strings screens already render stay identical.
  static String relativeDay(DateTime when, {DateTime? now}) {
    final today = startOfDay(now ?? DateTime.now());
    final day = startOfDay(when);
    final delta = day.difference(today).inDays;
    return switch (delta) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => _dayMonthYear.format(day),
    };
  }

  /// "10:30 AM".
  static String timeLabel(DateTime when) => _time.format(when);

  /// "12 Aug 2026".
  static String dayMonthYear(DateTime when) => _dayMonthYear.format(when);

  /// "12 Aug" — for dense rows where the year is implied.
  static String dayMonth(DateTime when) => _dayMonth.format(when);

  /// "August 2026" — the month-calendar header.
  static String monthYear(DateTime when) => _monthYear.format(when);

  /// "Wednesday".
  static String weekdayLong(DateTime when) => _weekdayLong.format(when);

  /// "Today · 10:30 AM" — the one-line summary used on cards and toasts.
  static String dayAndTime(DateTime when, {DateTime? now}) =>
      '${relativeDay(when, now: now)} · ${timeLabel(when)}';

  /// A coarse "2 hours ago" / "2 days ago" label.
  ///
  /// Backs `AppNotification.ago`, which used to be a hardcoded string.
  static String relativeAgo(DateTime when, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final delta = reference.difference(when);
    if (delta.isNegative) return 'Just now';
    if (delta.inMinutes < 1) return 'Just now';
    if (delta.inMinutes < 60) return _plural(delta.inMinutes, 'minute');
    if (delta.inHours < 24) return _plural(delta.inHours, 'hour');
    if (delta.inDays < 7) return _plural(delta.inDays, 'day');
    if (delta.inDays < 30) return _plural(delta.inDays ~/ 7, 'week');
    if (delta.inDays < 365) return _plural(delta.inDays ~/ 30, 'month');
    return _plural(delta.inDays ~/ 365, 'year');
  }

  static String _plural(int n, String unit) =>
      '$n $unit${n == 1 ? '' : 's'} ago';

  /// Age in whole years — backs `Patient.meta` ("29 years · Female").
  static int ageInYears(DateTime dateOfBirth, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    var age = reference.year - dateOfBirth.year;
    final hadBirthday =
        reference.month > dateOfBirth.month ||
        (reference.month == dateOfBirth.month &&
            reference.day >= dateOfBirth.day);
    if (!hadBirthday) age--;
    return age < 0 ? 0 : age;
  }

  // ---- Comparison / ranges ----

  /// Midnight on the day of [when], in the same (local) zone.
  static DateTime startOfDay(DateTime when) =>
      DateTime(when.year, when.month, when.day);

  /// The last representable instant of [when]'s day.
  static DateTime endOfDay(DateTime when) =>
      DateTime(when.year, when.month, when.day, 23, 59, 59, 999);

  /// True when [a] and [b] fall on the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// True when [a] and [b] fall in the same calendar month.
  static bool isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  static bool isToday(DateTime when, {DateTime? now}) =>
      isSameDay(when, now ?? DateTime.now());

  static bool isPast(DateTime when, {DateTime? now}) =>
      when.isBefore(now ?? DateTime.now());

  /// True when [when] is inside `[from, to]`, day-inclusive at both ends.
  static bool isWithinDays(DateTime when, DateTime from, DateTime to) {
    final day = startOfDay(when);
    return !day.isBefore(startOfDay(from)) && !day.isAfter(startOfDay(to));
  }

  /// The [count] consecutive days starting at [from] (midnight-normalised).
  static List<DateTime> daysFrom(DateTime from, int count) {
    final base = startOfDay(from);
    return List<DateTime>.generate(
      count,
      (i) => DateTime(base.year, base.month, base.day + i),
    );
  }

  /// Every day in [when]'s calendar month, midnight-normalised. Used by the
  /// month grid in `core/widgets/app_date_picker_sheet.dart`.
  static List<DateTime> daysInMonth(DateTime when) {
    final length = DateUtilsLocal.daysInMonth(when.year, when.month);
    return List<DateTime>.generate(
      length,
      (i) => DateTime(when.year, when.month, i + 1),
    );
  }

  /// Same month as [when], shifted by [months] (clamps the day-of-month, so
  /// 31 Jan + 1 month is 28/29 Feb, not 2/3 Mar).
  static DateTime addMonths(DateTime when, int months) {
    final target = DateTime(when.year, when.month + months);
    final maxDay = DateUtilsLocal.daysInMonth(target.year, target.month);
    return DateTime(
      target.year,
      target.month,
      when.day > maxDay ? maxDay : when.day,
      when.hour,
      when.minute,
    );
  }

  /// Combines a calendar [day] with a wall-clock [time] taken from another
  /// instant. Used when a reschedule keeps the time but moves the day.
  static DateTime combine(DateTime day, DateTime time) =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  // ---- ISO round-trip (the wire format the API will use) ----

  /// `2026-08-12T10:30:00.000` — an ISO-8601 string for the API/cache.
  static String toIso(DateTime when) => when.toIso8601String();

  /// Parses an ISO-8601 string, or null when it is not a date.
  static DateTime? fromIso(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  // ---- Label parsing (backward compatibility) ----
  //
  // The screens built before §3.8.3 pass display strings back into the models
  // (`Appointment.copyWith(date: 'Today', time: '10:30 AM')`). These parsers let
  // the typed models keep accepting that shape, so no feature screen had to
  // change. New code should pass a `DateTime` instead.

  /// Parses "Today" / "Tomorrow" / "Yesterday" / "12 Aug 2026" back into a day.
  /// Returns null when [label] is not one of those shapes.
  static DateTime? parseDayLabel(String label, {DateTime? now}) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return null;
    final today = startOfDay(now ?? DateTime.now());
    switch (trimmed.toLowerCase()) {
      case 'today':
        return today;
      case 'tomorrow':
        return today.add(const Duration(days: 1));
      case 'yesterday':
        return today.subtract(const Duration(days: 1));
    }
    try {
      return _dayMonthYear.parseLoose(trimmed);
    } on FormatException {
      // Fall through to a year-less "12 Aug", assuming the current year.
    }
    try {
      final partial = _dayMonth.parseLoose(trimmed);
      return DateTime(today.year, partial.month, partial.day);
    } on FormatException {
      return DateTime.tryParse(trimmed);
    }
  }

  /// Parses "10:30 AM" into a time-of-day carried on an arbitrary day.
  /// Returns null when [label] is not a recognisable clock time.
  static ({int hour, int minute})? parseTimeLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return null;
    try {
      final parsed = _time.parseLoose(trimmed);
      return (hour: parsed.hour, minute: parsed.minute);
    } on FormatException {
      final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
      if (match == null) return null;
      return (
        hour: int.parse(match.group(1)!),
        minute: int.parse(match.group(2)!),
      );
    }
  }

  /// Rebuilds an instant from the display strings the prototype screens use.
  ///
  /// Falls back to [fallback] (default: now) for any part that will not parse,
  /// so a bad label degrades to "the appointment kept its old slot" rather than
  /// throwing inside a controller.
  static DateTime fromLabels({
    String? day,
    String? time,
    DateTime? fallback,
    DateTime? now,
  }) {
    final base = fallback ?? DateTime.now();
    final parsedDay = day == null ? null : parseDayLabel(day, now: now);
    final parsedTime = time == null ? null : parseTimeLabel(time);
    final d = parsedDay ?? base;
    return DateTime(
      d.year,
      d.month,
      d.day,
      parsedTime?.hour ?? base.hour,
      parsedTime?.minute ?? base.minute,
    );
  }
}

/// Calendar arithmetic that does not belong in [AppDates]' public surface.
///
/// Named to avoid colliding with Flutter's `DateUtils` (which this file
/// deliberately does not import, to stay UI-free).
abstract final class DateUtilsLocal {
  DateUtilsLocal._();

  /// Number of days in [month] of [year], leap years included.
  static int daysInMonth(int year, int month) {
    // Day 0 of the following month is the last day of this one.
    return DateTime(year, month + 1, 0).day;
  }

  /// Monday-first weekday index, 0-6, for the month-grid leading blanks.
  static int mondayFirstWeekday(DateTime when) => when.weekday - 1;
}
