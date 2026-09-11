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
///
/// ## [loading] — the double-tap fix (audit §3.5.6)
///
/// The audit found that tapping "Confirm and Pay" twice created two bookings.
/// Set [loading] while the request is in flight: the label is replaced by a
/// spinner **and taps are ignored**, so the button cannot fire twice. The flag
/// is additive and defaults to false, so existing call sites are unaffected.
///
/// ```dart
/// AppButton(
///   label: 'Confirm and Pay',
///   loading: state.isSubmitting,
///   onPressed: () => controller.confirm(),
/// )
/// ```
///
/// The button reserves the label's width while loading, so the layout does not
/// jump when the spinner appears.
///
/// ## Touch target (audit §3.3.8)
///
/// `AppButtonSize.sm` is 38px tall in the design, below the 48px platform
/// minimum. The **visual** button is still drawn at 38px — the design is
/// unchanged — but it is centred inside a [minTapHeight] (48) box, so it is
/// reachable by an average fingertip. The only consequence is that an `sm`
/// button now *occupies* 48px of height instead of 38, which grows the cards
/// that contain one (the record card and the notification card) by 10px.
/// `md` (48) and `lg` (54) are already at or above the floor and are
/// completely unaffected.
///
/// Set [expandHitArea] to false only for an `sm` button inside a row whose
/// height is already fixed at 38 and which would otherwise overflow — and say
/// why in a comment, because it reintroduces the accessibility failure.
///
/// ## [stubbed] — the honest-control presentation (audit §4.1)
///
/// For a control whose action genuinely cannot happen in this build. It renders
/// the button at reduced emphasis with a small "demo" marker and announces
/// itself to a screen reader as unavailable, so it does not *look* like a
/// working control. Pair it with `showStubbedToast` from
/// `app_stub_notice.dart` in [onPressed] — a stubbed button says what it is;
/// it never fires a success toast for something that did not happen.
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
    this.loading = false,
    this.stubbed = false,
    this.semanticLabel,
    this.expandHitArea = true,
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

  /// True while the button's action is running: shows a spinner and **blocks
  /// repeat taps**. Additive; defaults to false.
  final bool loading;

  /// True for a control whose action is not implemented in this build. Renders
  /// at reduced emphasis with a "demo" marker; still tappable, so it can
  /// explain itself via `showStubbedToast`.
  final bool stubbed;

  /// Accessible label, when the visible [label] is not the whole story
  /// ("Delete" on a row → "Delete Ava Johnson"). Defaults to [label].
  final String? semanticLabel;

  /// Whether the tap target is padded out to [minTapHeight]. Defaults to true;
  /// see the touch-target note in the class doc before turning it off.
  final bool expandHitArea;

  /// Platform minimum tap target.
  static const double minTapHeight = 48;

  /// True when the button will not fire — used by tests and by callers that
  /// need to mirror the state elsewhere.
  bool get isInert => disabled || loading || onPressed == null;

  @override
  Widget build(BuildContext context) {
    final inert = isInert;

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

    final row = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          AppIcon(leadingIcon!, size: iconSz, color: fg),
          SizedBox(width: gap.w),
        ],
        labelWidget,
        if (stubbed) ...[SizedBox(width: gap.w), _DemoMarker(color: fg)],
        if (trailingIcon != null) ...[
          SizedBox(width: gap.w),
          AppIcon(trailingIcon!, size: iconSz, color: fg),
        ],
      ],
    );

    // While loading, the label row stays in the tree (invisible) so the button
    // keeps its width and nothing around it reflows.
    final Widget inner = loading
        ? Stack(
            alignment: Alignment.center,
            children: [
              Opacity(opacity: 0, child: row),
              SizedBox(
                width: (fs + 4).w,
                height: (fs + 4).w,
                child: CircularProgressIndicator(strokeWidth: 2.w, color: fg),
              ),
            ],
          )
        : row;

    final visual = Container(
      height: h.h,
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: padH.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: pill ? AppRadii.pill : AppRadii.md,
        border: border,
      ),
      child: inner,
    );

    // The 38px `sm` button is centred inside a 48px target. Paint is unchanged;
    // only the occupied height grows, and only for `sm`.
    final content = (expandHitArea && h < minTapHeight)
        ? SizedBox(
            height: minTapHeight.h,
            width: fullWidth ? double.infinity : null,
            child: Center(widthFactor: fullWidth ? null : 1.0, child: visual),
          )
        : visual;

    return Semantics(
      button: true,
      enabled: !inert,
      label: semanticLabel ?? label,
      // Both states are announced, because a silent disabled button and a
      // silent busy button are the two cases users report as "nothing happens".
      hint: switch ((loading, stubbed, disabled)) {
        (true, _, _) => 'Busy',
        (_, true, _) => 'Not available in this demo',
        (_, _, true) => 'Unavailable',
        _ => null,
      },
      child: ExcludeSemantics(
        child: Opacity(
          // Stubbed sits between enabled and disabled: visibly quieter, still
          // reachable so it can explain itself.
          opacity: disabled ? 0.5 : (stubbed ? 0.72 : 1.0),
          child: _PressScale(
            onTap: inert ? null : onPressed,
            enabled: !inert,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// The small "demo" pill on a [AppButton.stubbed] button. Deliberately plain —
/// it marks the control without competing with the label.
class _DemoMarker extends StatelessWidget {
  const _DemoMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
      decoration: BoxDecoration(
        borderRadius: AppRadii.pill,
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.w),
      ),
      child: Text(
        'demo',
        style: AppText.poppins(
          size: AppFontSize.xxs,
          weight: AppText.medium,
          color: color,
        ),
      ),
    );
  }
}

/// Tap-down scale feedback. Scales the child to `0.98` while pressed, ignoring
/// input entirely when [enabled] is false.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, this.onTap, this.enabled = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  /// The pressed scale. Fixed rather than a parameter — every button in the
  /// design uses the same 0.98.
  static const double scale = 0.98;

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
