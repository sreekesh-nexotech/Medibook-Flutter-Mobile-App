import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/config/constants.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import 'app_icon.dart';

/// Surface variants for [AppIconButton].
enum AppIconButtonVariant { plain, onBrand, tint, outline }

/// A circular, single-glyph tap target (back, bell, edit …). Press feedback
/// scales to `0.92`.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.iconSize,
    this.variant = AppIconButtonVariant.plain,
  });

  /// A [MedIcon] name.
  final String icon;
  final VoidCallback? onPressed;
  final double size;

  /// Defaults to `round(size * 0.5)`.
  final double? iconSize;
  final AppIconButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final resolvedIcon = iconSize ?? (size * 0.5).roundToDouble();

    final Color bg;
    final Color fg;
    Border? border;
    switch (variant) {
      case AppIconButtonVariant.plain:
        bg = Colors.transparent;
        fg = AppColors.brand;
      case AppIconButtonVariant.onBrand:
        bg = Colors.transparent;
        fg = AppColors.textOnBrand;
      case AppIconButtonVariant.tint:
        bg = AppColors.surfaceTint;
        fg = AppColors.brand;
      case AppIconButtonVariant.outline:
        bg = AppColors.surface;
        fg = AppColors.brand;
        border = Border.all(color: AppColors.border, width: 1.w);
    }

    final content = Container(
      width: size.w,
      height: size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.pill,
        border: border,
      ),
      child: AppIcon(icon, size: resolvedIcon, color: fg),
    );

    return _PressScale(
      onTap: onPressed,
      enabled: onPressed != null,
      child: content,
    );
  }
}

/// Tap-down scale feedback (`0.92` for icon buttons).
class _PressScale extends StatefulWidget {
  const _PressScale({
    required this.child,
    this.onTap,
    this.scale = 0.92,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool enabled;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _down = false;

  void _set(bool value) {
    if (widget.enabled && _down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: active ? widget.onTap : null,
      onTapDown: active ? (_) => _set(true) : null,
      onTapUp: active ? (_) => _set(false) : null,
      onTapCancel: active ? () => _set(false) : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: AppConstants.pressScale,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
