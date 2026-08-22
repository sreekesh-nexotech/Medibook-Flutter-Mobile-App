import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:medibook/app/config/constants.dart';

/// The `screenIn` enter animation shared by the five pushed Auth screens:
/// fade + a 10px rise over 220ms, easing out, once on mount (DESIGN-SPEC §6,
/// Screen Build Guide rule 5). Restrained — no bounce. Wrap the screen body.
///
/// [TweenAnimationBuilder] runs the tween a single time when first built and
/// stays at its end value across later rebuilds (error-state changes, etc.),
/// so the animation never re-fires on a keystroke.
class ScreenFadeRise extends StatelessWidget {
  const ScreenFadeRise({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppConstants.screenIn,
      curve: Curves.easeOut,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 10.h),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
