import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/status_style.dart';
import '../../domain/entities/insurance_policy.dart';
import 'policy_labels.dart';

/// The status pill colours for an insurance policy — the same three-tone
/// language as the appointment pills: green in force, red gone, amber
/// "needs attention".
abstract final class InsuranceStatusStyle {
  InsuranceStatusStyle._();

  static PillColors of(InsurancePolicy policy) => switch (policy.status) {
    PolicyStatus.expired => (
      background: AppColors.dangerSoft,
      foreground: AppColors.dangerText,
    ),
    PolicyStatus.expiringSoon || PolicyStatus.notYetActive => (
      background: AppColors.warningSoft,
      foreground: AppColors.textPrimary,
    ),
    PolicyStatus.active => (
      background: AppColors.successSoft,
      foreground: AppColors.successText,
    ),
  };
}

/// One policy in the insurance locker (CM-37).
///
/// An expired policy must *look* expired: the pill's wording, a red left
/// edge, and the sum insured muted with "no longer covers you" spelled out.
/// None of it is colour-only.
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
          '${policy.providerName}, ${policy.planLabel}, '
          '${policy.sumInsuredLabel} cover, ${policy.statusLabel}',
      child: ExcludeSemantics(
        child: AppCard(
          padding: EdgeInsets.zero,
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                                    policy.providerName,
                                    style: AppText.poppins(
                                      size: AppFontSize.base,
                                      weight: AppText.bold,
                                      color: AppColors.textStrong,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    policy.planLabel,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isExpired ? 'Cover when active' : 'Sum insured',
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
                                color: isExpired
                                    ? AppColors.textMuted
                                    : AppColors.textStrong,
                              ),
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
