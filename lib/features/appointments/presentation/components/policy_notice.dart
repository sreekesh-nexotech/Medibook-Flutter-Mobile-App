import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../domain/policies/cancellation_policy.dart';

/// The cancel / reschedule policy panel (CM-25, CM-26).
///
/// The audit finding was that *"both actions work, but no cut-off, no policy
/// window and no refund consequence is ever shown to the patient"*. This is the
/// surface that answers all three **before** the patient commits:
///
/// * which window they are in ([PolicyOutcome.windowLabel]);
/// * when the cut-off is, and how far away it is;
/// * exactly what it means for their money ([PolicyOutcome.consequence]).
///
/// Tone follows the verdict: free window → neutral tint, inside the cut-off →
/// warning, blocked → danger. Nothing here is a typed-in number; every value
/// comes off the [PolicyOutcome].
class PolicyNotice extends StatelessWidget {
  const PolicyNotice({super.key, required this.outcome, this.margin});

  final PolicyOutcome outcome;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final blocked = outcome.blockedReason;
    final (
      Color background,
      Color accent,
      Color border,
    ) = switch (outcome.window) {
      PolicyWindow.beforeCutoff => (
        AppColors.surfaceTint,
        AppColors.brand,
        AppColors.primary200,
      ),
      PolicyWindow.insideCutoff => (
        AppColors.warningSoft,
        AppColors.grey600,
        AppColors.warning,
      ),
      PolicyWindow.slotStarted || PolicyWindow.closed => (
        AppColors.dangerSoft,
        AppColors.dangerText,
        AppColors.danger,
      ),
    };

    return Container(
      margin: margin ?? EdgeInsets.only(top: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.md,
        border: Border.all(color: border, width: 1.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(MedIcon.clock, size: 18, color: accent),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  '${outcome.change.label} policy · ${outcome.windowLabel}',
                  style: AppText.poppins(
                    size: 13,
                    weight: AppText.semibold,
                    color: accent,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _line(
            'Cut-off',
            '${outcome.cutoffLabel} (${outcome.timeToCutoffLabel()})',
          ),
          SizedBox(height: 4.h),
          _line('Refund', outcome.tier.label),
          SizedBox(height: 8.h),
          Text(
            blocked ?? outcome.consequence,
            style: AppText.poppins(
              size: 12,
              color: AppColors.textBody,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.poppins(size: 12, color: AppColors.textMuted),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppText.poppins(
              size: 12,
              weight: AppText.medium,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
