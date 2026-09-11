import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/appointment_receipt.dart';

/// One priced line on the receipt: label (plus its note) on the left, the
/// amount on the right.
///
/// The amount is always rendered from [Money.format] — never a hand-built
/// string — and a deduction shows its own sign and the success tone, so a
/// coupon reads as money off rather than money owed.
class ReceiptLineRow extends StatelessWidget {
  const ReceiptLineRow({super.key, required this.line});

  final ReceiptLine line;

  @override
  Widget build(BuildContext context) {
    final note = line.note;
    final amount = line.amount;
    final isCredit = line.isDeduction || amount.isNegative;
    // `Money.format` already carries the minus for a negative amount, so only
    // a positive-but-deducted line needs one added.
    final label = amount.isNegative
        ? amount.format()
        : isCredit
        ? '−${amount.format()}'
        : amount.format();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 7.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.label,
                  style: AppText.poppins(size: 13, color: AppColors.textBody),
                ),
                if (note != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    note,
                    style: AppText.poppins(
                      size: 11,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            label,
            style: AppText.poppins(
              size: 13,
              weight: AppText.medium,
              color: isCredit ? AppColors.successText : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The bold total row under the receipt's hairline.
class ReceiptTotalRow extends StatelessWidget {
  const ReceiptTotalRow({
    super.key,
    required this.label,
    required this.amount,
    this.caption,
  });

  final String label;
  final Money amount;

  /// One muted line under the label ("Settled by UPI").
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final note = caption;
    return Container(
      margin: EdgeInsets.only(top: 10.h),
      padding: EdgeInsets.only(top: 12.h),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1.w),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.poppins(
                    size: 15,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                if (note != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    note,
                    style: AppText.poppins(
                      size: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            amount.format(),
            style: AppText.poppins(
              size: 17,
              weight: AppText.bold,
              color: AppColors.textStrong,
            ),
          ),
        ],
      ),
    );
  }
}
