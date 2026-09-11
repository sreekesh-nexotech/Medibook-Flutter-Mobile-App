import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/fee_breakdown.dart';
import '../../../../core/mock_data/models/payment.dart';
import '../../../../core/mock_data/stores/payments_store.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../appointments/domain/entities/appointment_receipt.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../../../booking/presentation/controllers/booking_controller.dart';
import '../../../booking/presentation/controllers/booking_records_controller.dart';

/// How a payment attempt ended (CM-20).
enum PaymentOutcome {
  /// Collected online.
  success,

  /// The gateway declined or dropped the attempt. Retryable.
  failed,

  /// Nothing has been collected yet and that is expected — Pay at Hospital
  /// (CM-18), where the money is due at the counter.
  pending;

  bool get isSuccess => this == PaymentOutcome.success;
  bool get isFailure => this == PaymentOutcome.failed;
}

/// The payment step's state.
///
/// [isSubmitting] is the fix for audit §3.5.6 — *"tapping 'Confirm and Pay'
/// twice quickly creates two bookings"*. It is set **synchronously** at the
/// top of [PaymentController.pay], before the first `await`, and the button
/// binds it to `AppButton(loading:)`, which both shows a spinner and refuses
/// taps. [appointmentId] closes the same hole from the other side: an
/// appointment is created at most once per flow, so even a retry after a
/// failure re-uses the booking rather than minting a second one.
class PaymentFlowState {
  const PaymentFlowState({
    this.isSubmitting = false,
    this.appointmentId,
    this.paymentId,
    this.outcome,
    this.failureReason,
    this.simulatedOutcome = PaymentOutcome.success,
  });

  /// True while an attempt is in flight.
  final bool isSubmitting;

  /// The appointment this flow created, or null before the first attempt.
  final String? appointmentId;

  /// The `paymentsStoreProvider` entry for the most recent attempt.
  final String? paymentId;

  /// How the most recent attempt ended, or null before the first attempt.
  final PaymentOutcome? outcome;

  /// The gateway's reason, when [outcome] is [PaymentOutcome.failed].
  final String? failureReason;

  /// Demo-only: which outcome the simulated gateway should produce. There is
  /// no payment SDK in this build and none may be added, so the failure and
  /// pending paths need a way to be reached — see [PaymentController.pay].
  final PaymentOutcome simulatedOutcome;

  /// True once an attempt has been made — the retry copy keys off this.
  bool get hasAttempted => outcome != null;

  PaymentFlowState copyWith({
    bool? isSubmitting,
    String? appointmentId,
    String? paymentId,
    PaymentOutcome? outcome,
    String? Function()? failureReason,
    PaymentOutcome? simulatedOutcome,
  }) => PaymentFlowState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    appointmentId: appointmentId ?? this.appointmentId,
    paymentId: paymentId ?? this.paymentId,
    outcome: outcome ?? this.outcome,
    failureReason: failureReason != null ? failureReason() : this.failureReason,
    simulatedOutcome: simulatedOutcome ?? this.simulatedOutcome,
  );
}

/// Drives the payment step (CM-17, CM-18, CM-20).
///
/// ## What is real and what is simulated
///
/// Real: the appointment, the booking reference, the token, the fee
/// arithmetic, the `paymentsStoreProvider` ledger entry with its receipt
/// number and GSTIN, and the `attachPayment` link between the two. Every
/// screen downstream — appointment detail, receipt, refunds — reads those.
///
/// Simulated: the authorisation itself. No gateway SDK exists in this build
/// and none may be added, so [pay] waits [_gatewayLatency] and then applies
/// [PaymentFlowState.simulatedOutcome]. The payment screen says so on screen
/// with an `AppStubBanner` and exposes the selector, so nothing here claims
/// money moved when it did not (THE LAW).
///
/// Not `autoDispose`: the result screen reads this after the payment screen
/// has been popped. It is reset explicitly by [reset] when a new booking flow
/// starts a payment.
class PaymentController extends StateNotifier<PaymentFlowState> {
  PaymentController(this._ref) : super(const PaymentFlowState());

  final Ref _ref;

  /// How long the simulated authorisation takes. Long enough that a human can
  /// physically tap the button twice inside it — which is exactly the window
  /// audit §3.5.6 found unguarded.
  static const Duration _gatewayLatency = Duration(milliseconds: 1200);

