import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../core/mock_data/medibook_seed.dart';
import '../../../../core/mock_data/models/patient.dart';
import '../../../../core/mock_data/models/payment.dart';
import '../../../../core/mock_data/models/slot.dart';
import '../../../../core/utils/date_utils.dart';

/// Where a booking flow was entered from — the back button at step 1 returns
/// here.
enum BookingOrigin { home, appointments }

/// Immutable in-flight booking draft (step + selections). Updated only via
/// [copyWith].
///
/// ## What changed for CM-11 / CM-12 / X-02
///
/// * A **hospital** can now be part of the draft ([hospitalId]), so the real
///   discovery funnel — location → hospital → department → doctor → slot —
///   filters the department and doctor steps. It stays null for the
///   department-first entry from Home and Search, which is unchanged.
/// * The date is a real [DateTime] ([day]) and the time is a real [Slot]
///   ([slot]), not an index into five fixed chips and a display string. That
///   is what lets the calendar render `fullyBooked` / `unavailable` days and
///   the slot grid render `booked` / `blocked` / `past` times.
/// * The patient is identified by [patientId] as well as [patientName], so a
///   dependant added in Profile can be picked here (CM-16).
/// * The slot is **held** for [AppConstants.slotHold] from the moment the
///   patient reaches the summary ([holdUntil]), and the booking reference is
///   minted at the same moment so it is on screen before payment (CM-14,
///   X-02).
class BookingDraft {
  const BookingDraft({
    this.step = 1,
    this.hospitalId,
    this.departmentName,
    this.doctorId,
    this.patientId,
    this.patientName = MedibookSeed.userName,
    this.day,
    this.slot,
    this.couponCode,
    this.couponError,
    this.holdUntil,
    this.holdExpired = false,
    this.bookingRef,
    this.token,
    this.method,
    this.origin = BookingOrigin.home,
  });

  /// 1 = department, 2 = doctor, 3 = patient/date/time, 4 = summary.
  final int step;

  /// The facility the funnel was entered through (CM-11). Null for the
  /// department-first entry.
  final String? hospitalId;

  final String? departmentName;
  final String? doctorId;

  /// The dependant the appointment is for; null means the account holder.
  final String? patientId;

  /// Display name of the chosen patient.
  final String patientName;

  /// The chosen day, midnight-normalised. Null until the patient picks one.
  final DateTime? day;

  /// The chosen slot. Null until the patient picks one; only an
  /// [SlotStatus.available] slot can ever land here.
  final Slot? slot;

  /// An applied coupon code, or null (CM-19).
  final String? couponCode;

  /// Why the last coupon attempt failed, or null. Transient form state.
  final String? couponError;

  /// When the slot hold runs out (X-02). Null when nothing is held.
  final DateTime? holdUntil;

  /// True once the hold ran out — the patient must pick a slot again.
  final bool holdExpired;

  /// The reference minted when the hold started (CM-14).
  final String? bookingRef;

  /// The token this booking will be given, canonical `T-026`.
  final String? token;

  /// The payment method chosen on the payment screen (CM-17, CM-18).
  final PaymentMethod? method;

  final BookingOrigin origin;

  bool get isFirstStep => step == 1;
  bool get isLastStep => step == 4;

  /// Continue is disabled until the current step's required pick exists.
  bool get canContinue => switch (step) {
    1 => departmentName != null,
    2 => doctorId != null,
    3 => slot != null,
    _ => true,
  };

  /// True while a slot is held and the deadline has not passed.
  bool get isHoldActive =>
      !holdExpired &&
      holdUntil != null &&
      holdUntil!.isAfter(DateTime.now());

  /// The chosen slot's start instant — the appointment's `scheduledAt`.
  DateTime? get scheduledAt => slot?.start;

  /// "Today" / "14 Sep 2026", or null before a day is chosen.
  String? get dayLabel => day == null ? null : AppDates.relativeDay(day!);

  /// "10:30 AM – 10:45 AM", or null before a slot is chosen.
  String? get slotRangeLabel => slot?.rangeLabel;

  /// Everything the payment step needs is present.
  bool get isPayable => doctorId != null && slot != null && bookingRef != null;

  BookingDraft copyWith({
    int? step,
    String? Function()? hospitalId,
    String? Function()? departmentName,
    String? Function()? doctorId,
    String? Function()? patientId,
    String? patientName,
    DateTime? Function()? day,
    Slot? Function()? slot,
    String? Function()? couponCode,
    String? Function()? couponError,
    DateTime? Function()? holdUntil,
    bool? holdExpired,
    String? Function()? bookingRef,
    String? Function()? token,
    PaymentMethod? Function()? method,
    BookingOrigin? origin,
  }) {
    return BookingDraft(
      step: step ?? this.step,
      hospitalId: hospitalId != null ? hospitalId() : this.hospitalId,
      departmentName: departmentName != null
          ? departmentName()
          : this.departmentName,
      doctorId: doctorId != null ? doctorId() : this.doctorId,
      patientId: patientId != null ? patientId() : this.patientId,
      patientName: patientName ?? this.patientName,
      day: day != null ? day() : this.day,
      slot: slot != null ? slot() : this.slot,
      couponCode: couponCode != null ? couponCode() : this.couponCode,
      couponError: couponError != null ? couponError() : this.couponError,
      holdUntil: holdUntil != null ? holdUntil() : this.holdUntil,
      holdExpired: holdExpired ?? this.holdExpired,
      bookingRef: bookingRef != null ? bookingRef() : this.bookingRef,
      token: token != null ? token() : this.token,
      method: method != null ? method() : this.method,
      origin: origin ?? this.origin,
    );
  }
}

