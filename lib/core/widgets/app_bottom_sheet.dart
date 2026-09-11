import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';
import 'app_button.dart';
import 'app_icon.dart';
import 'app_icon_button.dart';

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
    // Root navigator so the sheet + scrim cover the bottom-nav shell too,
    // matching the design (the scrim dims the whole screen).
    useRootNavigator: true,
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

/// Shows a generic Medibook bottom sheet: the same scrim, surface, 24px top
/// radius and padding rhythm as [showMedibookSheet], with the body supplied by
/// the caller.
///
/// Use this rather than a bare `showModalBottomSheet` so every sheet in the app
/// has one visual language — the country-code picker, the month calendar and
/// the filter sheet all go through here.
///
/// Returns the value the sheet was popped with, or null when it was dismissed.
///
/// ```dart
/// final picked = await showAppSheet<CountryCode>(
///   context,
///   title: 'Select country code',
///   builder: (sheetContext) => Column(children: [...]),
/// );
/// ```
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool showCloseButton = true,
  bool isDismissible = true,
  bool scrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // Root navigator so the sheet + scrim cover the bottom-nav shell too.
    useRootNavigator: true,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    shape: RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
    builder: (sheetContext) => _AppSheetFrame(
      title: title,
      showCloseButton: showCloseButton,
      scrollable: scrollable,
      builder: builder,
    ),
  );
}

/// The shared chrome for [showAppSheet]: grab handle, optional title row with
/// a labelled close button, then the caller's body.
class _AppSheetFrame extends StatelessWidget {
  const _AppSheetFrame({
    required this.builder,
    required this.showCloseButton,
    required this.scrollable,
    this.title,
  });

  final WidgetBuilder builder;
  final bool showCloseButton;
  final bool scrollable;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final body = builder(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(22.w, 14.h, 22.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grab handle — the affordance that says "this can be dragged".
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.grey200,
                  borderRadius: AppRadii.pill,
                ),
              ),
            ),
            if (title != null) ...[
              SizedBox(height: 14.h),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title!,
                        style: AppText.poppins(
                          size: AppFontSize.title,
                          weight: AppText.bold,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ),
                  ),
                  if (showCloseButton)
                    AppIconButton(
                      icon: MedIcon.close,
                      size: 32,
                      semanticLabel: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ],
            SizedBox(height: 12.h),
            // A tall body (the month grid, a long picker) scrolls rather than
            // overflowing; a short one is left alone.
            if (scrollable)
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: body,
                ),
              )
            else
              body,
          ],
        ),
      ),
    );
  }
}
