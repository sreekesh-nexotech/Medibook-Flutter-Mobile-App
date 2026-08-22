import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';

/// Restrained screen-enter animation (cross-cutting rule 5).
///
/// [rise] true → `screenIn`: fade + a 10px upward rise, for pushed screens
/// (detail / reschedule). [rise] false → `fadeIn`: opacity only, for the
/// Appointments tab. 220ms, easeOut, no bounce.
class ScreenEnter extends StatelessWidget {
  const ScreenEnter({super.key, required this.child, this.rise = true});

  final Widget child;
  final bool rise;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: rise ? AppConstants.screenIn : AppConstants.fadeIn,
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
