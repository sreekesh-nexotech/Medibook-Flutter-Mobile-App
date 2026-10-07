import '../../../../core/utils/money.dart';
import 'token_card.dart';

/// One priced line on a receipt (§10.8). [amount] is signed — a discount is
/// negative — so the lines sum to the subtotal with no special cases.
class ReceiptLine {
  const ReceiptLine({
    required this.supplier,
    required this.line,
    required this.description,
    required this.qty,
    required this.unit,
    required this.amount,
    required this.rateBp,
    required this.tax,
    this.taxCode,
    this.taxInclusive = false,
    this.appointmentId,
    this.bookingRef,
  });

  /// `hospital | platform`.
  final String supplier;

  /// `consultation | service | discount | convenience_fee`.
  final String line;
  final String description;
  final int qty;
  final Money unit;
  final Money amount;
  final String? taxCode;
  final int rateBp;
  final Money tax;
  final bool taxInclusive;
  final String? appointmentId;
  final String? bookingRef;

  bool get isDeduction => amount.isNegative;
}

/// How the receipt was settled (§10.8 `payment_lines`).
class PaymentLine {
  const PaymentLine({
    required this.method,
    required this.amount,
    this.reference,
  });

  final String method;
  final Money amount;
  final String? reference;
}

/// The hospital as it was at issue time — the GST identity on the receipt.
class ReceiptHospital {
  const ReceiptHospital({
    required this.id,
    required this.name,
    required this.address,
    this.legalName,
    this.gstin,
    this.logoFileId,
    this.stampFileId,
  });

  final String id;
  final String name;
  final String? legalName;
  final String? gstin;
  final AddressSnapshot address;
  final String? logoFileId;
  final String? stampFileId;
}

/// Medibook, the seller for online bookings.
class ReceiptPlatform {
  const ReceiptPlatform({required this.address, this.legalName, this.gstin});

  final String? legalName;
  final String? gstin;
  final AddressSnapshot address;
}

/// `GET /patient/appointments/{id}/receipt` (§10.8). Issued by the backend
/// once the booking is paid; the app renders it and never reconstructs it.
class Receipt {
  const Receipt({
    required this.id,
    required this.receiptNo,
    required this.issuedAt,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.lines,
    required this.paymentLines,
    required this.hospital,
    required this.pdfAvailable,
    this.fyCode,
    this.issuedByName,
    this.counterCode,
    this.platform,
  });

  final String id;

  /// Show this.
  final String receiptNo;
  final String? fyCode;
  final DateTime issuedAt;

  /// Staff name on desk receipts.
  final String? issuedByName;
  final String? counterCode;
  final Money subtotal;
  final Money tax;
  final Money total;
  final List<ReceiptLine> lines;
  final List<PaymentLine> paymentLines;
  final ReceiptHospital hospital;
  final ReceiptPlatform? platform;
  final bool pdfAvailable;
}

/// `GET /patient/appointments/{id}/receipt.pdf` (§10.9) — a signed URL,
/// valid for ten minutes.
class ReceiptPdfLink {
  const ReceiptPdfLink({required this.url, this.receiptNo});

  final String url;
  final String? receiptNo;
}
