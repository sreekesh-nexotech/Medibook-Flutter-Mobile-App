import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_icon.dart';

/// A read-only, tappable date field for the policy validity window.
///
/// Mirrors `AppTextField`'s anatomy — label, `surfaceAlt` box, error line,
/// helper line — so the add form reads as one control set, and carries no
/// fixed height, so it grows rather than clipping at 1.3x text scale. It is a
/// labelled `Semantics` button, so a screen reader announces the field, the
/// date currently chosen and that tapping opens a calendar.
class InsuranceDateField extends StatelessWidget {
  const InsuranceDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = 'Select a date',
    this.errorText,
    this.helperText,
  });

  final String label;

  /// The formatted date, or null when nothing is chosen yet.
  final String? value;

  final VoidCallback onTap;
  final String placeholder;
  final String? errorText;

  /// A quiet line under the field, shown when there is no [errorText].
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final hasValue = value != null && value!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppText.poppins(
            size: AppFontSize.base,
            weight: AppText.medium,
            color: AppColors.textStrong,
          ),
        ),
        SizedBox(height: AppSpacing.x2.h),
        Semantics(
          button: true,
          label: '$label: ${hasValue ? value! : 'not set'}',
          hint: 'Opens a calendar',
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                constraints: BoxConstraints(minHeight: 52.h),
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4.w,
                  vertical: AppSpacing.x3.h,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: AppRadii.md,
                  border: Border.all(
                    color: hasError ? AppColors.danger : AppColors.border,
                    width: 1.w,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasValue ? value! : placeholder,
                        style: AppText.poppins(
                          size: AppFontSize.body,
                          color: hasValue
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.x3.w),
                    AppIcon(
                      MedIcon.calendar,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              errorText!,
              style: AppText.poppins(
                size: AppFontSize.xs,
                color: AppColors.danger,
              ),
            ),
          )
        else if (helperText != null)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              helperText!,
              style: AppText.poppins(
                size: AppFontSize.xs,
                color: AppColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

/// A label/value line on the policy detail screen.
///
/// The value is [SelectableText] where it is the kind of thing that gets read
/// down a phone line or typed into a hospital's system — a policy number, a
/// TPA name — so it can be copied instead of transcribed by eye.
class InsuranceDetailRow extends StatelessWidget {
  const InsuranceDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.isSelectable = false,
    this.isMono = false,
    this.showDivider = true,
  });

  final String label;
  final String value;

  /// Lets the value be selected and copied.
  final bool isSelectable;

  /// Renders the value in Inter rather than Poppins — for numbers, where
  /// even-width digits are easier to read back.
  final bool isMono;

  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final style = isMono
        ? AppText.inter(
            size: AppFontSize.base,
            weight: AppText.medium,
            color: AppColors.textPrimary,
          )
        : AppText.poppins(
            size: AppFontSize.base,
            weight: AppText.medium,
            color: AppColors.textPrimary,
          );

    return Container(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.x3.h),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.borderSubtle, width: 1.w),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: 4.h),
          // Stacked rather than a two-column row: a policy number is 23
          // characters and would either wrap awkwardly or overflow beside its
          // label at 1.3x text scale.
          if (isSelectable)
            SelectableText(value, style: style)
          else
            Text(value, style: style),
        ],
      ),
    );
  }
}
