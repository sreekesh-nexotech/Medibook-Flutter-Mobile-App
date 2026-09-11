import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/config/constants.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../error/error_view.dart';
import '../app_button.dart';
import '../app_icon.dart';

/// The "page not found" screen (audit §3.2.4: an unmatched route *"drops the
/// viewer onto a raw framework crash page"*).
///
/// This is what `GoRouter.errorBuilder` must render, and what a detail screen
/// shows when the id in its path does not resolve — a deep link to a cancelled
/// appointment, a `/legal/:slug` with a slug that does not exist, a doctor who
/// has left the practice.
///
/// Wiring (the router file is owned elsewhere):
///
/// ```dart
/// GoRouter(
///   errorBuilder: (context, state) => AppNotFoundView(
///     attemptedPath: state.uri.toString(),
///     onGoHome: () => context.go(AppRoutes.home),
///   ),
///   ...
/// );
/// ```
///
/// [attemptedPath] is shown only in debug builds — a production user gains
/// nothing from seeing a route string, and it can leak an id.
class AppNotFoundView extends StatelessWidget {
  const AppNotFoundView({
    super.key,
    this.headline,
    this.body,
    this.attemptedPath,
    this.onGoHome,
    this.onGoBack,
    this.iconName = MedIcon.search,
  });

  /// Overrides "Page not found".
  final String? headline;

  /// Overrides the explanatory line.
  final String? body;

  /// The route that did not match. Rendered in debug builds only.
  final String? attemptedPath;

  /// Primary action. Every not-found screen should offer a way home.
  final VoidCallback? onGoHome;

  /// Secondary action, when there is a stack to pop.
  final VoidCallback? onGoBack;

  /// [MedIcon] name for the glyph.
  final String iconName;

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.x8.w,
              vertical: 40.h,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppStateGlyph(
                  iconName: iconName,
                  tone: AppStateGlyphTone.neutral,
                ),
                SizedBox(height: AppSpacing.x5.h),
                Text(
                  headline ?? strings.pageNotFoundTitle,
                  textAlign: TextAlign.center,
                  style: AppText.poppins(
                    size: AppFontSize.h3,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: AppSpacing.x2.h),
                Text(
                  body ?? strings.pageNotFoundBody,
                  textAlign: TextAlign.center,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    height: 1.5,
                    color: AppColors.textMuted,
                  ),
                ),
                // Developer affordance only — never shown to a real user.
                if (kDebugMode && attemptedPath != null) ...[
                  SizedBox(height: AppSpacing.x3.h),
                  Text(
                    attemptedPath!,
                    textAlign: TextAlign.center,
                    style: AppText.inter(
                      size: AppFontSize.xs,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                if (onGoHome != null) ...[
                  SizedBox(height: AppSpacing.x6.h),
                  AppButton(
                    label: strings.goHome,
                    fullWidth: true,
                    onPressed: onGoHome,
                  ),
                ],
                if (onGoBack != null) ...[
                  SizedBox(height: AppSpacing.x3.h),
                  AppButton(
                    label: strings.goBack,
                    variant: AppButtonVariant.ghost,
                    fullWidth: true,
                    onPressed: onGoBack,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
