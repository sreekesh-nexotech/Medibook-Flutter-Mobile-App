import 'package:flutter/widgets.dart';

import '../../app/config/constants.dart';

/// Reduce-motion support (audit §3.3.8).
///
/// The home promo banner auto-rotates every 4s with no pause and no
/// reduce-motion check, which is a WCAG 2.2.2 failure and a vestibular-trigger
/// risk. Every animation that moves on its own — carousels, marquees, pulsing
/// skeletons, enter animations — must ask [reduceMotion] first.
///
/// ```dart
/// if (!reduceMotion(context)) _timer = Timer.periodic(interval, _advance);
/// ```
///
/// Honours the OS "Reduce Motion" (iOS) / "Remove animations" (Android)
/// setting, which Flutter surfaces as `MediaQueryData.disableAnimations`.
bool reduceMotion(BuildContext context) =>
    AppConstants.respectReducedMotion(context);

/// [duration], or [Duration.zero] when the viewer asked for reduced motion.
///
/// Use for decorative transitions that should simply *arrive* rather than
/// animate. Functional durations (a debounce, a slot-hold countdown) must not
/// go through this.
Duration motionDuration(BuildContext context, Duration duration) =>
    reduceMotion(context) ? Duration.zero : duration;

/// [interval], or `null` when the viewer asked for reduced motion — the shape
/// an auto-advancing carousel wants, so it can skip starting its timer.
Duration? autoAdvanceInterval(BuildContext context, Duration interval) =>
    reduceMotion(context) ? null : interval;

/// Reduce-motion helpers hung off [BuildContext], for call sites that read
/// better as a property.
extension MotionContext on BuildContext {
  /// True when the viewer has asked the OS to remove animations.
  bool get prefersReducedMotion => reduceMotion(this);

  /// [duration] collapsed to zero under reduced motion.
  Duration motion(Duration duration) => motionDuration(this, duration);
}
