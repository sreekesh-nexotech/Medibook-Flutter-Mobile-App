import '../../../../core/utils/money.dart';

/// `Payment.status` (§17).
enum PaymentStatus {
  captured('captured'),
  failed('failed'),
  refunded('refunded');

  const PaymentStatus(this.wire);

  final String wire;

  static PaymentStatus? fromWire(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}

/// `Refund.status` (§17).
enum RefundStatus {
  requested('requested'),
  processing('processing'),
  processed('processed'),
  failed('failed');

  const RefundStatus(this.wire);

  final String wire;

  static RefundStatus? fromWire(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}

/// One captured (or failed / refunded) payment (§10.11).
class Payment {
  const Payment({
    required this.id,
    required this.orderId,
    required this.appointmentId,
    required this.amount,
    required this.method,
    required this.status,
    this.gateway,
    this.capturedAt,
    this.failureCode,
    this.failureReason,
    this.createdAt,
  });

  final String id;
  final String orderId;
  final String appointmentId;
  final Money amount;

  /// `upi | card | netbanking | wallet | emi | paylater | cash | pos | other`.
  final String method;

  /// Null for desk payments.
  final String? gateway;
  final PaymentStatus status;
  final DateTime? capturedAt;
  final String? failureCode;
  final String? failureReason;
  final DateTime? createdAt;
}

/// A refund raised against a payment (§10.11).
class Refund {
  const Refund({
    required this.id,
    required this.paymentId,
    required this.appointmentId,
    required this.amount,
    required this.status,
    this.reason,
    this.requestedAt,
    this.processedAt,
  });

  final String id;
  final String paymentId;
  final String appointmentId;
  final Money amount;

  /// `patient_cancellation | hospital_cancellation | …` — opaque text.
  final String? reason;
  final RefundStatus status;
  final DateTime? requestedAt;
  final DateTime? processedAt;
}
