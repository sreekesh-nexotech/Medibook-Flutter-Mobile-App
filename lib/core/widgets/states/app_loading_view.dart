import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/config/constants.dart';
import '../../../app/localization/l10n.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme.dart';
import '../../../app/theme/typography.dart';
import '../../utils/motion.dart';

/// The loading state (audit §3.2.1: the app had no designed loading state, so
/// every async screen would have shown a bare framework spinner).
///
/// Two shapes:
/// * [AppLoadingView] — full-screen, a brand spinner over an optional label.
/// * [AppInlineLoader] — a small spinner for inside a button row or a section.
///
/// Prefer the **skeletons** below for a screen whose layout is already known:
/// a skeleton that matches the real card shape makes the wait feel shorter and
/// stops the content jumping when it arrives.
///
/// No `shimmer` package. The pulse is a `TweenAnimationBuilder` opacity cycle
/// (see [AppSkeletonLine]), which respects reduced motion — under
/// "remove animations" the skeleton renders flat rather than pulsing
/// (audit §3.3.8).
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.label, this.padding});

  /// Optional caption under the spinner. Null → spinner only.
  final String? label;

  /// Defaults to `EdgeInsets.all(32.w)`.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding ?? EdgeInsets.all(AppSpacing.x8.w),
        child: Semantics(
          liveRegion: true,
          label: label ?? context.l10n.loading,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32.w,
                height: 32.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5.w,
                  color: AppColors.brand,
                  backgroundColor: AppColors.grey100,
                ),
              ),
              if (label != null) ...[
                SizedBox(height: AppSpacing.x4.h),
                Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small spinner, sized to sit in a row of text or beside a control.
class AppInlineLoader extends StatelessWidget {
  const AppInlineLoader({super.key, this.size = 18, this.color});

  /// Raw design px.
  final double size;

  /// Defaults to [AppColors.brand].
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.w,
      height: size.w,
      child: CircularProgressIndicator(
        strokeWidth: 2.w,
        color: color ?? AppColors.brand,
      ),
    );
  }
}

/// One pulsing grey bar — the atom every skeleton is built from.
///
/// [width] is raw design px, or null to fill the available width. The pulse
/// runs at 900ms and stops entirely under reduced motion.
class AppSkeletonLine extends StatelessWidget {
  const AppSkeletonLine({
    super.key,
    this.width,
    this.height = 12,
    this.radius = AppRadius.sm,
  });

  /// Raw design px; null → `double.infinity`.
  final double? width;

  /// Raw design px.
  final double height;

  /// Raw radius px.
  final double radius;

  static const Duration _pulse = Duration(milliseconds: 900);

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: width == null ? double.infinity : width!.w,
      height: height.h,
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(radius.r),
      ),
    );

    // A viewer who asked for no animation gets a flat placeholder.
    if (reduceMotion(context)) return bar;

    return _Pulse(duration: _pulse, child: bar);
  }
}

/// A pulsing circle — the avatar slot in a skeleton row.
class AppSkeletonCircle extends StatelessWidget {
  const AppSkeletonCircle({super.key, this.size = 44});

  /// Raw design px.
  final double size;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: size.w,
      height: size.w,
      decoration: const BoxDecoration(
        color: AppColors.grey100,
        shape: BoxShape.circle,
      ),
    );
    if (reduceMotion(context)) return circle;
    return _Pulse(duration: const Duration(milliseconds: 900), child: circle);
  }
}

/// A skeleton shaped like the app's standard content card — the shape used by
/// the doctor card, the appointment card and the record card, so the
/// placeholder occupies the same space the real card will.
///
/// `surface` fill, `--radius-lg`, `--shadow-sm`, `16` padding: identical to
/// [AppCard], deliberately, so the swap to real content does not move anything.
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({
    super.key,
    this.hasAvatar = true,
    this.lines = 3,
    this.hasFooter = true,
  });

  /// Whether to reserve the leading avatar/thumbnail slot.
  final bool hasAvatar;

  /// How many text lines to draw in the body.
  final int lines;

  /// Whether to draw the divider + meta row at the bottom (the appointment
  /// card's date/time strip).
  final bool hasFooter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lg,
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasAvatar) ...[
                const AppSkeletonCircle(size: 52),
                SizedBox(width: AppSpacing.x3.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSkeletonLine(height: 16),
                    for (var i = 1; i < lines; i++) ...[
                      SizedBox(height: AppSpacing.x2.h),
                      AppSkeletonLine(
                        // Taper the lines so the block reads as prose.
                        width: i == lines - 1 ? 120 : null,
                        height: 12,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hasFooter) ...[
            SizedBox(height: AppSpacing.x3.h),
            Divider(height: 1.h, thickness: 1.h, color: AppColors.borderSubtle),
            SizedBox(height: AppSpacing.x3.h),
            Row(
              children: [
                const AppSkeletonLine(width: 88, height: 12),
                SizedBox(width: AppSpacing.x4.w),
                const AppSkeletonLine(width: 64, height: 12),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A skeleton shaped like a one-line list row (the search results row, the
/// document row, the dependant row): a leading circle, a title and a subtitle.
class AppSkeletonListTile extends StatelessWidget {
  const AppSkeletonListTile({super.key, this.hasAvatar = true});

  final bool hasAvatar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.x3.h),
      child: Row(
        children: [
          if (hasAvatar) ...[
            const AppSkeletonCircle(size: 44),
            SizedBox(width: AppSpacing.x3.w),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeletonLine(height: 14),
                SizedBox(height: AppSpacing.x2.h),
                const AppSkeletonLine(width: 140, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// [count] stacked [AppSkeletonCard]s — the whole-list placeholder a feed
/// shows on a cold load.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    super.key,
    this.count = 3,
    this.padding,
    this.itemGap = AppSpacing.x3,
    this.tile = false,
  });

  final int count;

  /// Defaults to the 20px screen gutter, vertically 16.
  final EdgeInsetsGeometry? padding;

  /// Raw design px between items.
  final double itemGap;

  /// Use [AppSkeletonListTile] instead of [AppSkeletonCard].
  final bool tile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: AppSpacing.x5.w,
            vertical: AppSpacing.x4.h,
          ),
      child: Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) SizedBox(height: itemGap.h),
            // Excluded from semantics: a screen reader should hear "loading",
            // announced once by AppLoadingView, not three fake cards.
            ExcludeSemantics(
              child: tile
                  ? const AppSkeletonListTile()
                  : const AppSkeletonCard(),
            ),
          ],
        ],
      ),
    );
  }
}

/// The opacity cycle behind every skeleton. One controller-free
/// implementation, so a list of skeletons does not spin up a ticker each.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child, required this.duration});

  final Widget child;
  final Duration duration;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> {
  double _target = 1;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.45, end: _target),
      duration: widget.duration,
      curve: Curves.easeInOut,
      onEnd: () {
        if (!mounted) return;
        setState(() => _target = _target == 1 ? 0.45 : 1);
      },
      builder: (context, value, child) =>
          Opacity(opacity: value, child: child),
      child: widget.child,
    );
  }
}
