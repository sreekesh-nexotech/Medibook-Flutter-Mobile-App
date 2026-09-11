import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_icon.dart';

/// A read-only, tappable field that opens a picker — date of birth, gender,
/// blood group, relation, the policy validity dates.
///
/// Mirrors `AppTextField`'s anatomy (label, `surfaceAlt` box with a 1px border,
/// an error line, a helper line) so a form mixing typed and picked fields reads
/// as one control set, with two deliberate differences:
///
/// * **no fixed height** — the box grows with the OS text scale instead of
///   clipping at 1.3x;
/// * it is a labelled `Semantics` button, so a screen reader announces the
///   field, its current value and that tapping opens a picker, rather than
///   reading a bare string.
///
/// `AppSelect` is the core equivalent, but it has no error slot and no helper
/// line, and these forms must show a per-field error on the same rows as their
/// text fields (audit §3.5.4). This is the Profile/Insurance feature's version
/// of the same control; it deliberately copies the records feature's
/// `DocumentPickerField` rather than importing across features.
///
/// When [enabled] is false the row greys out and stops responding, and
/// [helperText] carries the reason — an honest disabled control rather than a
/// tap that silently does nothing.
class ProfilePickerField extends StatelessWidget {
  const ProfilePickerField({
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

  /// What to show when nothing is selected yet.
  final String? placeholder;

  final VoidCallback? onTap;

  /// Trailing [MedIcon] name hinting at what the picker is.
  final String iconName;

  final String? errorText;

  /// A quiet line under the field, shown when there is no [errorText].
  final String? helperText;

  final bool enabled;

  /// Overrides what a screen reader announces. Defaults to "[label]: value".
  final String? semanticLabel;

  bool get _isInert => !enabled || onTap == null;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final hasValue = value != null && value!.isNotEmpty;
    final shown = hasValue ? value! : (placeholder ?? 'Select');

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
          button: !_isInert,
          enabled: !_isInert,
          label: semanticLabel ?? '$label: ${hasValue ? value! : 'not set'}',
          hint: _isInert ? null : 'Opens a picker',
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isInert ? null : onTap,
              child: Container(
                // Minimum, not fixed: the row grows rather than clipping when
                // the OS text scale goes up.
                constraints: BoxConstraints(minHeight: 52.h),
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4.w,
                  vertical: AppSpacing.x3.h,
                ),
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
                          color: enabled && hasValue
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.x3.w),
                    AppIcon(
                      iconName,
                      size: 20,
                      color: enabled
                          ? AppColors.textMuted
                          : AppColors.textInactive,
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
