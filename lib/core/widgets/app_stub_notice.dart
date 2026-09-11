import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/config/constants.dart';
import '../../app/localization/l10n.dart';
import '../../app/monitoring/analytics.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';
import 'app_icon.dart';
import 'toast/toast_controller.dart';

/// The sanctioned way to render a control whose action genuinely cannot happen
/// in this build (audit §4.1 — *"make the lying controls honest"*).
///
/// This presentation-layer build ships **no** file picker, share sheet, PDF
/// renderer, payment SDK or telephony plugin, and must not gain them. So a
/// "Download", "Share" or "Pay" control has three legitimate shapes, and no
/// fourth:
///
/// 1. **It does the thing.** Preferred, always.
/// 2. **It is disabled with a reason** —
///    `AppButton(label: …, disabled: true, semanticLabel: 'Download — not
///    available offline')`. Use when the action will never be available in
///    this context.
/// 3. **It says it is stubbed** — [showStubbedToast] in `onPressed`, or
///    [AppButton.stubbed] for the presentation, or [AppStubBanner] for a whole
///    unbuilt section.
///
/// What it must never do is fire a success toast for something that did not
/// happen. "Prescription downloaded" when no file was written is the single
/// worst class of bug in this app, because the patient then looks for a file
/// that does not exist.
///
/// The house wording is fixed in one place, [AppStrings.stubbed], so every
/// stubbed control in every feature reads the same:
/// `"<Action> is stubbed in this demo"`.
///
/// ```dart
/// AppButton(
///   label: 'Download',
///   stubbed: true,
///   onPressed: () => showStubbedToast(context, ref, 'Download'),
/// )
/// ```

/// Show the house "stubbed" toast for [action].
///
/// [action] is the thing that did not happen, capitalised as a label —
/// `'Download'`, `'Share'`, `'Payment'`, `'Calling the ambulance'`. The
/// sentence is assembled by [AppStrings.stubbed], so callers never write the
/// wording themselves.
///
/// Also records an [AnalyticsEvent.stubbedActionTapped] event, so the stubbed
/// surface is measurable rather than invisible — how often users reach for a
/// control that cannot work is exactly what should drive what gets built next.
///
/// Call from a callback (`onPressed`), never from a `build`.
void showStubbedToast(BuildContext context, WidgetRef ref, String action) {
  ref.read(toastControllerProvider.notifier).show(context.l10n.stubbed(action));
  Analytics.track(AnalyticsEvent.stubbedActionTapped, {'action': action});
}

/// [showStubbedToast] for a `Ref` (a controller or provider callback) rather
/// than a widget's `WidgetRef`. Takes the wording directly, because there is no
/// [BuildContext] to resolve the locale from.
void reportStubbedAction(Ref ref, String action, {required String message}) {
  ref.read(toastControllerProvider.notifier).show(message);
  Analytics.track(AnalyticsEvent.stubbedActionTapped, {'action': action});
}

/// A banner marking a whole section that is part of the design but is not
/// wired up in this build.
///
/// Use above (not instead of) the section's real layout when the layout itself
/// is worth showing to a reviewer, and in place of it when it is not. Reads as
/// one of the app's inset rows — `surfaceAlt` fill, `border` hairline,
/// `--radius-md` — with a warning-toned marker, so it is visibly a note about
/// the build rather than a piece of the product.
///
/// ```dart
/// AppStubBanner(
///   title: 'Video consultation',
///   body: 'The call screen is designed but not connected in this build.',
/// )
/// ```
class AppStubBanner extends StatelessWidget {
  const AppStubBanner({
    super.key,
    this.title,
    this.body,
    this.iconName = MedIcon.closeCircle,
    this.margin,
  });

  /// Defaults to [AppStrings.stubBannerTitle] ("Not built yet").
  final String? title;

  /// Defaults to [AppStrings.stubBannerBody].
  final String? body;

  /// [MedIcon] name for the leading glyph.
  final String iconName;

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;

    return Container(
      margin: margin,
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.x4.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.md,
        border: Border.all(color: AppColors.border, width: 1.w),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.warningSoft,
              shape: BoxShape.circle,
            ),
            child: AppIcon(iconName, size: 16, color: AppColors.warning),
          ),
          SizedBox(width: AppSpacing.x3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title ?? strings.stubBannerTitle,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  body ?? strings.stubBannerBody,
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    height: 1.45,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small inline "demo" tag, for marking one row or value inside otherwise
/// working content ("Estimated wait · demo data").
class AppStubTag extends StatelessWidget {
  const AppStubTag({super.key, this.label = 'demo'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: AppRadii.pill,
      ),
      child: Text(
        label,
        style: AppText.poppins(
          size: AppFontSize.xxs,
          weight: AppText.medium,
          color: AppColors.warning,
        ),
      ),
    );
  }
}
