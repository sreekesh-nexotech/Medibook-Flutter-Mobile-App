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
///
/// ## Accessibility (audit §3.3.1, §3.3.8)
///
/// An icon-only control has no text for a screen reader, so this widget is
/// always labelled:
///
/// * Pass [semanticLabel] whenever the action is specific ("Download blood
///   test report"). **Strongly encouraged** — it is the only thing a
///   non-sighted user hears.
/// * When it is omitted, a sensible default is derived from the [MedIcon] name
///   ([defaultSemanticLabel]), so no icon button is ever silent. That fallback
///   exists to make the audit fix apply to every existing call site at once;
///   it is not an excuse to leave the label off new ones.
///
/// The **hit area** is [hitAreaSize] (48 by default, the platform minimum)
/// while the **visual** circle stays [size]. The glyph therefore looks exactly
/// as designed — a 38px back button is still 38px of paint — but it is
/// reachable by an average fingertip. Only the space the widget occupies
/// grows; nothing about it is redrawn.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.iconSize,
    this.variant = AppIconButtonVariant.plain,
    this.semanticLabel,
    this.hitAreaSize = 48,
  });

  /// A [MedIcon] name.
  final String icon;
  final VoidCallback? onPressed;

  /// Visual diameter, in raw design px. Unchanged by the hit-area rule.
  final double size;

  /// Defaults to `round(size * 0.5)`.
  final double? iconSize;
  final AppIconButtonVariant variant;

  /// What a screen reader announces. Defaults to [defaultSemanticLabel].
  final String? semanticLabel;

  /// Minimum tap target, in raw design px. 48 is the Material/HIG floor and
  /// the audit's §3.3.8 requirement; the visual circle is unaffected. Lower it
  /// only for a glyph inside an already-large tappable row, where the row
  /// itself is the target.
  final double hitAreaSize;

  /// The label used when [semanticLabel] is omitted, derived from the icon.
  ///
  /// Covers every glyph in [MedIcon]; anything unmapped falls back to
  /// `"<name> button"`, which is still better than silence.
  static String defaultSemanticLabel(String icon) => switch (icon) {
    MedIcon.back => 'Back',
    MedIcon.close || MedIcon.closeCircle => 'Close',
    MedIcon.bell => 'Notifications',
    MedIcon.search => 'Search',
    MedIcon.edit => 'Edit',
    MedIcon.download => 'Download',
    MedIcon.eye => 'View',
    MedIcon.calendar => 'Calendar',
    MedIcon.clock => 'Time',
    MedIcon.location => 'Location',
    MedIcon.logout => 'Log out',
    MedIcon.moon => 'Dark mode',
    MedIcon.star => 'Rating',
    MedIcon.video => 'Video consultation',
    MedIcon.hospital => 'Hospital',
    MedIcon.bag => 'Services',
    MedIcon.records => 'Records',
    _ => '${icon.replaceAll('-', ' ')} button',
  };

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

    final visual = Container(
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

    // The visual circle, centred inside a target at least `hitAreaSize` across.
    // Paint is unchanged; only the tappable box grows.
    final target = hitAreaSize <= size
        ? visual
        : SizedBox(
            width: hitAreaSize.w,
            height: hitAreaSize.w,
            child: Center(child: visual),
          );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel ?? defaultSemanticLabel(icon),
      child: ExcludeSemantics(
        child: _PressScale(
          onTap: onPressed,
          enabled: onPressed != null,
          child: target,
        ),
      ),
    );
  }
}

/// Tap-down scale feedback (`0.92` for icon buttons).
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, this.onTap, this.enabled = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  /// The pressed scale. Fixed rather than a parameter — every icon button in
  /// the design uses the same 0.92.
  static const double scale = 0.92;

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
        scale: _down ? _PressScale.scale : 1.0,
        duration: AppConstants.pressScale,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
