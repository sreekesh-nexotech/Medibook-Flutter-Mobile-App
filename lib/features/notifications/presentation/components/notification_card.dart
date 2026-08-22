import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/app_notification.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';

/// A single notification card: title, body, relative time, and — when the
/// notification carries actions — a two-button row (secondary + primary pill).
/// Action taps are delegated up via [onAction]; the screen maps each
/// [NotificationAction] to navigation or a toast.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onAction,
  });

  final AppNotification notification;
  final ValueChanged<NotificationAction> onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notification.title,
            style: AppText.poppins(
              size: 16,
              weight: AppText.bold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            notification.body,
            style: AppText.poppins(
              size: 13,
              weight: AppText.regular,
              color: AppColors.textBody,
              height: 1.5,
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              AppIcon(MedIcon.clock, size: 15, color: AppColors.textMuted),
              SizedBox(width: 7.w),
              Text(
                notification.ago,
                style: AppText.poppins(
                  size: 12,
                  weight: AppText.regular,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (notification.hasActions) ...[
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: notification.action1Label!,
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.sm,
                    pill: true,
                    fullWidth: true,
                    onPressed: () => onAction(notification.action1!),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: AppButton(
                    label: notification.action2Label!,
                    size: AppButtonSize.sm,
                    pill: true,
                    fullWidth: true,
                    onPressed: () => onAction(notification.action2!),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
