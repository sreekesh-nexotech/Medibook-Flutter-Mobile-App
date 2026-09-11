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
class AppCarouselDots extends StatelessWidget {
  const AppCarouselDots({
    super.key,
    required this.count,
    required this.activeIndex,
    this.onDotTapped,
    this.activeColor,
    this.inactiveColor,
  });

  final int count;
  final int activeIndex;

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
            for (var i = 0; i < count; i++)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDotTapped == null ? null : () => onDotTapped!(i),
                child: SizedBox(
                  // 44px tap target around a 7px dot.
                  width: 44.w / count.clamp(1, 4),
                  height: 44.h,
                  child: Center(
                    child: AnimatedContainer(
                      duration: context.motion(AppConstants.easeShort),
                      curve: Curves.easeOut,
                      width: (i == activeIndex ? 18 : 7).w,
                      height: 7.h,
                      decoration: BoxDecoration(
                        color: i == activeIndex ? active : inactive,
                        borderRadius: AppRadii.pill,
                      ),
                    ),
                  ),
                ),
              ),
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
