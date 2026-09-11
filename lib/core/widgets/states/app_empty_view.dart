import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/config/constants.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme.dart';
import '../../../app/theme/typography.dart';
import '../../error/error_view.dart';
import '../app_button.dart';
import '../app_icon.dart';

/// The empty state (audit §3.2.2).
///
/// The audit's specific complaint was not that empty states were missing but
/// that they *"offer no action"* — a patient with no appointments was told so
/// and left there. So [actionLabel] + [onAction] are first-class here, and the
/// doc for every call site is: **an empty state should always name the one
/// thing the user came to do.**
///
/// ```dart
/// AppEmptyView(
///   iconName: MedIcon.calendar,
///   headline: 'No upcoming appointments',
///   body: 'Book a consultation and it will show up here.',
///   actionLabel: 'Book an Appointment',
///   onAction: () => context.push(AppRoutes.bookingPath()),
/// )
/// ```
///
/// Shares [AppStateGlyph] with [AppErrorView] and `AppNotFoundView`, so the
/// four screen states read as one family.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.iconName,
    required this.headline,
    this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.padding,
  });

  /// [MedIcon] name for the glyph — pick the one that matches the missing
  /// thing (`calendar` for appointments, `records` for documents).
  final String iconName;

  /// One short line: what is missing.
  final String headline;

  /// One or two lines: why it is empty, or what fills it.
  final String? body;

  /// The primary action. **Provide one** unless the screen genuinely has
  /// nothing to offer.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// An optional second, quieter action.
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Defaults to `EdgeInsets.symmetric(horizontal: 32.w, vertical: 40.h)`.
  final EdgeInsetsGeometry? padding;

  bool get _hasAction => actionLabel != null && onAction != null;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding:
            padding ??
            EdgeInsets.symmetric(horizontal: AppSpacing.x8.w, vertical: 40.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppStateGlyph(iconName: iconName),
            SizedBox(height: AppSpacing.x5.h),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: AppText.poppins(
                size: AppFontSize.h3,
                weight: AppText.bold,
                color: AppColors.textStrong,
              ),
            ),
            if (body != null) ...[
              SizedBox(height: AppSpacing.x2.h),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: AppText.poppins(
                  size: AppFontSize.base,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (_hasAction) ...[
              SizedBox(height: AppSpacing.x6.h),
              AppButton(
                label: actionLabel!,
                fullWidth: true,
                onPressed: onAction,
              ),
            ],
            if (secondaryLabel != null && onSecondary != null) ...[
              SizedBox(height: AppSpacing.x3.h),
              AppButton(
                label: secondaryLabel!,
                variant: AppButtonVariant.ghost,
                fullWidth: true,
                onPressed: onSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The compact empty state, for an empty section inside a populated screen —
/// "no documents for this appointment", "no slots on this day".
///
/// Same inset-row language as [AppInlineError]: `surfaceAlt`, 1px `border`,
/// `--radius-md`. Still takes an action, for the same reason.
class AppInlineEmpty extends StatelessWidget {
  const AppInlineEmpty({
    super.key,
    required this.message,
    this.iconName,
    this.actionLabel,
    this.onAction,
    this.margin,
  });

  final String message;

  /// Optional [MedIcon] name for a leading glyph.
  final String? iconName;

  final String? actionLabel;
  final VoidCallback? onAction;

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;

    return Container(
      margin: margin,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.x4.w,
        vertical: AppSpacing.x4.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.md,
        border: Border.all(color: AppColors.border, width: 1.w),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconName != null) ...[
            AppIcon(iconName!, size: 22, color: AppColors.textMuted),
            SizedBox(height: AppSpacing.x2.h),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.poppins(
              size: AppFontSize.sm,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          if (hasAction) ...[
            SizedBox(height: AppSpacing.x2.h),
            AppButton(
              label: actionLabel!,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
