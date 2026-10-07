/// One ready-to-render row of a fee quote (§8.3 `lines[]`). Amounts are
/// integer paise; a discount arrives negative.
class FeeLine {
  const FeeLine({
    required this.line,
    required this.description,
    required this.supplier,
    required this.amountPaise,
    required this.taxRateBp,
    required this.taxPaise,
    required this.taxInclusive,
    this.taxCode,
  });

  /// `consultation` | `convenience_fee` | `discount` | `service` …
  final String line;
  final String description;

  /// `hospital` | `platform`.
  final String supplier;
  final int amountPaise;
  final String? taxCode;
  final int taxRateBp;
  final int taxPaise;
  final bool taxInclusive;

  bool get isDiscount => amountPaise < 0;

  /// "GST 18%" when a tax applies on top, else null.
  String? get taxLabel =>
      taxPaise == 0 ? null : 'GST ${(taxRateBp / 100).toStringAsFixed(0)}%';
}

/// The coupon verdict inside a quote. A bad coupon does **not** fail the
/// quote; it comes back with [valid] false and [reason].
class CouponResult {
  const CouponResult({required this.code, required this.valid, this.reason});

  final String code;
  final bool valid;

  /// `COUPON_INVALID` | `COUPON_EXPIRED` | `COUPON_MIN_ORDER` |
  /// `COUPON_USAGE_CAP`, or null when valid.
  final String? reason;
}

/// `GET /patient/fee-quotes` (§8.3). Rendered as-is — the app never computes
/// a fee. The booking re-prices on the slot date, so the amount to pay comes
/// from the booking response, not from here.
class FeeQuote {
  const FeeQuote({
    required this.doctorId,
    required this.hospitalId,
    required this.consultationFeePaise,
    required this.serviceFeePaise,
    required this.discountPaise,
    required this.convenienceFeePaise,
    required this.taxPaise,
    required this.totalPaise,
    required this.isFollowUp,
    required this.currency,
    required this.lines,
    required this.quotedForDate,
    this.personId,
    this.coupon,
    this.regularConsultationFeePaise,
    this.followUpFeePaise,
  });

  final String doctorId;
  final String hospitalId;
  final String? personId;
  final int consultationFeePaise;
  final int serviceFeePaise;
  final int discountPaise;
  final int convenienceFeePaise;
  final int taxPaise;
  final int totalPaise;
  final bool isFollowUp;
  final String currency;
  final CouponResult? coupon;
  final int? regularConsultationFeePaise;
  final int? followUpFeePaise;
  final List<FeeLine> lines;
  final String quotedForDate;

  bool get hasValidCoupon => coupon?.valid == true;

  /// The rejection reason when a coupon was sent and refused, else null.
  String? get couponError => coupon?.valid == false ? coupon?.reason : null;

  bool get hasDiscount => discountPaise > 0;
}
