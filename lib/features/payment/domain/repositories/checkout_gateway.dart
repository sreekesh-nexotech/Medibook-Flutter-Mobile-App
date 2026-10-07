import '../../../booking/domain/entities/payment_order.dart';
import '../entities/checkout_outcome.dart';

/// What the app asks the gateway SDK to do (§9.2): open checkout for an
/// order and report how it ended. Abstract so the payment controller can be
/// tested with a scripted gateway and no SDK.
abstract interface class CheckoutGateway {
  /// Open the SDK with `key = order.keyId`, `order_id = order.gatewayOrderId`,
  /// `amount = order.amountPaise`, `currency = order.currency`. Completes
  /// once, with the outcome.
  ///
  /// [contactName], [contactPhone] and [contactEmail] prefill the sheet.
  Future<CheckoutOutcome> open(
    PaymentOrder order, {
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    String? description,
  });

  /// Release SDK listeners.
  void dispose();
}
