import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';
import 'app_button.dart';

/// Shows the Medibook confirm sheet (logout / delete / cancel appointment).
///
/// Scrim `AppColors.scrim`, surface sheet, top radius 24, padding `26,22,30`,
/// centered title + message and a Cancel (soft) + confirm row. Tapping the
/// scrim dismisses; [onConfirm] runs after the sheet is popped by Confirm.
Future<void> showMedibookSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  AppButtonVariant confirmVariant = AppButtonVariant.primary,
  required VoidCallback onConfirm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
    builder: (sheetContext) => _MedibookSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      confirmVariant: confirmVariant,
      onConfirm: onConfirm,
    ),
  );
}

class _MedibookSheet extends StatelessWidget {
  const _MedibookSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmVariant,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final AppButtonVariant confirmVariant;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22.w, 26.h, 22.w, 30.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.poppins(
                size: AppFontSize.title,
                weight: AppText.bold,
                color: AppColors.textStrong,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.poppins(
                size: AppFontSize.base,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            SizedBox(height: 22.h),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.soft,
                    fullWidth: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: AppButton(
                    label: confirmLabel,
                    variant: confirmVariant,
                    fullWidth: true,
                    onPressed: () {
                      Navigator.of(context).pop();
                      onConfirm();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