  /// House wording for a declined attempt. One string, so the result screen
  /// and the ledger entry cannot disagree.
  static const String declinedReason =
      'The bank declined this payment. No money has left your account.';

  void chooseSimulatedOutcome(PaymentOutcome outcome) =>
      state = state.copyWith(simulatedOutcome: outcome);

  /// Clear the attempt state for a fresh booking. Call when the payment screen
  /// is opened for a different booking reference.
  void reset() => state = const PaymentFlowState();

  /// Attempt to pay for [draft] (CM-17).
  ///
  /// Returns null — and does nothing at all — when an attempt is already in
  /// flight, so a double tap cannot create a second booking or a second ledger
  /// entry. Otherwise returns how the attempt ended.
  ///
  /// [method] decides the shape of the attempt, not just its label: the
  /// Pay-at-Hospital choice records a genuinely **pending** payment due at the
  /// counter (CM-18) rather than a fake collection.
  Future<PaymentOutcome?> pay({
    required BookingDraft draft,
    required FeeBreakdown fee,
    required PaymentMethod method,
  }) async {
    // The guard. Synchronous, before any await.
    if (state.isSubmitting) return null;
    final slot = draft.slot;
    final doctorId = draft.doctorId;
    if (slot == null || doctorId == null) return null;
    if (draft.holdExpired) return null;

    state = state.copyWith(isSubmitting: true, failureReason: () => null);

    await Future<void>.delayed(_gatewayLatency);

    final appointmentId =
        state.appointmentId ??
        _createAppointment(draft: draft, fee: fee, method: method);

    final PaymentOutcome outcome = method.isOnline
        ? state.simulatedOutcome
        : PaymentOutcome.pending;

    final payment = _ref
        .read(paymentsStoreProvider.notifier)
        .record(
          appointmentId: appointmentId,
          method: method,
          amount: fee.total,
          sequence: _ref.read(bookingRecordsProvider.notifier).lastSequence,
          status: switch (outcome) {
            PaymentOutcome.success => PaymentStatus.paid,
            PaymentOutcome.failed => PaymentStatus.failed,
            PaymentOutcome.pending => PaymentStatus.pending,
          },
          gstNumber: AppointmentReceipt.hospitalGstin,
          failureReason: outcome.isFailure ? declinedReason : null,
        );

    // Only link a payment the patient can be shown: a declined attempt stays
    // in the ledger for support, but it is not this appointment's payment.
    if (!outcome.isFailure) {
      _ref
          .read(appointmentsControllerProvider.notifier)
          .attachPayment(appointmentId, payment.id);
      _ref
          .read(bookingRecordsProvider.notifier)
          .linkPayment(appointmentId, payment.id);
    }

    state = state.copyWith(
      isSubmitting: false,
      appointmentId: appointmentId,
      paymentId: payment.id,
      outcome: outcome,
      failureReason: () => outcome.isFailure ? declinedReason : null,
    );
    return outcome;
  }

  /// Create the appointment and file the booking record. Called at most once
  /// per flow — see [PaymentFlowState.appointmentId].
  String _createAppointment({
    required BookingDraft draft,
    required FeeBreakdown fee,
    required PaymentMethod method,
  }) {
    final slot = draft.slot!;
    final appointment = _ref
        .read(appointmentsControllerProvider.notifier)
        .book(
          doctorId: draft.doctorId!,
          patient: draft.patientName,
          // `book` still takes display strings and parses them back into a
          // real instant (see the core contract §2.5). The instant is the
          // source here; the strings are derived from it, never the reverse.
          dateFull: AppDates.dayMonthYear(slot.start),
          time: AppDates.timeLabel(slot.start),
        );

    _ref
        .read(bookingRecordsProvider.notifier)
        .add(
          BookingRecord(
            appointmentId: appointment.id,
            bookingRef: draft.bookingRef ?? appointment.bookingRef ?? '',
            token: draft.token ?? appointment.token,
            scheduledAt: slot.start,
            amount: fee.total,
            method: method,
            createdAt: DateTime.now(),
            hospitalId: draft.hospitalId,
            patientId: draft.patientId,
          ),
        );
    return appointment.id;
  }
}

/// The payment step's controller. Deliberately not `autoDispose` — the result
/// screen outlives the payment screen.
final paymentControllerProvider =
    StateNotifierProvider<PaymentController, PaymentFlowState>(
      PaymentController.new,
    );
