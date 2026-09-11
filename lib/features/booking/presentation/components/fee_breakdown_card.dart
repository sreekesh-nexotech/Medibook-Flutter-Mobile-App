import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/fee_breakdown.dart';
import '../../../../core/widgets/app_card.dart';

/// The itemised cost of a booking (CM-13, CM-19), used by the booking summary
/// and the payment order summary.
///
/// The audit's complaint: *"the summary shows a single consultation fee. Taxes,
/// convenience fee, coupon entry and a total have no row."* Every line here
/// comes from [FeeBreakdown.lines], which is computed from [Money] integers —
/// so the total on screen is arithmetic over the rows above it and cannot
/// drift from them (audit §3.8.2). This widget never does sums; it renders the
/// ones the model guarantees.
///
/// A discount row renders negative and in success green, because a number that
/// reduces the total should not look like one that raises it.
class FeeBreakdownCard extends StatelessWidget {
  const FeeBreakdownCard({
    super.key,
    required this.fee,
    this.title,
    this.footnote,
    this.shadow = AppShadowToken.sm,
  });

  final FeeBreakdown fee;

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
          for (final line in fee.lines)
            _FeeRow(
              label: line.label,
              value: line.amount.format(),
              valueColor: line.isDiscount
                  ? AppColors.successText
                  : AppColors.textPrimary,
            ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.x3.h),
            child: Container(height: 1.h, color: AppColors.borderSubtle),
          ),
          _FeeRow(
            label: 'Total Payable',
            value: fee.total.format(),
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
    this.labelColor = AppColors.textMuted,
    this.labelWeight = AppText.regular,
    this.valueColor = AppColors.textPrimary,
    this.valueWeight = AppText.medium,
    this.valueSize = AppFontSize.base,
  });

  final String label;
  final String value;
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
            child: Text(
              label,
              style: AppText.poppins(
                size: AppFontSize.base,
                weight: labelWeight,
                color: labelColor,
              ),
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
