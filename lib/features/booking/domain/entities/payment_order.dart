/// Payment order `status` (§17).
enum PaymentOrderStatus {
  created('created'),
  attempted('attempted'),
  paid('paid'),
  failed('failed'),
  expired('expired'),
  cancelled('cancelled');

  const PaymentOrderStatus(this.wire);

  final String wire;

  static PaymentOrderStatus fromWire(String? value) => values.firstWhere(
    (v) => v.wire == value,
    orElse: () => PaymentOrderStatus.created,
  );

  bool get isPaid => this == PaymentOrderStatus.paid;

  /// True when this order can no longer be paid and a retry mints a new one.
  bool get isTerminal => this == failed || this == expired || this == cancelled;
}

/// The `PaymentOrder` a booking returns (§9.1) and a retry replaces (§9.4).
///
/// The four checkout inputs are [keyId], [gatewayOrderId], [amountPaise] and
/// [currency] — the amount to pay comes from here, never from a fee quote.
class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.appointmentId,
    required this.amountPaise,
    required this.currency,
    required this.gatewayOrderId,
    required this.keyId,
    required this.status,
    this.channel = 'online',
    this.gateway = 'razorpay',
    this.attempts = 1,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String appointmentId;
  final int amountPaise;
  final String currency;
  final String channel;
  final String gateway;

  /// → Razorpay checkout `order_id`.
  final String gatewayOrderId;

  /// → Razorpay checkout `key`.
  final String keyId;
  final PaymentOrderStatus status;
  final int attempts;

  /// Equals the appointment's `booking_deadline_at`.
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool get isPaid => status.isPaid;
}
