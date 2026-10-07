import '../../../../core/error/failure.dart';
import '../../../booking/domain/entities/booked_appointment.dart';
import '../../../booking/domain/entities/payment_order.dart';
import '../../domain/entities/payment_record.dart';

/// Where the payment step is (§9).
enum PaymentPhase {
  /// Nothing attempted yet, or a failed attempt awaiting a retry.
  idle,

  /// The gateway sheet is open.
  checkout,

  /// `POST …/verify` is in flight.
  verifying,

  /// A new order is being minted (`POST …/retry`).
  retrying,

  /// The order is being re-read (`GET …/orders/{id}`).
  polling,

  /// Paid; the appointment is scheduled.
  paid,

  /// Paid; the hospital confirms online bookings by hand.
  pendingApproval,

  /// The gateway declined, the signature failed, or the sheet was closed.
  failed,

  /// Money arrived after the deadline: cancelled, refund initiated.
  latePayment,

  /// The 5 minutes ran out before a payment was made.
  expired;

  bool get isBusy =>
      this == checkout ||
      this == verifying ||
      this == retrying ||
      this == polling;

  bool get isSettled => this == paid || this == pendingApproval;

  /// True when there is nothing left to pay for on this booking.
  bool get isFinal => isSettled || this == latePayment || this == expired;
}

/// The payment step's state. Immutable; every update is a [copyWith].
///
/// The idempotency keys follow §1.8: one per verify attempt of the *same*
/// payment, one per retry action, each reused when that action is repeated
/// after a lost response.
class PaymentFlowState {
  const PaymentFlowState({
    this.phase = PaymentPhase.idle,
    this.order,
    this.appointment,
    this.payment,
    this.failure,
    this.failureMessage,
    this.wasCancelled = false,
    this.verifyKey,
    this.retryKey,
  });

  final PaymentPhase phase;

  /// The order being paid — replaced by a retry.
  final PaymentOrder? order;

  /// The appointment, refreshed from the verify response.
  final BookedAppointment? appointment;

  /// The captured payment, once verified.
  final PaymentRecord? payment;

  /// A backend failure from verify / retry / poll, or null.
  final Failure? failure;

  /// Why the last attempt failed, worded for the patient.
  final String? failureMessage;

  /// True when the last attempt ended because the patient closed the sheet.
  final bool wasCancelled;

  final String? verifyKey;
  final String? retryKey;

  bool get hasOrder => order != null;

  /// The amount to pay: from the order, never from a quote (§8.3).
  int? get amountPaise => order?.amountPaise;

  DateTime? get deadline => appointment?.bookingDeadlineAt ?? order?.expiresAt;

  PaymentFlowState copyWith({
    PaymentPhase? phase,
    PaymentOrder? Function()? order,
    BookedAppointment? Function()? appointment,
    PaymentRecord? Function()? payment,
    Failure? Function()? failure,
    String? Function()? failureMessage,
    bool? wasCancelled,
    String? Function()? verifyKey,
    String? Function()? retryKey,
  }) => PaymentFlowState(
    phase: phase ?? this.phase,
    order: order != null ? order() : this.order,
    appointment: appointment != null ? appointment() : this.appointment,
    payment: payment != null ? payment() : this.payment,
    failure: failure != null ? failure() : this.failure,
    failureMessage: failureMessage != null
        ? failureMessage()
        : this.failureMessage,
    wasCancelled: wasCancelled ?? this.wasCancelled,
    verifyKey: verifyKey != null ? verifyKey() : this.verifyKey,
    retryKey: retryKey != null ? retryKey() : this.retryKey,
  );
}
