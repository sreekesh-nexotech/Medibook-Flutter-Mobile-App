import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';
import 'app_icon.dart';

/// A `mm:ss` countdown that calls [onExpired] once when it reaches zero.
///
/// Two things in the app need exactly this and must not each grow their own
/// timer:
/// * **X-02, the slot hold** — a picked slot is held for
///   `AppConstants.slotHold` while the patient pays, and the payment screen
///   has to show the time left and release the slot when it runs out.
/// * **CM-05, the sign-in lockout** — the lockout screen counts down
///   `AppConstants.loginLockoutCooldown` and re-enables the form.
///
/// ## Deliberate design points
///
/// * **[onExpired] fires exactly once**, even across rebuilds, so a payment is
///   not cancelled twice.
/// * The timer is driven by **wall-clock arithmetic against a deadline**, not
///   by counting ticks. A `Timer.periodic` that counts down loses time
///   whenever the app is backgrounded, which would let a 5-minute hold last
///   eight real minutes. This recomputes from [deadline] every tick, so
///   returning to the app shows the truth.
/// * It ticks once a second and only rebuilds the label, so it is cheap enough
///   to sit inside a payment screen.
/// * Reduced motion is irrelevant here — a countdown is information, not
///   decoration — so it is **not** suppressed. It is announced to screen
///   readers at [announceEvery] rather than every second, so the reader is not
///   flooded.
class AppCountdown extends StatefulWidget {
  const AppCountdown({
    super.key,
    required this.deadline,
    this.onExpired,
    this.builder,
    this.style,
    this.expiredLabel = '00:00',
    this.announceEvery = const Duration(seconds: 30),
  });

  /// When the countdown reaches zero. Absolute, so backgrounding cannot cheat.
  final DateTime deadline;

  /// Called once, when the remaining time first hits zero.
  final VoidCallback? onExpired;

  /// Custom rendering. Receives the remaining time and the `mm:ss` label.
  /// Null → a plain [Text].
  final Widget Function(BuildContext context, Duration remaining, String label)?
  builder;

  /// Text style for the default [Text] rendering.
  final TextStyle? style;

  /// Shown once expired.
  final String expiredLabel;

  /// How often the remaining time is announced to a screen reader.
  final Duration announceEvery;

  /// `mm:ss` for [remaining] (`05:00`, `00:09`). Hours are folded into
  /// minutes, because nothing in this app counts down for an hour.
  static String format(Duration remaining) {
    final total = remaining.isNegative ? Duration.zero : remaining;
    final minutes = total.inMinutes.toString().padLeft(2, '0');
    final seconds = (total.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  State<AppCountdown> createState() => _AppCountdownState();
}

class _AppCountdownState extends State<AppCountdown> {
  Timer? _timer;
  late Duration _remaining;
  bool _expiredFired = false;
  int _lastAnnouncedBucket = -1;

  @override
  void initState() {
    super.initState();
    _remaining = _computeRemaining();
    if (_remaining == Duration.zero) {
      _fireExpired();
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  @override
  void didUpdateWidget(AppCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new deadline (the hold was extended, a new lockout began) restarts the
    // countdown and re-arms onExpired.
    if (oldWidget.deadline != widget.deadline) {
      _expiredFired = false;
      _lastAnnouncedBucket = -1;
      _remaining = _computeRemaining();
      _timer?.cancel();
      if (_remaining == Duration.zero) {
        _fireExpired();
      } else {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Recomputed from the wall clock each tick, so backgrounding is accounted
  /// for rather than paused through.
  Duration _computeRemaining() {
    final left = widget.deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _tick() {
    if (!mounted) return;
    final next = _computeRemaining();
    // Only rebuild when the displayed second actually changes.
    if (next.inSeconds == _remaining.inSeconds && next != Duration.zero) return;
    setState(() => _remaining = next);
    if (next == Duration.zero) {
      _timer?.cancel();
      _fireExpired();
    }
  }

  void _fireExpired() {
    if (_expiredFired) return;
    _expiredFired = true;
    final callback = widget.onExpired;
    if (callback == null) return;
    // Deferred so a caller can safely navigate or mutate a provider — firing
    // during initState/build would throw.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) callback();
    });
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining == Duration.zero;
    final label = expired
        ? widget.expiredLabel
        : AppCountdown.format(_remaining);

    final child =
        widget.builder?.call(context, _remaining, label) ??
        Text(
          label,
          style:
              widget.style ??
              AppText.inter(
                size: AppFontSize.base,
                weight: AppText.semibold,
                color: expired ? AppColors.danger : AppColors.textStrong,
              ),
        );

    // Announce at intervals, not every second, so a screen reader is not
    // flooded by a ticking clock.
    final bucket =
        _remaining.inSeconds ~/ (widget.announceEvery.inSeconds.clamp(1, 3600));
    final shouldAnnounce = expired || bucket != _lastAnnouncedBucket;
    if (shouldAnnounce) _lastAnnouncedBucket = bucket;

    return Semantics(
      liveRegion: shouldAnnounce,
      label: expired ? 'Time expired' : '$label remaining',
      child: ExcludeSemantics(child: child),
    );
  }
}

/// The countdown as a pill — what the payment screen shows above the fee
/// summary while the slot is held (X-02).
///
/// Tinted brand while there is time, danger-tinted in the last minute, so the
/// urgency is visible without a second widget.
class AppCountdownPill extends StatelessWidget {
  const AppCountdownPill({
    super.key,
    required this.deadline,
    this.onExpired,
    this.prefix,
    this.iconName = MedIcon.clock,
    this.urgentThreshold = const Duration(minutes: 1),
  });

  final DateTime deadline;
  final VoidCallback? onExpired;

  /// Leading copy ("Slot held for"). Null → the timer alone.
  final String? prefix;

  /// [MedIcon] name for the leading glyph.
  final String iconName;

  /// Below this, the pill turns danger-toned.
  final Duration urgentThreshold;

  @override
  Widget build(BuildContext context) {
    return AppCountdown(
      deadline: deadline,
      onExpired: onExpired,
      builder: (context, remaining, label) {
        final urgent = remaining <= urgentThreshold;
        final background = urgent
            ? AppColors.dangerSoft
            : AppColors.surfaceTint;
        final foreground = urgent ? AppColors.dangerText : AppColors.brand;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppRadii.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(iconName, size: 15, color: foreground),
              SizedBox(width: 7.w),
              if (prefix != null) ...[
                Text(
                  prefix!,
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    weight: AppText.medium,
                    color: foreground,
                  ),
                ),
                SizedBox(width: 5.w),
              ],
              Text(
                label,
                style: AppText.inter(
                  size: AppFontSize.sm,
                  weight: AppText.semibold,
                  color: foreground,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
