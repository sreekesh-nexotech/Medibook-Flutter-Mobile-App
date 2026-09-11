import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/payment.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_radio.dart';
import '../../../../core/widgets/app_tag.dart';

/// One selectable payment method (CM-17, CM-18).
///
/// The audit found *"no method choice"* at all, and separately that Pay at
/// Hospital *"is not presented as a choice"*. Both are the same row type here,
/// so the counter option is a peer of the online ones rather than a footnote —
/// it carries a "Pay later" tag and, when selected, the counter-confirmation
/// window the caller passes as [note].
///
/// The whole row is the tap target (a 20px radio dot is not one), and the row
/// is a single semantics node announcing label, hint and selected state.
class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile({
    super.key,
    required this.method,
    required this.selected,
    required this.onSelected,
    this.note,
    this.enabled = true,
  });

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onSelected;

  /// Extra copy shown under the hint while this method is [selected] — used
  /// for the Pay-at-Hospital counter-confirmation window (CM-18).
  final String? note;

  /// False while an attempt is in flight: the method must not change under a
  /// gateway call.
  final bool enabled;

  String get _iconName => switch (method) {
    PaymentMethod.upi => MedIcon.bag,
    PaymentMethod.card => MedIcon.records,
    PaymentMethod.netBanking => MedIcon.hospital,
    PaymentMethod.wallet => MedIcon.bag,
    PaymentMethod.payAtHospital => MedIcon.location,
  };

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return Semantics(
      button: true,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      selected: selected,
      label: method.label,
      hint: method.hint,
      child: ExcludeSemantics(
        child: AppCard(
          onTap: enabled ? onSelected : null,
          padding: EdgeInsets.all(14.w),
          border: Border.all(
            color: selected ? AppColors.brand : Colors.transparent,
            width: 1.5.w,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38.w,
                    height: 38.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint,
                      borderRadius: BorderRadius.circular(AppRadius.sm.r),
                    ),
                    child: AppIcon(_iconName, size: 18, color: AppColors.brand),
                  ),
                  SizedBox(width: AppSpacing.x3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                method.label,
                                style: AppText.poppins(
                                  size: AppFontSize.base,
                                  weight: AppText.semibold,
                                  color: enabled
                                      ? AppColors.textStrong
                                      : AppColors.textInactive,
                                ),
                              ),
                            ),
                            if (!method.isOnline) ...[
                              SizedBox(width: AppSpacing.x2.w),
                              const AppTag(label: 'Pay later'),
                            ],
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          method.hint,
                          style: AppText.poppins(
                            size: AppFontSize.xs,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.x2.w),
                  AppRadio(
                    selected: selected,
                    onChanged: enabled ? (_) => onSelected() : null,
                  ),
                ],
              ),
              if (selected && note != null) ...[
                SizedBox(height: AppSpacing.x3.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppSpacing.x3.w),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(AppRadius.sm.r),
                  ),
                  child: Text(
                    note,
                    style: AppText.poppins(
                      size: AppFontSize.xs,
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
