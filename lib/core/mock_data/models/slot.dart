import '../../utils/date_utils.dart';

/// Whether a slot can be booked, and if not, why (CM-12).
///
/// The audit's point: the booking screen only ever rendered *available* times,
/// so there was no data with which to design "this slot is taken", "this doctor
/// is not in today" or "this whole day is full". All four states exist now, and
/// the seed produces every one of them.
enum SlotStatus {
  /// Bookable.
  available('Available'),

  /// Taken by someone else — shown struck through, not hidden, so the user can
  /// see the doctor is busy rather than that the app is broken.
  booked('Booked'),

  /// The doctor is not consulting then (break, leave, theatre).
  blocked('Unavailable'),

  /// Already gone by. Only appears on today's list.
  past('Past');

  const SlotStatus(this.label);

  final String label;

  bool get isSelectable => this == SlotStatus.available;
}

/// One consultation slot on a doctor's calendar.
///
/// Presentation view-model — immutable, no logic.
class Slot {
  const Slot({
    required this.start,
    required this.status,
    this.durationMinutes = 15,
  });

  /// The slot's start instant.
  final DateTime start;

  final SlotStatus status;

  /// Consultation length; the seed uses 15 minutes throughout.
  final int durationMinutes;

  DateTime get end => start.add(Duration(minutes: durationMinutes));

  /// "10:30 AM" — the chip label, and the string the older booking screen
  /// compares against `MedibookSeed.timeSlots`.
  String get timeLabel => AppDates.timeLabel(start);

  /// "10:30 AM – 10:45 AM" — the confirmation row.
  String get rangeLabel =>
      '${AppDates.timeLabel(start)} – ${AppDates.timeLabel(end)}';

  /// Midnight on the slot's day — the grouping key.
  DateTime get day => AppDates.startOfDay(start);

  bool get isSelectable => status.isSelectable;

  Slot copyWith({DateTime? start, SlotStatus? status, int? durationMinutes}) =>
      Slot(
        start: start ?? this.start,
        status: status ?? this.status,
        durationMinutes: durationMinutes ?? this.durationMinutes,
      );
}

/// A doctor's availability for one day, with the day-level states the booking
/// calendar needs to render (CM-12).
class DaySlots {
  const DaySlots({required this.day, required this.slots});

  /// Midnight on the day these slots belong to.
  final DateTime day;

  /// Every slot, in chronological order — including the unbookable ones.
  final List<Slot> slots;

  /// The slots a user can actually pick.
  List<Slot> get available =>
      slots.where((s) => s.status == SlotStatus.available).toList();

  /// True when the doctor does not consult at all on this day (no slots were
  /// published) — the "unavailable day" the calendar must grey out.
  bool get isUnavailable => slots.isEmpty;

  /// True when slots exist but none are bookable — the "fully booked" day,
  /// which must read differently from "unavailable".
  bool get isFullyBooked => slots.isNotEmpty && available.isEmpty;

  bool get hasAvailability => available.isNotEmpty;

  /// "6 slots" / "Fully booked" / "Not available".
  String get summaryLabel {
    if (isUnavailable) return 'Not available';
    if (isFullyBooked) return 'Fully booked';
    final count = available.length;
    return '$count slot${count == 1 ? '' : 's'}';
  }
}
