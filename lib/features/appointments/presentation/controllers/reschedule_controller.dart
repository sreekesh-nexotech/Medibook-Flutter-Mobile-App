import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'appointments_controller.dart';

/// The transient date/time selection while rescheduling one appointment.
///
/// Immutable value object — the notifier swaps in a new instance via [copyWith]
/// on every pick (no field mutation).
class RescheduleSelection {
  const RescheduleSelection({required this.dateIndex, required this.time});

  /// Index into the 5 upcoming date chips (0 == "Today").
  final int dateIndex;

  /// The selected time-slot label, or the appointment's current time until the
  /// user taps a new slot.
  final String time;

  RescheduleSelection copyWith({int? dateIndex, String? time}) =>
      RescheduleSelection(
        dateIndex: dateIndex ?? this.dateIndex,
        time: time ?? this.time,
      );
}

/// Holds the date/time picks for the Reschedule screen. Seeded from the
/// appointment (date chip 0, its current time) — mirroring the prototype's
/// `goResched`, which opens on "Today" with the existing time preselected.
class RescheduleController extends StateNotifier<RescheduleSelection> {
  RescheduleController(RescheduleSelection seed) : super(seed);

  void pickDate(int index) => state = state.copyWith(dateIndex: index);

  void pickTime(String time) => state = state.copyWith(time: time);
}

/// Local UI state for one appointment's reschedule flow → an `autoDispose`
/// family keyed by appointment id, seeded from [appointmentByIdProvider].
final rescheduleControllerProvider = StateNotifierProvider.autoDispose
    .family<RescheduleController, RescheduleSelection, String>((ref, id) {
      final appt = ref.watch(appointmentByIdProvider(id));
      return RescheduleController(
        RescheduleSelection(dateIndex: 0, time: appt?.time ?? ''),
      );
    });
