import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';

/// Home's "Your Token" card, as the design draws it: the title, the doctor,
/// the day and time, and the token in a navy box on the right.
///
/// Design: `Card` (16 padding) → row `gap 12`; "Your Token" `18/600`
/// text-strong, doctor `13` text-body (`mt 4`, one line), when `12` text-muted
/// (`mt 2`); token box `--radius-md`, `padding 12px 20px`, `16/700`.
///
/// The token label is shown exactly as the backend issued it — each hospital
/// sets its own format (§1.11).
class TokenCard extends StatelessWidget {
  const TokenCard({
    super.key,
    required this.token,
    required this.doctor,
    required this.when,
    this.title = 'Your Token',
    this.note,
    this.onTap,
  });

  /// The card for a booking that has not been paid yet (owner decision,
  /// BL-HOME-003). An unpaid booking is a short hold, not a place in the
  /// queue, so the card says so and offers the payment instead of presenting
  /// a token as though the visit were confirmed.
  ///
  /// [note] carries the server's amount and hold deadline ("Pay ₹524 by
  /// 1:42 PM to confirm"); the screen builds it from the appointment.
  const TokenCard.paymentPending({
    super.key,
    required this.doctor,
    required this.when,
    this.note = 'Pay to confirm this booking',
    this.onTap,
  }) : token = 'Pay now',
       title = 'Payment pending';

  /// The card's heading.
  final String title;

  /// An extra line under the time, or null.
  final String? note;

  /// What the navy box shows: the patient's token label, verbatim — or the
  /// call to action on a [TokenCard.paymentPending] card.
  final String token;

  /// "Dr. Priya Mehta".
  final String doctor;

  /// "Today · 10:30 AM".
  final String when;

  /// Opens the appointment.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppText.poppins(
                    size: AppFontSize.title,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  doctor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    color: AppColors.textBody,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  when,
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                  ),
                ),
                if (note != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    note!,
                    style: AppText.poppins(
                      size: AppFontSize.xs,
                      weight: AppText.medium,
                      color: AppColors.textStrong,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: AppRadii.md,
            ),
            child: Text(
              token.trim(),
              maxLines: 1,
              softWrap: false,
              style: AppText.poppins(
                size: AppFontSize.body,
                weight: AppText.bold,
                color: AppColors.textOnBrand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
