import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/insurance_policy.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/status_style.dart';

/// The status pill colours for an insurance policy.
///
/// Deliberately the same three-tone language as `AppStatusStyle.appointment`
/// — green for in force, red for gone, amber for "needs attention" — so a
/// user who has learned what a green pill means on the appointments list does
/// not have to learn it again here.
///
/// There is no `AppColors.warningText` token, so the expiring pill puts the
/// strong ink on `warningSoft`; that pairing measures well above 4.5:1, where
/// `AppColors.warning` on `warningSoft` would not.
abstract final class InsuranceStatusStyle {
  InsuranceStatusStyle._();

  static PillColors of(InsurancePolicy policy) {
    if (policy.isExpired) {
      return (
        background: AppColors.dangerSoft,
        foreground: AppColors.dangerText,
      );
    }
    if (policy.isExpiringSoon) {
      return (
        background: AppColors.warningSoft,
        foreground: AppColors.textPrimary,
      );
    }
    return (
      background: AppColors.successSoft,
      foreground: AppColors.successText,
    );
  }
}

/// One policy in the insurance locker (CM-37).
///
/// ## Making an expired policy look expired
///
/// The audit's requirement is that an expired policy must *look* expired,
/// because a patient who thinks they have cover and does not is the worst
/// outcome this screen can produce. Three things carry it, so no single one is
/// load-bearing: the status pill's wording (`policy.statusLabel` — "Expired",
/// "Expires in 12 days", "Active"), a red left edge, and the sum insured shown
/// in muted rather than strong ink with "no longer covered" spelled out. None
/// of it is colour-only.
class InsurancePolicyCard extends StatelessWidget {
  const InsurancePolicyCard({
    super.key,
    required this.policy,
    required this.onTap,
  });

  final InsurancePolicy policy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isExpired = policy.isExpired;

    return Semantics(
      button: true,
      label:
          '${policy.provider}, ${policy.planName}, '
          '${policy.sumInsuredLabel} cover, ${policy.statusLabel}',
      child: ExcludeSemantics(
        child: AppCard(
          padding: EdgeInsets.zero,
          onTap: onTap,
          // IntrinsicHeight, because the status edge below stretches to the
          // card's height and a stretched Row inside a ListView has no height
          // to stretch to — without this the screen dies on
          // "BoxConstraints forces an infinite height" rather than rendering.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The status edge. 4px of colour is not the only signal — see
                // the class doc — but it is the one visible while scrolling.
                Container(
                  width: 4.w,
                  decoration: BoxDecoration(
                    color: isExpired
                        ? AppColors.danger
                        : policy.isExpiringSoon
                        ? AppColors.warning
                        : AppColors.success,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(AppRadius.lg.r),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.x4.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                    policy.provider,
                                    style: AppText.poppins(
                                      size: AppFontSize.base,
                                      weight: AppText.bold,
                                      color: AppColors.textStrong,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    policy.planName,
                                    style: AppText.poppins(
                                      size: AppFontSize.xs,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: AppSpacing.x2.w),
                            AppStatusPill(
                              label: policy.statusLabel,
                              colors: InsuranceStatusStyle.of(policy),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.x3.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isExpired
                                        ? 'Cover when active'
                                        : 'Sum insured',
                                    style: AppText.poppins(
                                      size: AppFontSize.xxs,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    policy.sumInsuredLabel,
                                    style: AppText.inter(
                                      size: AppFontSize.title,
                                      weight: AppText.bold,
                                      // Muted when there is no cover, so the
                                      // big number cannot be mistaken for money
                                      // that is actually available.
                                      color: isExpired
                                          ? AppColors.textMuted
                                          : AppColors.textStrong,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (policy.hasDocuments)
                              Row(
                                children: [
                                  AppIcon(
                                    MedIcon.records,
                                    size: 14,
                                    color: AppColors.textMuted,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    policy.documents.length == 1
                                        ? '1 file'
                                        : '${policy.documents.length} files',
                                    style: AppText.poppins(
                                      size: AppFontSize.xxs,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.x3.h),
                        Text(
                          isExpired
                              ? 'Expired ${policy.validityLabel.split(' – ').last}'
                                    ' — this policy no longer covers you'
                              : policy.validityLabel,
                          style: AppText.poppins(
                            size: AppFontSize.xs,
                            height: 1.4,
                            color: isExpired
                                ? AppColors.dangerText
                                : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
