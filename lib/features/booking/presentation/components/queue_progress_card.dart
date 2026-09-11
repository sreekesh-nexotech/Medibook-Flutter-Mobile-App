import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/mock_data/models/queue_status.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_tag.dart';
import '../../domain/booking_identifiers.dart';

/// Live token progress at a doctor's desk (CM-09, CM-24).
///
/// The audit's finding: *"The patient sees only their own token. Current token
/// being served, last called number, estimated wait and a refresh indicator
/// have no place on screen."* All four are here —
///
/// * **now serving** is the headline number, because it is the one fact that
///   tells a patient whether to leave the house;
/// * **last called** sits beside it, since a desk that has called T-030 but is
///   seeing T-028 is two patients behind;
/// * the **wait** is derived for *this* patient's token when one is given
///   ([myToken]), not just the desk average;
/// * **freshness** is stated (`updatedLabel`) and a stale reading says so
///   rather than presenting old numbers as current.
///
/// Every token is rendered through [AppTokens.normalize], so a seeded `A-25`
/// and a freshly minted `T-026` cannot appear side by side in two different
/// notations (CANONICAL_MASTER_DATA §5).
class QueueProgressCard extends StatelessWidget {
  const QueueProgressCard({
    super.key,
    required this.status,
    this.myToken,
    this.onTap,
    this.compact = false,
  });

  final QueueStatus status;

  /// This patient's token, when they hold one for this desk.
  final String? myToken;

  /// Opens the full queue screen. Null → the card is display-only.
  final VoidCallback? onTap;

  /// True for the Home card: headline + wait only, no secondary grid.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mine = myToken == null ? null : AppTokens.normalize(myToken!);
    final ahead = myToken == null ? null : status.positionsAhead(myToken!);
    final wait = myToken == null ? null : status.estimatedWaitFor(myToken!);

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      status.isPaused ? 'Queue paused' : 'Now seeing',
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      AppTokens.normalize(status.currentToken),
                      style: AppText.poppins(
                        size: AppFontSize.h1,
                        weight: AppText.bold,
                        color: status.isPaused
                            ? AppColors.textInactive
                            : AppColors.accentBlue,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (mine != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: AppSpacing.x2.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: AppRadii.pill,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'You',
                        style: AppText.poppins(
                          size: AppFontSize.xxs,
                          color: AppColors.textOnBrand,
                        ),
                      ),
                      Text(
                        mine,
                        style: AppText.poppins(
                          size: AppFontSize.body,
                          weight: AppText.bold,
                          color: AppColors.textOnBrand,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.x3.h),
          Wrap(
            spacing: AppSpacing.x2.w,
            runSpacing: AppSpacing.x1.h,
            children: [
              AppTag(label: status.waitLabel),
              if (ahead != null)
                AppTag(
                  label: ahead == 0 ? "You're next" : '$ahead ahead of you',
                  active: ahead == 0,
                ),
            ],
          ),
          if (!compact) ...[
            SizedBox(height: AppSpacing.x4.h),
            Container(height: 1.h, color: AppColors.borderSubtle),
            SizedBox(height: AppSpacing.x3.h),
            _Facts(status: status, wait: wait),
          ],
          SizedBox(height: AppSpacing.x3.h),
          if (status.isStale)
            AppErrorBanner(
              message:
                  'This reading is more than 10 minutes old — '
                  '${status.updatedLabel.toLowerCase()}. Pull down to '
                  'refresh.',
              iconName: MedIcon.clock,
            )
          else
            Row(
              children: [
                ExcludeSemantics(
                  child: AppIcon(
                    MedIcon.clock,
                    size: 12,
                    color: AppColors.textMutedDecorative,
                  ),
                ),
                SizedBox(width: 5.w),
                Expanded(
                  child: Text(
                    status.updatedLabel,
                    style: AppText.poppins(
                      size: AppFontSize.xxs,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The secondary grid: last called, per-patient wait, desk pace.
class _Facts extends StatelessWidget {
  const _Facts({required this.status, required this.wait});

  final QueueStatus status;
  final Duration? wait;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value})>[
      (
        label: 'Last called',
        value: AppTokens.normalize(status.lastCalledToken),
      ),
      (
        label: 'Desk pace',
        value: status.estimatedWaitMinutes <= 0
            ? 'No estimate published'
            : '~${status.estimatedWaitMinutes} min per patient',
      ),
      if (wait != null)
        (
          label: 'Your estimated wait',
          value: wait!.inMinutes <= 0
              ? 'Any moment'
              : '~${wait!.inMinutes} min',
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 5.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    row.label,
                    style: AppText.poppins(
                      size: AppFontSize.xs,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.x3.w),
                Expanded(
                  flex: 5,
                  child: Text(
                    row.value,
                    textAlign: TextAlign.end,
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      weight: AppText.medium,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
