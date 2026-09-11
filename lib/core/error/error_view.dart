import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/config/constants.dart';
import '../../app/localization/l10n.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';
import 'failure.dart';

/// The full-screen error state (audit §3.2.3: *"the patient app has no error
/// state whatsoever"*).
///
/// Takes a [Failure] and renders its [Failure.userMessage] — so the wording is
/// decided once, in the error model, rather than re-invented per screen — plus
/// a headline, a tinted glyph and a Retry button. [onRetry] is hidden
/// automatically when the failure is not retryable ([Failure.isRetryable]),
/// because offering "Try Again" for a 404 teaches users the button does
/// nothing.
///
/// Visual language matches the rest of the design system: `surfaceTint` circle,
/// Poppins h3 bold `textStrong` headline, `textMuted` body at 1.5 line height,
/// a full-width primary [AppButton], all `.w`/`.h`/`.sp`-scaled.
///
/// ```dart
/// AppErrorView(failure: failure, onRetry: () => ref.invalidate(doctorsProvider))
/// ```
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.failure,
    this.onRetry,
    this.headline,
    this.iconName = MedIcon.closeCircle,
    this.retryLabel,
    this.secondaryLabel,
    this.onSecondary,
    this.padding,
  });

  /// The problem. Its [Failure.userMessage] is the body copy.
  final Failure failure;

  /// Retry handler. When null — or when the failure is not retryable — no
  /// Retry button is shown.
  final VoidCallback? onRetry;

  /// Overrides the default headline ("Something went wrong", or "You're
  /// offline" for a [NetworkFailure]).
  final String? headline;

  /// [MedIcon] name for the glyph.
  final String iconName;

  /// Overrides the Retry button's label.
  final String? retryLabel;

  /// Optional second action ("Go to Home", "Contact Support").
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Defaults to `EdgeInsets.symmetric(horizontal: 32.w, vertical: 40.h)`.
  final EdgeInsetsGeometry? padding;

  /// Whether a Retry button will be rendered — exposed so a screen can decide
  /// whether it still needs its own action row.
  bool get showsRetry => onRetry != null && failure.isRetryable;

  String _headline(BuildContext context) {
    if (headline != null) return headline!;
    return switch (failure) {
      NetworkFailure() => context.l10n.offlineTitle,
      NotFoundFailure() => context.l10n.pageNotFoundTitle,
      _ => context.l10n.somethingWentWrong,
    };
  }

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
            _StateGlyph(iconName: iconName, tone: _GlyphTone.danger),
            SizedBox(height: AppSpacing.x5.h),
            Text(
              _headline(context),
              textAlign: TextAlign.center,
              style: AppText.poppins(
                size: AppFontSize.h3,
                weight: AppText.bold,
                color: AppColors.textStrong,
              ),
            ),
            SizedBox(height: AppSpacing.x2.h),
            Text(
              failure.userMessage,
              textAlign: TextAlign.center,
              style: AppText.poppins(
                size: AppFontSize.base,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            if (showsRetry) ...[
              SizedBox(height: AppSpacing.x6.h),
              AppButton(
                label: retryLabel ?? context.l10n.retry,
                fullWidth: true,
                leadingIcon: MedIcon.back,
                onPressed: onRetry,
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

/// The compact error state, for a failed section inside an otherwise working
/// screen — a list that would not load, a fee quote that timed out.
///
/// Reads as one of the app's inset rows: `surfaceAlt` fill, 1px `border`,
/// `--radius-md`. Renders [Failure.userMessage] and, when the failure is
/// retryable and [onRetry] is given, a ghost "Try Again".
///
/// ```dart
/// AppInlineError(failure: failure, onRetry: controller.reload)
/// ```
class AppInlineError extends StatelessWidget {
  const AppInlineError({
    super.key,
    required this.failure,
    this.onRetry,
    this.retryLabel,
    this.iconName = MedIcon.closeCircle,
    this.margin,
  });

  final Failure failure;
  final VoidCallback? onRetry;
  final String? retryLabel;

  /// [MedIcon] name for the leading glyph.
  final String iconName;

  final EdgeInsetsGeometry? margin;

  bool get showsRetry => onRetry != null && failure.isRetryable;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.x4.w,
        vertical: AppSpacing.x3.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.md,
        border: Border.all(color: AppColors.border, width: 1.w),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1.h),
            child: AppIcon(iconName, size: 18, color: AppColors.danger),
          ),
          SizedBox(width: AppSpacing.x3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  failure.userMessage,
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    height: 1.45,
                    color: AppColors.textBody,
                  ),
                ),
                if (showsRetry) ...[
                  SizedBox(height: AppSpacing.x2.h),
                  AppButton(
                    label: retryLabel ?? context.l10n.retry,
                    variant: AppButtonVariant.ghost,
                    size: AppButtonSize.sm,
                    onPressed: onRetry,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A persistent, non-blocking banner for a problem the screen can survive —
/// "you are offline, this data is from earlier", or the amber stale-cache bar
/// from `docs-flutter/HIVE implementation.md` (Scenario 5).
///
/// Distinct from [AppInlineError]: this one sits above working content rather
/// than replacing it, so it is quieter and the whole bar is the retry target.
class AppErrorBanner extends StatelessWidget {
  const AppErrorBanner({
    super.key,
    required this.message,
    this.onTap,
    this.tone = AppBannerTone.warning,
    this.iconName = MedIcon.clock,
  });

  final String message;

  /// Tapping the bar retries. Null → informational only.
  final VoidCallback? onTap;

  final AppBannerTone tone;

  /// [MedIcon] name for the leading glyph.
  final String iconName;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      AppBannerTone.warning => (AppColors.warningSoft, AppColors.textPrimary),
      AppBannerTone.danger => (AppColors.dangerSoft, AppColors.dangerText),
      AppBannerTone.info => (AppColors.surfaceTint, AppColors.brand),
    };

    final content = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.x4.w,
        vertical: AppSpacing.x2.h,
      ),
      color: background,
      child: Row(
        children: [
          AppIcon(iconName, size: 16, color: foreground),
          SizedBox(width: AppSpacing.x2.w),
          Expanded(
            child: Text(
              message,
              style: AppText.poppins(
                size: AppFontSize.xs,
                weight: AppText.medium,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return Semantics(liveRegion: true, child: content);
    return Semantics(
      liveRegion: true,
      button: true,
      label: message,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Tone for [AppErrorBanner].
enum AppBannerTone { info, warning, danger }

/// Tone for the state glyph circle.
enum _GlyphTone { brand, danger, neutral }

/// The 72px tinted circle that heads every full-screen state. Shared by
/// [AppErrorView], `AppEmptyView`, `AppNotFoundView` and `AppLoadingView`, so
/// the four states are unmistakably the same family.
class _StateGlyph extends StatelessWidget {
  const _StateGlyph({required this.iconName, this.tone = _GlyphTone.brand});

  final String iconName;
  final _GlyphTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      _GlyphTone.brand => (AppColors.surfaceTint, AppColors.brand),
      _GlyphTone.danger => (AppColors.dangerSoft, AppColors.dangerText),
      _GlyphTone.neutral => (AppColors.grey100, AppColors.grey500),
    };

    return Container(
      width: 72.w,
      height: 72.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: AppIcon(iconName, size: 32, color: foreground),
    );
  }
}

/// The state glyph, exposed for the sibling state widgets in
/// `core/widgets/states/` so the circle is defined exactly once.
class AppStateGlyph extends StatelessWidget {
  const AppStateGlyph({
    super.key,
    required this.iconName,
    this.tone = AppStateGlyphTone.brand,
  });

  /// [MedIcon] name.
  final String iconName;

  final AppStateGlyphTone tone;

  @override
  Widget build(BuildContext context) => _StateGlyph(
    iconName: iconName,
    tone: switch (tone) {
      AppStateGlyphTone.brand => _GlyphTone.brand,
      AppStateGlyphTone.danger => _GlyphTone.danger,
      AppStateGlyphTone.neutral => _GlyphTone.neutral,
    },
  );
}

/// Public tone for [AppStateGlyph].
enum AppStateGlyphTone { brand, danger, neutral }
