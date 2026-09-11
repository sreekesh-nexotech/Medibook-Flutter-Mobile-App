import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_icon.dart';

/// A read-only, tappable field that opens a picker — the document form's type,
/// patient, date and appointment rows.
///
/// Mirrors `AppTextField`'s anatomy (label, `surfaceAlt` box with a 1px border,
/// error line, helper line) so the form reads as one control set, with two
/// deliberate differences:
///
/// * it has **no fixed height** — it grows with the OS text scale, which a
///   52px box would clip at 1.3x;
/// * it is a labelled `Semantics` button, so a screen reader announces the
///   field, its current value and that tapping opens a picker.
///
/// When [enabled] is false the row greys out and stops responding, and
/// [helperText] is where the reason goes ("locked after upload") — an honest
/// disabled control per the project's rule on controls that cannot act.
class DocumentPickerField extends StatelessWidget {
  const DocumentPickerField({
    super.key,
    required this.label,
    required this.value,
    this.placeholder,
    this.onTap,
    this.iconName = MedIcon.calendar,
    this.errorText,
    this.helperText,
    this.enabled = true,
    this.semanticLabel,
  });

  final String label;

  /// The current selection, or null to render [placeholder].
  final String? value;
  final String? placeholder;
  final VoidCallback? onTap;

  /// Trailing [MedIcon] name hinting at what the picker is.
  final String iconName;

  final String? errorText;

  /// A quiet line under the field, shown when there is no [errorText]. Carries
  /// the reason when [enabled] is false.
  final String? helperText;

  final bool enabled;

  /// Overrides what a screen reader announces. Defaults to "[label]: [value]".
  final String? semanticLabel;

  bool get _isInert => !enabled || onTap == null;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final shown = value ?? placeholder ?? 'Select';
    final hasValue = value != null;

    final box = Container(
      // Minimum, not fixed: the row grows instead of clipping when the OS text
      // scale goes up.
      constraints: BoxConstraints(minHeight: 52.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: enabled ? AppColors.surfaceAlt : AppColors.grey100,
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
              shown,
              style: AppText.poppins(
                size: AppFontSize.body,
                color: !enabled
                    ? AppColors.textMuted
                    : hasValue
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          AppIcon(
            iconName,
            size: 20,
            color: enabled ? AppColors.textMuted : AppColors.textInactive,
          ),
        ],
      ),
    );

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
        SizedBox(height: 8.h),
        Semantics(
          button: enabled,
          enabled: enabled,
          label: semanticLabel ?? '$label: $shown',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isInert ? null : onTap,
            child: box,
          ),
        ),
        if (hasError) ...[
          SizedBox(height: 6.h),
          Text(
            errorText!,
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.danger,
            ),
          ),
        ] else if (helperText != null) ...[
          SizedBox(height: 6.h),
          Text(
            helperText!,
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
