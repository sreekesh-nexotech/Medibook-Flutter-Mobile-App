import '../../../booking/domain/entities/booking_result.dart';
import '../../../booking/domain/entities/payment_order.dart';
import '../entities/payment_verification.dart';

/// The payment-order contract (§9.3–§9.5).
///
/// **Error contract:** every method throws a `Failure`. [verify] throws a
/// `ValidationFailure` with `apiCode == PAYMENT_SIGNATURE_INVALID` when the
/// gateway signature does not check out (treat as failed); [retry] throws a
/// `ConflictFailure` with `PAYMENT_ALREADY_CAPTURED` (go to success) or
/// `APPOINTMENT_NOT_ACTIONABLE` (the 5 minutes are over).
abstract interface class PaymentRepository {
  /// `POST /patient/payments/orders/{id}/verify`. Safe to call again with the
  /// same [idempotencyKey]; the capture is recorded once.
  Future<PaymentVerification> verify({
    required String orderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String idempotencyKey,
  });

  /// `POST /patient/payments/orders/{id}/retry` → a **new** order. The
  /// deadline is not extended.
  Future<PaymentOrder> retry({
    required String orderId,
    required String idempotencyKey,
  });

  /// `GET /patient/payments/orders/{id}` — poll this when the app comes back
  /// from checkout without a result; the gateway notifies the backend
  /// directly, so the order can become paid without a verify call.
  Future<PaymentOrder> order(String orderId);

  /// The booking to resume paying for, reached from an appointment rather
  /// than from the booking flow ("Retry payment" on a `pending_payment`
  /// appointment, §9.4): the appointment plus its current `payment_order`.
  /// [orderId] is the fallback when the detail carries no order. Throws a
  /// `NotFoundFailure` when there is nothing to pay for.
  Future<BookingResult> booking(String appointmentId, {String? orderId});
}
