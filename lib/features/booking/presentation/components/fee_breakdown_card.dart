import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/booked_appointment.dart';
import '../../domain/entities/fee_quote.dart';

/// One row of a fee card: a label and an amount in paise. A discount is a
/// negative amount and renders in success green.
class FeeRowData {
  const FeeRowData({required this.label, required this.amountPaise, this.note});

  final String label;
  final int amountPaise;

  /// A quiet line under the label ("GST 18% · ₹4").
  final String? note;

  bool get isDiscount => amountPaise < 0;

  /// The ready-to-render rows of a fee quote (§8.3 `lines[]`) — rendered as
  /// the backend priced them, never recomputed.
  static List<FeeRowData> fromQuote(FeeQuote quote) => [
    for (final line in quote.lines)
      FeeRowData(
        label: line.description,
        amountPaise: line.amountPaise,
        note: line.taxPaise == 0
            ? null
            : '${line.taxLabel} · ${Money.inr(line.taxPaise)}'
                  '${line.taxInclusive ? ' included' : ' added'}',
      ),
    if (quote.taxPaise > 0)
      FeeRowData(label: 'Taxes', amountPaise: quote.taxPaise),
  ];

  /// The fee snapshot on a booked appointment (§10) — the final figures.
  static List<FeeRowData> fromAppointment(BookedAppointment a) => [
    FeeRowData(label: 'Consultation', amountPaise: a.consultationFeePaise),
    if (a.serviceFeePaise > 0)
      FeeRowData(label: 'Service', amountPaise: a.serviceFeePaise),
    if (a.discountPaise > 0)
      FeeRowData(label: 'Discount', amountPaise: -a.discountPaise),
    if (a.convenienceFeePaise > 0)
      FeeRowData(label: 'Convenience fee', amountPaise: a.convenienceFeePaise),
    if (a.taxPaise > 0) FeeRowData(label: 'Taxes', amountPaise: a.taxPaise),
  ];
}

/// The itemised cost of a booking (CM-13, CM-19), used by the booking
/// summary and the payment order summary.
///
/// Every row comes from the backend — a fee quote's `lines[]` or the
/// appointment's fee snapshot. This widget never does sums (§8.3: "do not
/// compute fees in the app"); [totalPaise] is the backend's figure.
class FeeBreakdownCard extends StatelessWidget {
  const FeeBreakdownCard({
    super.key,
    required this.rows,
    required this.totalPaise,
    this.title,
    this.footnote,
    this.shadow = AppShadowToken.sm,
  });

  final List<FeeRowData> rows;
  final int totalPaise;

  /// Optional heading above the rows ("Payment summary").
  final String? title;

  /// Optional quiet line under the total ("Inclusive of all taxes").
  final String? footnote;

  /// Lowered to [AppShadowToken.none] when the card sits inside another card.
  final AppShadowToken shadow;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      shadow: shadow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: AppText.poppins(
                size: AppFontSize.base,
                weight: AppText.semibold,
                color: AppColors.textStrong,
              ),
            ),
            SizedBox(height: AppSpacing.x3.h),
          ],
          for (final row in rows)
            _FeeRow(
              label: row.label,
              note: row.note,
              value: row.isDiscount
                  ? '− ${Money.inr(-row.amountPaise)}'
                  : Money.inr(row.amountPaise),
              valueColor: row.isDiscount
                  ? AppColors.successText
                  : AppColors.textPrimary,
            ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.x3.h),
            child: Container(height: 1.h, color: AppColors.borderSubtle),
          ),
          _FeeRow(
            label: 'Total Payable',
            value: Money.inr(totalPaise),
            labelColor: AppColors.textStrong,
            labelWeight: AppText.semibold,
            valueColor: AppColors.textStrong,
            valueWeight: AppText.bold,
            valueSize: AppFontSize.body,
          ),
          if (footnote != null) ...[
            SizedBox(height: AppSpacing.x2.h),
            Text(
              footnote!,
              style: AppText.poppins(
                size: AppFontSize.xs,
                height: 1.45,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One label/amount row. Label and value both wrap rather than clip, so the
/// rows survive OS text scaling to 1.3x.
class _FeeRow extends StatelessWidget {
  const _FeeRow({
    required this.label,
    required this.value,
    this.note,
    this.labelColor = AppColors.textMuted,
    this.labelWeight = AppText.regular,
    this.valueColor = AppColors.textPrimary,
    this.valueWeight = AppText.medium,
    this.valueSize = AppFontSize.base,
  });

  final String label;
  final String value;
  final String? note;
  final Color labelColor;
  final FontWeight labelWeight;
  final Color valueColor;
  final FontWeight valueWeight;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: labelWeight,
                    color: labelColor,
                  ),
                ),
                if (note != null)
                  Text(
                    note!,
                    style: AppText.poppins(
                      size: AppFontSize.xxs,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.x3.w),
          Text(
            value,
            textAlign: TextAlign.end,
            style: AppText.poppins(
              size: valueSize,
              weight: valueWeight,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
