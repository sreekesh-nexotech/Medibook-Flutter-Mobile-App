import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/config/constants.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../utils/motion.dart';

/// Page indicator dots for the home promo banner (and any other carousel).
///
/// The active dot is a `brand` pill; inactive dots are `grey200` circles.
/// Tapping a dot jumps to that page, via [onDotTapped] — an indicator that
/// cannot be used to navigate is decoration, and the tap target is 44px even
/// though the dot is 7px.
///
/// Also announces itself properly: the row reports "Slide 2 of 3" rather than
/// leaving a screen-reader user with three unlabelled shapes.
///
/// The defaults are the home banner's 7px dots. The onboarding intro uses the
/// design's larger 8px dots with a 28px active pill and a full 44px tap
/// target per dot, via [dotSize], [activeWidth] and [tapTargetWidth].
class AppCarouselDots extends StatelessWidget {
  const AppCarouselDots({
    super.key,
    required this.count,
    required this.activeIndex,
    this.onDotTapped,
    this.activeColor,
    this.inactiveColor,
    this.dotSize = 7,
    this.activeWidth = 18,
    this.tapTargetWidth,
    this.gap = 0,
  });

  final int count;
  final int activeIndex;

  /// Diameter of an inactive dot and height of the active pill (design px).
  final double dotSize;

  /// Width of the active pill (design px).
  final double activeWidth;

  /// Width of each dot's tap target (design px). Null keeps the banner's
  /// packed layout, where the dots share one 44px-wide target.
  final double? tapTargetWidth;

  /// Space between tap targets (design px).
  final double gap;

  /// Jump to a page. Null → the dots are display-only.
  final ValueChanged<int>? onDotTapped;

  /// Defaults to [AppColors.brand].
  final Color? activeColor;

  /// Defaults to [AppColors.grey200].
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();

    final active = activeColor ?? AppColors.brand;
    final inactive = inactiveColor ?? AppColors.grey200;

    return Semantics(
      label: 'Slide ${activeIndex + 1} of $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0 && gap > 0) SizedBox(width: gap.w),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDotTapped == null ? null : () => onDotTapped!(i),
                child: SizedBox(
                  // 44px tap target around a 7px dot.
                  width: tapTargetWidth?.w ?? 44.w / count.clamp(1, 4),
                  height: 44.h,
                  child: Center(
                    child: AnimatedContainer(
                      duration: context.motion(AppConstants.easeShort),
                      curve: Curves.easeOut,
                      width: (i == activeIndex ? activeWidth : dotSize).w,
                      height: dotSize.h,
                      decoration: BoxDecoration(
                        color: i == activeIndex ? active : inactive,
                        borderRadius: AppRadii.pill,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Auto-advance timing for a carousel, resolved against the two switches that
/// must both allow it.
///
/// Audit §3.3.8: the home banner auto-rotates every 4s with no pause and no
/// reduce-motion check, which fails WCAG 2.2.2 (a moving thing longer than 5s
/// must be pausable) and is a vestibular trigger. A carousel must therefore ask
/// **both** questions before starting a timer:
///
/// 1. Is auto-rotation enabled for this build? (`FeatureFlags.bannerAutoRotate`)
/// 2. Has this viewer asked for reduced motion? (`reduceMotion(context)`)
///
/// [resolve] answers both at once and returns null when the carousel must
/// stand still — so the call site is a single null check rather than two
/// conditions someone can half-remember.
///
/// ```dart
/// final interval = AppCarouselAutoplay.resolve(
///   context,
///   enabled: FeatureFlags.bannerAutoRotate,
/// );
/// if (interval != null) _timer = Timer.periodic(interval, _advance);
/// ```
///
/// **Pause on touch** is the other half of WCAG 2.2.2 and belongs to the
/// carousel itself: cancel the timer in `onPointerDown` / when the `PageView`
/// starts being dragged, and restart it after. [pauseAfterInteraction] is the
/// recommended delay before resuming.
abstract final class AppCarouselAutoplay {
  AppCarouselAutoplay._();

  /// How long to leave a carousel alone after the user touches it, before
  /// auto-advance resumes.
  static const Duration pauseAfterInteraction = Duration(seconds: 8);

  /// The interval a carousel should use, or null when it must not auto-advance.
  ///
  /// [enabled] is the product decision (a feature flag); the reduced-motion
  /// check is applied here so no call site can skip it.
  static Duration? resolve(
    BuildContext context, {
    required bool enabled,
    Duration interval = AppConstants.bannerInterval,
  }) {
    if (!enabled) return null;
    return autoAdvanceInterval(context, interval);
  }
}
