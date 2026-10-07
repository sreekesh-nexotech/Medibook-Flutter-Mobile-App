import '../../../../core/utils/money.dart';
import 'appointment.dart';
import 'payment.dart';

/// The buttons the detail screen may show (§10.2 `actions`).
///
/// The backend decides; the app never re-derives cancel / retry / review
/// rules from status and clock.
class AppointmentActions {
  const AppointmentActions({
    this.canCancel = false,
    this.cancelBlockedReason,
    this.canRetryPayment = false,
    this.canReview = false,
  });

  final bool canCancel;

  /// When [canCancel] is false: `APPOINTMENT_NOT_ACTIONABLE` |
  /// `TOKEN_ALREADY_CALLED` | `TOKEN_CANCEL_WINDOW_CLOSED`, or null.
  final String? cancelBlockedReason;

  /// `pending_payment` and the deadline has not passed.
  final bool canRetryPayment;

  /// `completed` and not yet reviewed.
  final bool canReview;
}

/// A payment order (§9.1) — the latest one on the appointment.
class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.appointmentId,
    required this.amount,
    required this.status,
    this.currency = 'INR',
    this.gateway,
    this.gatewayOrderId,
    this.keyId,
    this.attempts = 1,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String appointmentId;
  final Money amount;
  final String currency;
  final String? gateway;

  /// → Razorpay checkout `order_id`.
  final String? gatewayOrderId;

  /// → Razorpay checkout `key`.
  final String? keyId;

  /// `created | attempted | paid | failed | expired | cancelled`.
  final String status;
  final int attempts;
  final DateTime? expiresAt;
  final DateTime? createdAt;
}

/// The receipt stub on a detail (§10.2) — the full receipt is §10.8.
class ReceiptSummary {
  const ReceiptSummary({required this.receiptNo, this.issuedAt});

  final String receiptNo;
  final DateTime? issuedAt;
}

/// `GET /patient/appointments/{id}` — the appointment plus what the detail
/// screen needs to render its buttons and money rows.
class AppointmentDetail {
  const AppointmentDetail({
    required this.appointment,
    required this.actions,
    this.paymentOrder,
    this.receipt,
    this.refunds = const <Refund>[],
    this.reviewed = false,
  });

  final Appointment appointment;
  final AppointmentActions actions;
  final PaymentOrder? paymentOrder;
  final ReceiptSummary? receipt;
  final List<Refund> refunds;
  final bool reviewed;

  bool get hasReceipt => receipt != null;
}
