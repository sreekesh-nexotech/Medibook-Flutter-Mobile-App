import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/config/constants.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';
import 'app_icon.dart';

/// Fill/emphasis variants for [AppButton] (DESIGN-SPEC §3).
enum AppButtonVariant { primary, secondary, ghost, danger, soft }

/// Height/typography sizes for [AppButton].
enum AppButtonSize { sm, md, lg }

/// The primary call-to-action button. Data + callback in, styled pill/rounded
/// button out. Press feedback scales to `0.98`; [disabled] dims to 0.5 and
/// ignores taps.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.pill = false,
    this.fullWidth = false,
    this.leadingIcon,
    this.trailingIcon,
    this.disabled = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool pill;
  final bool fullWidth;

  /// Optional leading [MedIcon] name.
  final String? leadingIcon;

  /// Optional trailing [MedIcon] name.
  final String? trailingIcon;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final inert = disabled || onPressed == null;

    // Size tokens (raw design px; ScreenUtil-scaled at use).
    final double h;
    final double padH;
    final double fs;
    final double gap;
    final double iconSz;
    switch (size) {
      case AppButtonSize.sm:
        h = 38;
        padH = 16;
        fs = 13;
        gap = 6;
        iconSz = 16;
      case AppButtonSize.md:
        h = 48;
        padH = 22;
        fs = 16;
        gap = 8;
        iconSz = 18;
      case AppButtonSize.lg:
        h = 54;
        padH = 26;
        fs = 16;
        gap = 10;
        iconSz = 20;
    }

    // Variant colors + border.
    final Color bg;
    final Color fg;
    Border? border;
    switch (variant) {
      case AppButtonVariant.primary:
        bg = AppColors.brand;
        fg = AppColors.textOnBrand;
        border = Border.all(color: AppColors.brand, width: 1.w);
      case AppButtonVariant.secondary:
        bg = Colors.transparent;
        fg = AppColors.brand;
        border = Border.all(color: AppColors.brand, width: 1.5.w);
      case AppButtonVariant.ghost:
        bg = Colors.transparent;
        fg = AppColors.brand;
      case AppButtonVariant.danger:
        bg = AppColors.danger;
        fg = AppColors.textOnBrand;
      case AppButtonVariant.soft:
        bg = AppColors.surfaceTint;
        fg = AppColors.brand;
    }

    Widget labelWidget = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.poppins(size: fs, weight: AppText.semibold, color: fg),
    );
    // Only allow the label to flex when the row is bounded (fullWidth).
    if (fullWidth) labelWidget = Flexible(child: labelWidget);

    final content = Container(
      height: h.h,
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: padH.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: pill ? AppRadii.pill : AppRadii.md,
        border: border,
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (leadingIcon != null) ...[
            AppIcon(leadingIcon!, size: iconSz, color: fg),
            SizedBox(width: gap.w),
          ],
          labelWidget,
          if (trailingIcon != null) ...[
            SizedBox(width: gap.w),
            AppIcon(trailingIcon!, size: iconSz, color: fg),
          ],
        ],
      ),
    );

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: _PressScale(
        onTap: inert ? null : onPressed,
        enabled: !inert,
        child: content,
      ),
    );
  }
}

/// Tap-down scale feedback. Scales the child to [scale] while pressed, ignoring
/// input entirely when [enabled] is false.
class _PressScale extends StatefulWidget {
  const _PressScale({
    required this.child,
    this.onTap,
    this.scale = 0.98,
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
