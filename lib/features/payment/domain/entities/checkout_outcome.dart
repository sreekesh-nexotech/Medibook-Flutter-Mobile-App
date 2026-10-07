/// How a checkout attempt in the gateway SDK ended (§9.2).
///
/// Sealed, so the payment controller's `switch` is exhaustive. The SDK
/// offers the payment methods itself; the app never lists them.
sealed class CheckoutOutcome {
  const CheckoutOutcome();
}

/// The SDK collected the money and returned what verify needs.
class CheckoutSucceeded extends CheckoutOutcome {
  const CheckoutSucceeded({
    required this.paymentId,
    required this.signature,
    this.orderId,
  });

  /// `razorpay_payment_id`.
  final String paymentId;

  /// `razorpay_signature`.
  final String signature;
  final String? orderId;
}

/// The SDK reported a failure, or the patient dismissed it.
class CheckoutFailed extends CheckoutOutcome {
  const CheckoutFailed({
    required this.message,
    this.code,
    this.cancelled = false,
  });

  /// The gateway's message, worded for the patient where possible.
  final String message;

  /// The gateway's numeric/enum code, for logs.
  final int? code;

  /// True when the patient closed the sheet without paying — nothing was
  /// attempted, so the copy must not say "declined".
  final bool cancelled;
}

/// The SDK handed off to an external wallet app; the result arrives through
/// the backend's webhook, not the SDK — poll the order.
class CheckoutExternalWallet extends CheckoutOutcome {
  const CheckoutExternalWallet({this.walletName});

  final String? walletName;
}
