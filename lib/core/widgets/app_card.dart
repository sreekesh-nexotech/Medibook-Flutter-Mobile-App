import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/config/constants.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';

/// Radius tokens selectable on [AppCard].
enum AppRadiusToken { sm, md, lg, xl }

/// Shadow tokens selectable on [AppCard].
enum AppShadowToken { none, xs, sm, md, lg }

/// The base white surface every screen is composed on. Defaults to the
/// `--radius-lg` / `--shadow-sm` card look. When [onTap] is provided the card
/// becomes a tap target with `0.98` press feedback.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadiusToken.lg,
    this.shadow = AppShadowToken.sm,
    this.onTap,
    this.border,
    this.color,
  });

  final Widget child;

  /// Defaults to `EdgeInsets.all(16.w)`.
  final EdgeInsetsGeometry? padding;
  final AppRadiusToken radius;
  final AppShadowToken shadow;
  final VoidCallback? onTap;

  /// Optional border for selected states.
  final Border? border;

  /// Defaults to [AppColors.surface].
  final Color? color;

  BorderRadius get _radius => switch (radius) {
    AppRadiusToken.sm => AppRadii.sm,
    AppRadiusToken.md => AppRadii.md,
    AppRadiusToken.lg => AppRadii.lg,
    AppRadiusToken.xl => AppRadii.xl,
  };

  List<BoxShadow>? get _shadow => switch (shadow) {
    AppShadowToken.none => null,
    AppShadowToken.xs => AppShadows.xs,
    AppShadowToken.sm => AppShadows.sm,
    AppShadowToken.md => AppShadows.md,
    AppShadowToken.lg => AppShadows.lg,
  };

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding ?? EdgeInsets.all(AppSpacing.x4.w),
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: _radius,
        boxShadow: _shadow,
        border: border,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return _PressScale(onTap: onTap, child: content);
  }
}

/// Tap-down scale feedback for interactive cards.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, this.onTap, this.scale = 0.98});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: AppConstants.pressScale,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