/// Drives the 4-step booking flow. `autoDispose` — this is temporary UI state
/// that must reset once the flow is left (per the coding standards / QA).
///
/// The payment screen sits **on top of** the booking route, so this provider
/// is still watched while the patient pays and the draft survives the hop.
/// Once the flow is left for good (Home, the appointment detail) it disposes
/// and the next booking starts clean.
class BookingController extends StateNotifier<BookingDraft> {
  BookingController() : super(const BookingDraft());

  /// Seed the draft when entering the flow (called from a screen's initState /
  /// an entry callback — not from `build`).
  void configure({
    int step = 1,
    String? hospitalId,
    String? departmentName,
    String? doctorId,
    BookingOrigin origin = BookingOrigin.home,
    Patient? patient,
  }) {
    state = BookingDraft(
      step: step,
      hospitalId: hospitalId,
      departmentName: departmentName,
      doctorId: doctorId,
      origin: origin,
      patientId: patient?.id,
      patientName: patient?.name ?? MedibookSeed.userName,
    );
  }

  /// Enter the funnel at a facility (CM-11). Clears the doctor, because a
  /// doctor from another hospital is no longer a valid pick.
  void pickHospital(String? id) => state = state.copyWith(
    hospitalId: () => id,
    doctorId: () => null,
    day: () => null,
    slot: () => null,
  );

  void pickDepartment(String name) => state = state.copyWith(
    departmentName: () => name,
    // Reset the doctor — and with it the day and slot, which belong to that
    // doctor's calendar.
    doctorId: () => null,
    day: () => null,
    slot: () => null,
  );

  void pickDoctor(String id) {
    if (state.doctorId == id) return;
    state = state.copyWith(
      doctorId: () => id,
      day: () => null,
      slot: () => null,
    );
  }

  /// Pick the patient the appointment is for (CM-16).
  void pickPatient(Patient patient) => state = state.copyWith(
    patientId: () => patient.id,
    patientName: patient.name,
  );

  /// Choose a day. Clears the slot, since slot instants belong to one day.
  void pickDay(DateTime day) {
    final normalised = AppDates.startOfDay(day);
    if (state.day != null && AppDates.isSameDay(state.day!, normalised)) return;
    state = state.copyWith(day: () => normalised, slot: () => null);
  }

  /// Choose a slot. Refuses anything the patient cannot actually book, so an
  /// unselectable chip can never end up in the draft.
  void pickSlot(Slot slot) {
    if (!slot.isSelectable) return;
    state = state.copyWith(
      slot: () => slot,
      day: () => slot.day,
      holdExpired: false,
    );
  }

  /// Apply a coupon (CM-19). [error] is the honest feedback for a code the
  /// catalogue does not know; pass it with a null [code].
  void applyCoupon({String? code, String? error}) => state = state.copyWith(
    couponCode: () => code,
    couponError: () => error,
  );

  void removeCoupon() =>
      state = state.copyWith(couponCode: () => null, couponError: () => null);

  void pickMethod(PaymentMethod method) =>
      state = state.copyWith(method: () => method);

  /// Start the slot hold and mint the identifiers (X-02, CM-14).
  ///
  /// [bookingRef] and [token] are supplied by the caller because they come
  /// from the shared ledger / token counter, which this draft does not own.
  /// Re-entering the summary re-arms the countdown but keeps the reference —
  /// one booking attempt, one reference.
  void startHold({required String bookingRef, required String token}) {
    state = state.copyWith(
      holdUntil: () => DateTime.now().add(AppConstants.slotHold),
      holdExpired: false,
      bookingRef: () => state.bookingRef ?? bookingRef,
      token: () => token,
    );
  }

  /// The hold ran out (X-02). The slot is kept for the expiry message to name,
  /// and is cleared by [backToSlotSelection] when the patient acts on it.
  void expireHold() {
    if (state.holdExpired) return;
    state = state.copyWith(holdExpired: true, holdUntil: () => null);
  }

  /// Give the slot back without expiring (the patient left the payment step).
  void releaseHold() =>
      state = state.copyWith(holdUntil: () => null, holdExpired: false);

  /// Return to step 3 with the slot cleared — where an expired hold lands.
  void backToSlotSelection() => state = state.copyWith(
    step: 3,
    slot: () => null,
    holdUntil: () => null,
    holdExpired: false,
  );

  void nextStep() {
    if (state.step < 4) state = state.copyWith(step: state.step + 1);
  }

  /// Returns true if a step was consumed; false when already at step 1 (caller
  /// should then pop the route to [BookingDraft.origin]).
  bool back() {
    if (state.step > 1) {
      // Walking back out of the summary gives the held slot back — holding a
      // slot for someone who has left the payment step is the bug X-02 is
      // about, in reverse.
      state = state.copyWith(
        step: state.step - 1,
        holdUntil: () => null,
        holdExpired: false,
      );
      return true;
    }
    return false;
  }
}

final bookingControllerProvider =
    StateNotifierProvider.autoDispose<BookingController, BookingDraft>(
      (ref) => BookingController(),
    );
