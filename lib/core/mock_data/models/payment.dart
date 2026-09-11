import '../../utils/date_utils.dart';
import '../../utils/money.dart';

/// How the patient paid (CM-17).
enum PaymentMethod {
  upi('UPI', 'Pay by UPI app or ID'),
  card('Card', 'Credit or debit card'),
  netBanking('Net Banking', 'All major banks'),
  wallet('Wallet', 'Paytm, PhonePe, Amazon Pay'),
  payAtHospital('Pay at Hospital', 'Settle at the reception desk');

  const PaymentMethod(this.label, this.hint);

  final String label;

  /// One-line helper shown under the option.
  final String hint;

  /// True when the money moves inside the app (so a gateway is involved and a
  /// receipt is issued immediately).
  bool get isOnline => this != PaymentMethod.payAtHospital;
}

/// Where a payment got to (CM-20 … CM-22).
enum PaymentStatus {
  pending('Pending'),
  paid('Paid'),
  failed('Failed'),
  refunded('Refunded');

  const PaymentStatus(this.label);

  final String label;

  bool get isSettled => this == PaymentStatus.paid;
  bool get isRefundable => this == PaymentStatus.paid;
}

/// How far a refund has got (CM-22).
enum RefundStatus {
  requested('Refund requested'),
  processing('Refund processing'),
  completed('Refunded'),
  rejected('Refund rejected');

  const RefundStatus(this.label);

  final String label;
}

/// One payment attempt against one appointment (CM-17, CM-20 … CM-22).
///
/// Presentation view-model — immutable, no logic. Amounts are [Money], so a
/// receipt total and a refund amount can be compared and summed.
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.appointmentId,
    required this.method,
    required this.amount,
    required this.status,
    required this.receiptNumber,
    this.gstNumber,
    this.paidAt,
    this.refundAmount,
    this.refundStatus,
    this.failureReason,
  });

  final String id;
  final String appointmentId;
  final PaymentMethod method;

  /// What was charged.
  final Money amount;

  final PaymentStatus status;

  /// Human receipt number shown on the invoice ("MB-RCPT-000124") — CM-21.
  final String receiptNumber;

  /// The patient's GSTIN, when they asked for a GST invoice (CM-21).
  final String? gstNumber;

  /// When the payment settled. Null unless [status] is
  /// [PaymentStatus.paid] or [PaymentStatus.refunded].
  final DateTime? paidAt;

  /// How much was (or is being) refunded — may be partial.
  final Money? refundAmount;

  final RefundStatus? refundStatus;

  /// Gateway message for a failed payment ("Insufficient funds") — CM-20.
  final String? failureReason;

  /// "₹1,062" — the amount, formatted.
  String get amountLabel => amount.format();

  /// "₹1,062" or null.
  String? get refundAmountLabel => refundAmount?.format();

  /// "12 Aug 2026 · 10:32 AM", or null when unpaid.
  String? get paidAtLabel {
    final at = paidAt;
    return at == null ? null : '${AppDates.dayMonthYear(at)} · ${AppDates.timeLabel(at)}';
  }

  bool get hasRefund => refundAmount != null && refundStatus != null;

  /// True when the refund was for the whole amount.
  bool get isFullRefund => refundAmount != null && refundAmount == amount;

  /// True when there is a receipt to show or download (CM-21).
  bool get hasReceipt => status.isSettled || status == PaymentStatus.refunded;

  PaymentRecord copyWith({
    String? id,
    String? appointmentId,
    PaymentMethod? method,
    Money? amount,
    PaymentStatus? status,
    String? receiptNumber,
    String? gstNumber,
    DateTime? paidAt,
    Money? refundAmount,
    RefundStatus? refundStatus,
    String? failureReason,
  }) {
    return PaymentRecord(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      method: method ?? this.method,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      gstNumber: gstNumber ?? this.gstNumber,
      paidAt: paidAt ?? this.paidAt,
      refundAmount: refundAmount ?? this.refundAmount,
      refundStatus: refundStatus ?? this.refundStatus,
      failureReason: failureReason ?? this.failureReason,
    );
  }
}
