import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';

/// The payment-order endpoints (§9.3–§9.5) as a typed remote data source.
/// HTTP only; JSON out; errors propagate to the repository.
abstract interface class PaymentApi {
  /// `POST /patient/payments/orders/{id}/verify` → 200.
  Future<Map<String, Object?>> verify({
    required String orderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String idempotencyKey,
  });

  /// `POST /patient/payments/orders/{id}/retry` → 201 `PaymentOrder`.
  Future<Map<String, Object?>> retry({
    required String orderId,
    required String idempotencyKey,
  });

  /// `GET /patient/payments/orders/{id}` → `PaymentOrder`.
  Future<Map<String, Object?>> order(String orderId);

  /// `GET /patient/appointments/{id}` → the detail (§10.2), whose
  /// `payment_order` is the order to resume for "Retry payment" (§9.4).
  Future<Map<String, Object?>> appointment(String appointmentId);
}

class HttpPaymentApi implements PaymentApi {
  const HttpPaymentApi(this._client);

  final ApiClient _client;

  @override
  Future<Map<String, Object?>> verify({
    required String orderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      Endpoints.paymentOrderVerify(orderId),
      body: {
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      },
      idempotencyKey: idempotencyKey,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> retry({
    required String orderId,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      Endpoints.paymentOrderRetry(orderId),
      idempotencyKey: idempotencyKey,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> order(String orderId) async {
    final response = await _client.get(Endpoints.paymentOrder(orderId));
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> appointment(String appointmentId) async {
    final response = await _client.get(Endpoints.appointment(appointmentId));
    return response.requireMap;
  }
}
