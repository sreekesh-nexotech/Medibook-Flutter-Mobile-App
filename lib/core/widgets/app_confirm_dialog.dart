import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/localization/l10n.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';
import 'app_button.dart';
import 'app_icon.dart';

/// The shared destructive-confirm dialog.
///
/// The rule this widget exists to enforce: **a destructive confirm must name
/// the consequence, not just the action.** "Are you sure?" tells the user
/// nothing; "Cancel this appointment? Your ₹1,062 will be refunded in 5-7
/// working days, and the 10:30 AM slot will be released" tells them exactly
/// what they are agreeing to. So [consequence] is a required parameter — there
/// is no way to call this without writing one.
///
/// Visual language matches `app_bottom_sheet.dart` — same scrim, same surface,
/// same 24px radius, same Cancel-plus-confirm button row — but rendered as a
/// centred dialog rather than a sheet, because a destructive confirm should
/// interrupt rather than slide up under the thumb.
///
/// Returns true when confirmed, false or null when dismissed. Always check the
/// result; never assume a confirm.
///
/// ```dart
/// final confirmed = await showAppConfirmDialog(
///   context,
///   title: 'Cancel this appointment?',
///   consequence: 'Your ₹1,062 will be refunded in 5-7 working days and the '
///       '10:30 AM slot will be released.',
///   confirmLabel: 'Cancel Appointment',
///   isDestructive: true,
/// );
/// if (confirmed != true) return;
/// ```
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String consequence,
  required String confirmLabel,
  String? cancelLabel,
  bool isDestructive = true,
  String? iconName,
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    // Root navigator so the scrim covers the bottom-nav shell too, matching
    // the sheet's behaviour.
    useRootNavigator: true,
    barrierColor: AppColors.scrim,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => _AppConfirmDialog(
      title: title,
      consequence: consequence,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel ?? dialogContext.l10n.cancel,
      isDestructive: isDestructive,
      iconName: iconName,
    ),
  );
}

class _AppConfirmDialog extends StatelessWidget {
  const _AppConfirmDialog({
    required this.title,
    required this.consequence,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
    this.iconName,
  });

  final String title;
  final String consequence;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final String? iconName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
      shape: RoundedRectangleBorder(borderRadius: AppRadii.xl),
      child: Padding(
        padding: EdgeInsets.fromLTRB(22.w, 26.h, 22.w, 22.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconName != null) ...[
              Container(
                width: 56.w,
                height: 56.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppColors.dangerSoft
                      : AppColors.surfaceTint,
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  iconName!,
                  size: 26,
                  color: isDestructive ? AppColors.dangerText : AppColors.brand,
                ),
              ),
              SizedBox(height: 16.h),
            ],
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppText.poppins(
                  size: AppFontSize.title,
                  weight: AppText.bold,
                  color: AppColors.textStrong,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            // The consequence, in the body slot — the whole reason this dialog
            // exists rather than a generic "Are you sure?".
            Text(
              consequence,
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
                    label: cancelLabel,
                    variant: AppButtonVariant.soft,
                    fullWidth: true,
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: AppButton(
                    label: confirmLabel,
                    variant: isDestructive
                        ? AppButtonVariant.danger
                        : AppButtonVariant.primary,
                    fullWidth: true,
                    onPressed: () => Navigator.of(context).pop(true),
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
