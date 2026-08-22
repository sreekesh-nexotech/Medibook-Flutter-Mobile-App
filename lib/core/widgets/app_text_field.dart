import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';
import 'app_icon.dart';

/// A labelled text input. Stateless by design — the owning screen holds the
/// [TextEditingController] and any obscure-toggle state. Field: `h 52`,
/// `surfaceAlt` fill, 1px border (`danger` on error), `--radius-md`.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.controller,
    this.onChanged,
    this.hintText,
    this.errorText,
    this.iconName,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
  });

  final String? label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Placeholder text.
  final String? hintText;
  final String? errorText;

  /// Optional leading [MedIcon] name.
  final String? iconName;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.medium,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        Container(
          height: 52.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
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
              if (iconName != null) ...[
                AppIcon(iconName!, size: 20, color: AppColors.textMuted),
                SizedBox(width: 10.w),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  obscureText: obscureText,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  cursorColor: AppColors.brand,
                  textAlignVertical: TextAlignVertical.center,
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: AppText.poppins(
                      size: AppFontSize.body,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
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
        ],
      ],
    );
  }
}
