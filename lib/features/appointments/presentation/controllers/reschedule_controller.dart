import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/slot.dart';
import '../../../../core/utils/date_utils.dart';
import 'appointments_controller.dart';

/// The transient date/slot selection while rescheduling one appointment.
///
/// Immutable value object — the notifier swaps in a new instance on every pick.
///
/// Both fields are **real date values**, not the old `dateIndex` + `'10:30 AM'`
/// pair. A reschedule that round-tripped through a chip index and a clock
/// string could not tell 10:30 tomorrow from 10:30 next week (audit §3.8.3);
/// [scheduledAt] is the exact instant the appointment moves to.
class RescheduleSelection {
  const RescheduleSelection({required this.day, this.slot});

  /// The selected day, normalised to midnight.
  final DateTime day;

  /// The selected slot on [day], or null until the patient picks one.
  ///
  /// Deliberately **not** pre-filled from the appointment's current time: the
  /// old time may not even be offered on the new day, and a pre-filled slot
  /// the patient never chose is how a booking moves by accident.
  final Slot? slot;

  /// The instant the appointment would move to, or null while no slot is
  /// picked.
  DateTime? get scheduledAt => slot?.start;

  /// True once there is something to confirm.
  bool get isComplete => slot != null;

  RescheduleSelection copyWith({DateTime? day, Slot? slot}) =>
      RescheduleSelection(day: day ?? this.day, slot: slot ?? this.slot);

  /// [day] selected, with any slot pick dropped — a slot only means something
  /// on the day it belongs to.
  RescheduleSelection onDay(DateTime day) =>
      RescheduleSelection(day: AppDates.startOfDay(day));
}

/// Holds the date/slot picks for the Reschedule screen.
///
/// Seeded on the appointment's own day, so the screen opens showing the
/// availability the patient is comparing against.
class RescheduleController extends StateNotifier<RescheduleSelection> {
  RescheduleController(super.state);

  /// Pick a day. Clears the slot — see [RescheduleSelection.onDay].
  void pickDay(DateTime day) => state = state.onDay(day);

  /// Pick a slot on the current day. Ignores a slot that is not selectable, so
  /// a booked or blocked chip can never become a confirmed reschedule.
  void pickSlot(Slot slot) {
    if (!slot.isSelectable) return;
    state = state.copyWith(slot: slot);
  }

  /// Drop the slot pick (used when the day's availability reloads).
  void clearSlot() => state = state.onDay(state.day);
}

/// Local UI state for one appointment's reschedule flow → an `autoDispose`
/// family keyed by appointment id, seeded from [appointmentByIdProvider].
final rescheduleControllerProvider = StateNotifierProvider.autoDispose
    .family<RescheduleController, RescheduleSelection, String>((ref, id) {
      final appointment = ref.watch(appointmentByIdProvider(id));
      final day = AppDates.startOfDay(
        appointment?.scheduledAt ?? DateTime.now(),
      );
      return RescheduleController(RescheduleSelection(day: day));
    });
