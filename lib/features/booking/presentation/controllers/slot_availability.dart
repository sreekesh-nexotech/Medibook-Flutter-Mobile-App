import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/slot.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';

/// Turns a doctor's published slots into the four day states the month
/// calendar renders (CM-12).
///
/// The audit's finding was that the booking screen showed "five fixed days and
/// six fixed times, always shown as available", so neither the calendar nor
/// the slot grid had any state to render besides *available*. The seed now
/// guarantees each state exists for every doctor:
///
/// | Day       | State                                       |
/// |-----------|---------------------------------------------|
/// | yesterday | [DayAvailability.past]                      |
/// | today     | available (past slots marked, not hidden)   |
/// | today + 2 | [DayAvailability.fullyBooked]                |
/// | today + 3 | [DayAvailability.unavailable] (no slots)     |
/// | any Sunday| [DayAvailability.unavailable] (closed)       |
///
/// Reading with `ref.read` rather than `ref.watch` is deliberate: this is
/// called once per visible day from inside the calendar's build, so watching
/// would subscribe the screen to ~35 providers a month. The slot data is
/// derived from a stable seed, so there is nothing to react to.
DayAvailability resolveDayAvailability(
  WidgetRef ref,
  String doctorId,
  DateTime day, {
  DateTime? now,
}) {
  final today = AppDates.startOfDay(now ?? DateTime.now());
  final target = AppDates.startOfDay(day);
  if (target.isBefore(today)) return DayAvailability.past;

  final slots = ref.read(slotsForProvider((doctorId: doctorId, day: target)));
  if (slots.isUnavailable) return DayAvailability.unavailable;
  if (slots.hasAvailability) return DayAvailability.available;
  // Slots were published but none are bookable — a full day, which must read
  // differently from a day the doctor does not consult.
  return DayAvailability.fullyBooked;
}

/// [resolveDayAvailability] bound to one doctor — the shape
/// `showAppDatePickerSheet` and `AppMonthCalendar` take.
DayAvailabilityResolver dayAvailabilityResolver(
  WidgetRef ref,
  String doctorId,
) =>
    (day) => resolveDayAvailability(ref, doctorId, day);

/// Why a day has nothing to offer, worded for the patient (CM-12).
///
/// Three different empty states, because "no slots" for three different
/// reasons is three different next actions:
///
/// * the doctor does not consult that day → pick another day;
/// * the day is full → pick another day (and the taken times are still shown,
///   so the patient can see the doctor is busy rather than that the app is
///   broken);
/// * today's remaining slots have all gone by → pick tomorrow.
///
/// Returns null when the day has bookable slots.
String? slotEmptyMessage(DaySlots slots, {DateTime? now}) {
  if (slots.hasAvailability) return null;
  final reference = now ?? DateTime.now();

  if (slots.isUnavailable) {
    if (slots.day.weekday == DateTime.sunday) {
      return 'The clinic is closed on Sundays. Pick another day.';
    }
    return 'This doctor does not consult on '
        '${AppDates.weekdayLong(slots.day)}, '
        '${AppDates.dayMonth(slots.day)}.';
  }

  if (AppDates.isToday(slots.day, now: reference)) {
    return "Today's slots have all gone by or been taken. "
        'Try tomorrow or a later day.';
  }
  return 'Every slot on ${AppDates.dayMonth(slots.day)} is taken. '
      'Pick another day.';
}
