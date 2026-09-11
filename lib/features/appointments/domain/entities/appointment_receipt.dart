import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/mock_data/models/fee_breakdown.dart';
import '../../../../core/mock_data/models/payment.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/money.dart';
import 'appointment_token.dart';

/// One priced line on a receipt. [amount] is signed — a discount is negative —
/// so the lines sum to [AppointmentReceipt.total] with no special cases.
class ReceiptLine {
  const ReceiptLine({
    required this.label,
    required this.amount,
    this.note,
    this.isDeduction = false,
  });

  final String label;
  final Money amount;

  /// Optional second line under the label ("18% on the discounted fee").
  final String? note;

  /// True for a line that reduces the total (a coupon, a waiver).
  final bool isDeduction;
}

/// The GST receipt for one appointment (CM-21).
///
/// The audit finding was blunt: *"Appointment details carry no receipt, no GST
/// entry and no refund status row."* This is the model behind the fix.
///
/// ## Why it reconciles rather than re-computes
///
/// Two numbers exist for one appointment: the **quoted** [FeeBreakdown] (what
/// the doctor's fee, GST and convenience fee come to today) and the **charged**
/// [PaymentRecord.amount] (what the ledger actually took). A receipt that shows
/// the quote while claiming to be a record of payment is a lie the moment they
/// differ — a coupon at booking, a fee revision since, a partial settlement.
///
/// So [AppointmentReceipt.of] itemises the quote and then, if the lines do not
/// sum to what was charged, adds one explicit [ReceiptLine] for the difference.
/// The lines therefore always sum to [total], and [total] is always the amount
/// the ledger holds. Every value is [Money] (paise) — no string arithmetic.
class AppointmentReceipt {
  const AppointmentReceipt._({
    required this.appointmentId,
    required this.receiptNumber,
    required this.ledgerReference,
    required this.lines,
    required this.total,
    required this.method,
    required this.status,
    required this.doctorName,
    required this.hospitalName,
    required this.patientName,
    required this.tokenLabel,
    required this.scheduledAt,
    required this.taxPercent,
    required this.taxAmount,
    this.bookingRef,
    this.paidAt,
    this.patientGstin,
    this.refundAmount,
    this.refundStatus,
  });

  /// The GSTIN the hospital bills under, printed on every receipt
  /// (`CANONICAL_MASTER_DATA` §7 — the same number the hospital console
  /// prints, so the two documents reconcile).
  ///
  /// A constant here because this build has no billing-entity endpoint; it
  /// belongs to the hospital record and should arrive with the payment.
  static const String hospitalGstin = '27AABCM9407L1ZK';

  /// The legal name the GST invoice is raised in.
  static const String billingEntity = 'Medibook Health Services Pvt Ltd';

  final String appointmentId;

  /// The canonical financial-year receipt series, `MB/R/2026-27/000124`.
  final String receiptNumber;

  /// The payment ledger's own reference (`MB-RCPT-000124`) — kept visible so a
  /// support query can be matched against the ledger as well as the series.
  final String ledgerReference;

  /// Itemised lines, in print order. Always sums to [total].
  final List<ReceiptLine> lines;

  /// What was charged — the ledger's number, not a re-computation.
  final Money total;

  final PaymentMethod method;
  final PaymentStatus status;

  final String doctorName;
  final String hospitalName;
  final String patientName;

  /// Canonical token (`T-025`).
  final String tokenLabel;

  final DateTime scheduledAt;

  /// The GST rate applied, and the tax in rupees — shown as its own line and
  /// repeated here for the summary strip.
  final double taxPercent;
  final Money taxAmount;

  final String? bookingRef;
  final DateTime? paidAt;

  /// The patient's own GSTIN, when they asked for a GST invoice in their name.
  final String? patientGstin;

  final Money? refundAmount;
  final RefundStatus? refundStatus;

  /// True once money has actually moved. A receipt for an unsettled payment is
  /// an *estimate* and must say so — never a paid invoice.
  bool get isSettled =>
      status == PaymentStatus.paid || status == PaymentStatus.refunded;

  bool get isProvisional => !isSettled;

  bool get hasRefund => refundAmount != null && refundStatus != null;

