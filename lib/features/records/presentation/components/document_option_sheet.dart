import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_icon.dart';

/// One row in a [showDocumentOptionSheet].
class DocumentOption<T> {
  const DocumentOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.iconName,
  });

  final T value;
  final String label;

  /// Second line — a relation ("Self"), a date, a doctor.
  final String? subtitle;

  /// Optional leading [MedIcon] name.
  final String? iconName;
}

/// A single-choice picker sheet for the document form (type, patient, linked
/// appointment).
///
/// Goes through `showAppSheet` so it shares the app's one sheet language, and
/// each row is a 48px labelled, selected-state semantics node. Returns the
/// chosen value, or null when the sheet is dismissed.
Future<T?> showDocumentOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<DocumentOption<T>> options,
  T? selected,
}) {
  return showAppSheet<T>(
    context,
    title: title,
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final option in options)
          _OptionRow<T>(
            option: option,
            isSelected: option.value == selected,
            onTap: () => Navigator.of(sheetContext).pop(option.value),
          ),
      ],
    ),
  );
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final DocumentOption<T> option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = option.subtitle;
    final iconName = option.iconName;

    return Semantics(
      button: true,
      selected: isSelected,
      label: option.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 48.h),
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceTint : AppColors.surfaceAlt,
            borderRadius: AppRadii.md,
            border: Border.all(
              color: isSelected ? AppColors.brand : AppColors.border,
              width: 1.w,
            ),
          ),
          child: Row(
            children: [
              if (iconName != null) ...[
                AppIcon(
                  iconName,
                  size: 20,
                  color: isSelected ? AppColors.brand : AppColors.textMuted,
                ),
                SizedBox(width: 12.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: AppText.poppins(
                        size: AppFontSize.base,
                        weight: isSelected ? AppText.semibold : AppText.medium,
                        color: isSelected
                            ? AppColors.brand
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: AppText.poppins(
                          size: AppFontSize.xs,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
