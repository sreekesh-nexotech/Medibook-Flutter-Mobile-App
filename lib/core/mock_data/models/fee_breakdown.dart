import '../../utils/money.dart';

/// The itemised cost of a booking (CM-13, CM-19).
///
/// This is the model the audit's money finding (§3.8.2) was really about: with
/// fees stored as the string `'₹900'`, a breakdown like this could not be
/// computed at all. Every line is a [Money], so the total is arithmetic rather
/// than a hand-written string, and the total is guaranteed to equal the sum of
/// its parts — [build] is the only way to make one.
///
/// Presentation view-model — immutable, no logic beyond the derived total.
class FeeBreakdown {
  const FeeBreakdown._({
    required this.consultationFee,
    required this.taxPercent,
    required this.taxAmount,
    required this.convenienceFee,
    required this.discount,
    required this.total,
    this.couponCode,
  });

  /// Compute a breakdown. The only constructor, so no caller can invent a
  /// total that does not match its lines.
  ///
  /// Order of operations, which matters for the numbers on screen:
  /// 1. discount applies to the consultation fee,
  /// 2. tax applies to the discounted fee,
  /// 3. the convenience fee is added last and is not taxed.
  factory FeeBreakdown.build({
    required Money consultationFee,
    double taxPercent = 18,
    Money convenienceFee = const Money.paise(2500),
    Money discount = Money.zero,
    String? couponCode,
  }) {
    final cappedDiscount = discount > consultationFee
        ? consultationFee
        : discount;
    final taxable = consultationFee.minusFloored(cappedDiscount);
    final tax = taxable.percent(taxPercent);
    final total = taxable + tax + convenienceFee;

    return FeeBreakdown._(
      consultationFee: consultationFee,
      taxPercent: taxPercent,
      taxAmount: tax,
      convenienceFee: convenienceFee,
      discount: cappedDiscount,
      total: total,
      couponCode: cappedDiscount.isZero ? null : couponCode,
    );
  }

  /// A zero breakdown — the safe initial value for a payment controller.
  static final FeeBreakdown empty = FeeBreakdown.build(
    consultationFee: Money.zero,
    convenienceFee: Money.zero,
  );

  /// The doctor's consultation fee, before anything else.
  final Money consultationFee;

  /// GST rate applied to the discounted fee.
  final double taxPercent;

  /// The tax in rupees — derived, never typed in.
  final Money taxAmount;

  /// Platform/booking charge. Not taxed.
  final Money convenienceFee;

  /// The coupon that produced [discount], or null when none applied.
  final String? couponCode;

  /// Amount taken off the consultation fee.
  final Money discount;

  /// What the patient pays. Equals
  /// `consultationFee - discount + taxAmount + convenienceFee`.
  final Money total;

  bool get hasDiscount => !discount.isZero;

  /// "GST (18%)" — the tax row's label.
  String get taxLabel =>
      'GST (${taxPercent == taxPercent.roundToDouble() ? taxPercent.round() : taxPercent}%)';

  /// The rows a summary table renders, in order. Signed: [discount] is shown
  /// as a negative line.
  List<({String label, Money amount, bool isDiscount})> get lines => [
    (label: 'Consultation Fee', amount: consultationFee, isDiscount: false),
    if (hasDiscount)
      (
        label: couponCode == null ? 'Discount' : 'Discount ($couponCode)',
        amount: -discount,
        isDiscount: true,
      ),
    (label: taxLabel, amount: taxAmount, isDiscount: false),
    if (!convenienceFee.isZero)
      (label: 'Convenience Fee', amount: convenienceFee, isDiscount: false),
  ];

  /// Re-apply a coupon to the same fee. Returns a fresh, consistent breakdown.
  FeeBreakdown withCoupon({required String code, required Money discount}) =>
      FeeBreakdown.build(
        consultationFee: consultationFee,
        taxPercent: taxPercent,
        convenienceFee: convenienceFee,
        discount: discount,
        couponCode: code,
      );

  /// Drop the coupon.
  FeeBreakdown withoutCoupon() => FeeBreakdown.build(
    consultationFee: consultationFee,
    taxPercent: taxPercent,
    convenienceFee: convenienceFee,
  );
}

/// The demo coupons the payment screen accepts (CM-19).
///
/// Percentage-based so the discount is computed, not hardcoded — which is the
/// whole point of storing money as numbers.
abstract final class DemoCoupons {
  DemoCoupons._();

  /// Code → percentage off the consultation fee.
  static const Map<String, double> percentOff = {
    'MEDI10': 10,
    'FIRSTVISIT': 20,
    'HEALTH50': 50,
  };

  /// The discount [code] would give on [fee], or null when the code is unknown.
  static Money? discountFor(String code, Money fee) {
    final percent = percentOff[code.trim().toUpperCase()];
    if (percent == null) return null;
    return fee.percent(percent);
  }
}
