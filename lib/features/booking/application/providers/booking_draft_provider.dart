import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/doctor.dart';
import '../../domain/entities/person_summary.dart';
import '../../domain/entities/slots.dart';
import '../states/booking_draft.dart';

/// Drives the 4-step booking flow. `autoDispose` — the draft is temporary UI
/// state that must reset once the flow is left.
///
/// The payment screens are pushed **on top of** the booking route, so this
/// provider is still watched while the patient pays and the draft survives
/// the hop. Once the flow is left for good it disposes and the next booking
/// starts clean. No navigation, no toasts, no `BuildContext` in here.
class BookingDraftController extends StateNotifier<BookingDraft> {
  BookingDraftController() : super(const BookingDraft());

  /// Seed the draft when entering the flow (from an entry callback, never
  /// from `build`).
  void configure({
    int step = 1,
    String? hospitalId,
    String? departmentCode,
    String? doctorId,
    BookingOrigin origin = BookingOrigin.home,
  }) {
    state = BookingDraft(
      step: step.clamp(1, 4),
      hospitalId: hospitalId,
      departmentCode: departmentCode,
      // A doctor named only by id is resolved by the screen through
      // `doctorDetailProvider`, then handed to [pickDoctor].
      origin: origin,
    );
  }

  /// Scope the funnel to a facility. Clears the doctor, because a doctor from
  /// another hospital is no longer a valid pick.
  void pickHospital({
    required String id,
    required String name,
    String? timezone,
  }) {
    if (state.hospitalId == id) return;
    state = state.copyWith(
      hospitalId: () => id,
      hospitalName: () => name,
      hospitalTimezone: () => timezone,
      doctor: () => null,
      date: () => null,
      slot: () => null,
      sessionLabel: () => null,
    );
  }

  /// Leave the facility scope (department-first entry again).
  void clearHospital() => state = state.copyWith(
    hospitalId: () => null,
    hospitalName: () => null,
    hospitalTimezone: () => null,
    doctor: () => null,
    date: () => null,
    slot: () => null,
    sessionLabel: () => null,
  );

  /// Names the department the flow was opened on by code alone — a Home
  /// service tile, a hospital's "View more doctors", a link — once the
  /// server's list has it. Nothing else changes.
  void nameDepartment({required String code, required String name}) {
    if (state.departmentCode != code || state.departmentName != null) return;
    state = state.copyWith(departmentName: () => name);
  }

  void pickDepartment({required String code, required String name}) {
    if (state.departmentCode == code) return;
    state = state.copyWith(
      departmentCode: () => code,
      departmentName: () => name,
      // The doctor — and with it the day and slot — belongs to a department.
      doctor: () => null,
      date: () => null,
      slot: () => null,
      sessionLabel: () => null,
    );
  }

  /// Pick a doctor. The doctor card carries its hospital, so a doctor picked
  /// from Search or Home also scopes the flow to that facility.
  void pickDoctor(DoctorCard doctor) {
    if (state.doctor?.id == doctor.id) return;
    state = state.copyWith(
      doctor: () => doctor,
      hospitalId: () => doctor.hospital.id,
      hospitalName: () => doctor.hospital.name,
      departmentCode: () => doctor.department.code,
      departmentName: () => doctor.department.name,
      date: () => null,
      slot: () => null,
      sessionLabel: () => null,
    );
  }

  /// Record the hospital's zone once the detail has been read, so slot
  /// labels render in hospital time.
  void setHospitalTimezone(String? timezone) {
    if (state.hospitalTimezone == timezone) return;
    state = state.copyWith(hospitalTimezone: () => timezone);
  }

  /// Choose a slot. Refuses anything the patient cannot book, so an
  /// unselectable chip can never end up in the draft.
  void pickSlot(Slot slot, {required String date, String? sessionLabel}) {
    if (!slot.isSelectable) return;
    state = state.copyWith(
      slot: () => slot,
      date: () => date,
      sessionLabel: () => sessionLabel,
    );
  }

  /// The slot was taken between showing it and booking it
  /// (`409 SLOT_UNAVAILABLE`): drop it and return to the time step.
  void clearSlot() => state = state.copyWith(
    slot: () => null,
    sessionLabel: () => null,
    step: state.step > 3 ? 3 : state.step,
  );

  void pickPerson(PersonSummary person) =>
      state = state.copyWith(person: () => person);

  void setNotes(String? notes) {
    final trimmed = notes?.trim();
    state = state.copyWith(
      patientNotes: () => trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
  }

  /// Type a coupon. Its validity is the fee quote's verdict (§8.3).
  void applyCoupon(String code) {
    final trimmed = code.trim().toUpperCase();
    state = state.copyWith(couponCode: () => trimmed.isEmpty ? null : trimmed);
  }

  void removeCoupon() => state = state.copyWith(couponCode: () => null);

  void goToStep(int step) {
    final target = step.clamp(1, 4);
    if (target == state.step) return;
    state = state.copyWith(step: target);
  }

  void nextStep() {
    if (state.step < 4) state = state.copyWith(step: state.step + 1);
  }

  /// Returns true if a step was consumed; false when already at step 1 (the
  /// caller then pops the route to [BookingDraft.origin]).
  bool back() {
    if (state.step > 1) {
      state = state.copyWith(step: state.step - 1);
      return true;
    }
    return false;
  }
}

final bookingDraftProvider =
    StateNotifierProvider.autoDispose<BookingDraftController, BookingDraft>(
      (ref) => BookingDraftController(),
    );
