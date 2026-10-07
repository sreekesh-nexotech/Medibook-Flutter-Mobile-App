/// The `Payment` object (§10.11): one captured / failed / refunded attempt.
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.orderId,
    required this.appointmentId,
    required this.amountPaise,
    required this.status,
    this.method,
    this.gateway,
    this.capturedAt,
    this.failureCode,
    this.failureReason,
    this.createdAt,
  });

  final String id;
  final String orderId;
  final String appointmentId;
  final int amountPaise;

  /// `upi` | `card` | `netbanking` | `wallet` | `emi` | `paylater` | …
  final String? method;
  final String? gateway;

  /// `captured` | `failed` | `refunded`.
  final String status;
  final DateTime? capturedAt;
  final String? failureCode;
  final String? failureReason;
  final DateTime? createdAt;

  bool get isCaptured => status == 'captured';

  /// "UPI" / "Card" — the method with a capital, for a receipt row.
  String? get methodLabel {
    final m = method;
    if (m == null || m.isEmpty) return null;
    return switch (m) {
      'upi' => 'UPI',
      'emi' => 'EMI',
      'netbanking' => 'Net banking',
      'paylater' => 'Pay later',
      'pos' => 'POS',
      _ => '${m[0].toUpperCase()}${m.substring(1)}',
    };
  }
}
