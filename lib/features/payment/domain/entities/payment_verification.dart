import '../../../booking/domain/entities/booked_appointment.dart';
import '../../../booking/domain/entities/payment_order.dart';
import 'payment_record.dart';

/// What `POST /patient/payments/orders/{id}/verify` returns (§9.3).
///
/// Success is `order.status == paid`. When the money arrived after the
/// 5-minute deadline the order is not paid, the appointment is cancelled and
/// a refund has already been started — [isLatePayment].
class PaymentVerification {
  const PaymentVerification({
    required this.status,
    required this.order,
    required this.appointment,
    this.payment,
  });

  /// `= order.status`.
  final PaymentOrderStatus status;
  final PaymentOrder order;
  final PaymentRecord? payment;
  final BookedAppointment appointment;

  bool get isPaid => status.isPaid;

  /// Paid, but the hospital approves online bookings by hand.
  bool get needsHospitalApproval => isPaid && appointment.isPendingApproval;

  /// Money received after the deadline: cancelled and refunded in full.
  bool get isLatePayment => !isPaid && appointment.isCancelled;
}