  /// "12 Aug 2026 · 10:32 AM", or null when nothing has been paid.
  String? get paidAtLabel {
    final at = paidAt;
    return at == null
        ? null
        : '${AppDates.dayMonthYear(at)} · ${AppDates.timeLabel(at)}';
  }

  /// "GST (18%)".
  String get taxLabel => 'GST (${_percentLabel(taxPercent)}%)';

  /// Build the receipt for [appointment] from the ledger and the quote.
  static AppointmentReceipt of({
    required Appointment appointment,
    required PaymentRecord payment,
    required FeeBreakdown quoted,
    required String doctorName,
    required String hospitalName,
  }) {
    final charged = payment.amount;
    final lines = <ReceiptLine>[
      ReceiptLine(label: 'Consultation Fee', amount: quoted.consultationFee),
      if (quoted.hasDiscount)
        ReceiptLine(
          label: quoted.couponCode == null
              ? 'Coupon discount'
              : 'Coupon discount (${quoted.couponCode})',
          amount: -quoted.discount,
          isDeduction: true,
        ),
      ReceiptLine(
        label: 'GST (${_percentLabel(quoted.taxPercent)}%)',
        amount: quoted.taxAmount,
        note: 'Charged on the consultation fee after any discount',
      ),
      if (!quoted.convenienceFee.isZero)
        ReceiptLine(
          label: 'Convenience Fee',
          amount: quoted.convenienceFee,
          note: 'Booking charge — not taxed',
        ),
    ];

    // One honest line for any gap between the quote and the ledger, so the
    // itemisation always adds up to what was actually charged.
    final difference = charged - Money.total(lines.map((l) => l.amount));
    if (!difference.isZero) {
      lines.add(
        ReceiptLine(
          label: difference.isNegative
              ? 'Adjustment at billing'
              : 'Additional charge at billing',
          amount: difference,
          note: 'Difference between the quote and the amount settled',
          isDeduction: difference.isNegative,
        ),
      );
    }

    // The ledger reference ends in the running sequence
    // (`MB-RCPT-000124` → 124), which is what the series is built from.
    final sequence = AppointmentToken.sequenceOf(payment.receiptNumber) ?? 0;

    return AppointmentReceipt._(
      appointmentId: appointment.id,
      receiptNumber: ReceiptSeries.format(
        sequence,
        on: payment.paidAt ?? appointment.scheduledAt,
      ),
      ledgerReference: payment.receiptNumber,
      lines: List<ReceiptLine>.unmodifiable(lines),
      total: charged,
      method: payment.method,
      status: payment.status,
      doctorName: doctorName,
      hospitalName: hospitalName,
      patientName: appointment.patient,
      tokenLabel: AppointmentToken.normalize(appointment.token),
      scheduledAt: appointment.scheduledAt,
      taxPercent: quoted.taxPercent,
      taxAmount: quoted.taxAmount,
      bookingRef: appointment.bookingRef,
      paidAt: payment.paidAt,
      patientGstin: payment.gstNumber,
      refundAmount: payment.refundAmount,
      refundStatus: payment.refundStatus,
    );
  }

  static String _percentLabel(double percent) =>
      percent == percent.roundToDouble()
      ? percent.round().toString()
      : percent.toString();
}

/// The canonical receipt series, `MB/R/<financial year>/<6 digits>`
/// (`CANONICAL_MASTER_DATA` §7).
///
/// The core seed currently mints `MB-RCPT-000124`; that string is kept as the
/// ledger reference and this series is derived from its sequence, so both apps
/// print the same number. **Core note:** `MedibookSeed.receiptNumber` should
/// mint this shape directly once the core layer reopens.
abstract final class ReceiptSeries {
  ReceiptSeries._();

  /// Month the Indian financial year starts in (April).
  static const int financialYearStartMonth = 4;

  /// `MB/R/2026-27/000124`.
  static String format(int sequence, {DateTime? on}) {
    final at = on ?? DateTime.now();
    return 'MB/R/${financialYear(at)}/${sequence.toString().padLeft(6, '0')}';
  }

  /// `'2026-27'` for any date in that financial year.
  static String financialYear(DateTime at) {
    final startYear = at.month >= financialYearStartMonth
        ? at.year
        : at.year - 1;
    final endShort = (startYear + 1).toString().substring(2);
    return '$startYear-$endShort';
  }
}
