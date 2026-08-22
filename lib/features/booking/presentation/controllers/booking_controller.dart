import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/medibook_seed.dart';

/// Where a booking flow was entered from — the back button at step 1 returns
/// here.
enum BookingOrigin { home, appointments }

/// Immutable in-flight booking draft (step + selections). Updated only via
/// [copyWith].
class BookingDraft {
  const BookingDraft({
    this.step = 1,
    this.departmentName,
    this.doctorId,
    this.patientName = MedibookSeed.userName,
    this.dateIndex = 0,
    this.time = '10:00 AM',
    this.origin = BookingOrigin.home,
  });

  /// 1 = department, 2 = doctor, 3 = patient/date/time, 4 = confirm.
  final int step;
  final String? departmentName;
  final String? doctorId;
  final String patientName;
  final int dateIndex;
  final String time;
  final BookingOrigin origin;

  bool get isFirstStep => step == 1;
  bool get isLastStep => step == 4;

  /// Continue button is disabled until the current step's required pick exists.
  bool get canContinue => switch (step) {
    1 => departmentName != null,
    2 => doctorId != null,
    _ => true,
  };

  BookingDraft copyWith({
    int? step,
    String? Function()? departmentName,
    String? Function()? doctorId,
    String? patientName,
    int? dateIndex,
    String? time,
    BookingOrigin? origin,
  }) {
    return BookingDraft(
      step: step ?? this.step,
      departmentName:
          departmentName != null ? departmentName() : this.departmentName,
      doctorId: doctorId != null ? doctorId() : this.doctorId,
      patientName: patientName ?? this.patientName,
      dateIndex: dateIndex ?? this.dateIndex,
      time: time ?? this.time,
      origin: origin ?? this.origin,
    );
  }
}

/// Drives the 4-step booking flow. `autoDispose` — this is temporary UI state
/// that must reset once the flow is left (per the coding standards / QA).
class BookingController extends StateNotifier<BookingDraft> {
  BookingController() : super(const BookingDraft());

  /// Seed the draft when entering the flow (called from a screen's initState /
  /// an entry callback — not from `build`).
  void configure({
    int step = 1,
    String? departmentName,
    String? doctorId,
    BookingOrigin origin = BookingOrigin.home,
    String? patientName,
  }) {
    state = BookingDraft(
      step: step,
      departmentName: departmentName,
      doctorId: doctorId,
      origin: origin,
      patientName: patientName ?? MedibookSeed.userName,
    );
  }

  void pickDepartment(String name) =>
      state = state.copyWith(
        departmentName: () => name,
        doctorId: () => null, // reset doctor when department changes
      );

  void pickDoctor(String id) => state = state.copyWith(doctorId: () => id);

  void pickPatient(String name) => state = state.copyWith(patientName: name);

  void pickDate(int index) => state = state.copyWith(dateIndex: index);

  void pickTime(String time) => state = state.copyWith(time: time);

  void nextStep() {
    if (state.step < 4) state = state.copyWith(step: state.step + 1);
  }

  /// Returns true if a step was consumed; false when already at step 1 (caller
  /// should then pop the route to [BookingDraft.origin]).
  bool back() {
    if (state.step > 1) {
      state = state.copyWith(step: state.step - 1);
      return true;
    }
    return false;
  }
}

final bookingControllerProvider =
    StateNotifierProvider.autoDispose<BookingController, BookingDraft>(
      (ref) => BookingController(),
    );
