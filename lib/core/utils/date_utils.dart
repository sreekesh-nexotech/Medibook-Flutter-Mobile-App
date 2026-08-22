import 'package:intl/intl.dart';

/// A single selectable day chip for the booking / reschedule date rows.
class DateChip {
  const DateChip({required this.dow, required this.day, required this.full});

  /// Day-of-week label ("Today" for index 0, else "Mon", "Tue"…).
  final String dow;

  /// Day-of-month number, e.g. "22".
  final String day;

  /// Full human date used in confirmation rows ("Today" or "22 Aug 2026").
  final String full;
}

/// Date helpers. The prototype generates 5 chips starting today with the first
/// labelled "Today"; we mirror that. Kept as pure functions so the future
/// application layer can call them without any UI dependency.
abstract final class AppDates {
  AppDates._();

  /// Build [count] day chips starting from [from] (defaults to today).
  static List<DateChip> upcomingChips({int count = 5, DateTime? from}) {
    final base = from ?? DateTime.now();
    final dow = DateFormat('EEE'); // Mon, Tue…
    final full = DateFormat('d MMM yyyy'); // 22 Aug 2026
    return List<DateChip>.generate(count, (i) {
      final d = DateTime(base.year, base.month, base.day + i);
      final isToday = i == 0;
      return DateChip(
        dow: isToday ? 'Today' : dow.format(d),
        day: d.day.toString(),
        full: isToday ? 'Today' : full.format(d),
      );
    });
  }
}
