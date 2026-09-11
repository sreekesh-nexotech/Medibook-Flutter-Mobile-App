import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../core/utils/motion.dart';

/// Restrained screen-enter animation for the booking / payment / discovery
/// funnel: a fade, plus a 10px rise for pushed screens.
///
/// One copy for the whole funnel rather than a private `_ScreenEnter` in each
/// of its eight screens. It also answers the reduce-motion question the older
/// copies do not: [motionDuration] collapses the tween to zero when the viewer
/// has asked the OS to remove animations, so the screen simply arrives (audit
/// §3.3.8). An enter animation is decoration, which is exactly the category
/// that must stand still — unlike the slot-hold countdown, which is
/// information and keeps ticking.
class FlowScreenEnter extends StatelessWidget {
  const FlowScreenEnter({super.key, required this.child, this.rise = true});

  final Widget child;

  /// True → `screenIn` (fade + rise), for a pushed screen. False → `fadeIn`
  /// (opacity only), for a tab.
  final bool rise;

  @override
  Widget build(BuildContext context) {
    final duration = context.motion(
      rise ? AppConstants.screenIn : AppConstants.fadeIn,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, t, child) {
        final faded = Opacity(opacity: t.clamp(0.0, 1.0), child: child);
        if (!rise) return faded;
        return Transform.translate(
          offset: Offset(0, (1 - t) * 10.h),
          child: faded,
        );
      },
      child: child,
    );
  }
}
