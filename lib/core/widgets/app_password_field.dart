import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/localization/l10n.dart';
import '../../app/theme/colors.dart';
import 'app_icon.dart';
import 'app_text_field.dart';

/// A password input: [AppTextField] plus the **show/hide eye toggle** and the
/// OS/password-manager autofill hints (audit §3.5.5 — the sign-in and sign-up
/// password fields had neither, so a mistyped password could not be checked and
/// a password manager could not fill it).
///
/// Stateful only for the toggle. The text itself still lives in the caller's
/// [TextEditingController], matching [AppTextField]'s contract — the screen
/// owns the value, the widget owns nothing but whether the dots are showing.
///
/// The eye is a real labelled button ("Show password" / "Hide password") with a
/// 48px tap target, so it is reachable by touch and announced correctly.
///
/// ```dart
/// AppPasswordField(
///   label: 'Password',
///   controller: controller,
///   errorText: state.passwordError,
///   isNewPassword: false,
///   textInputAction: TextInputAction.done,
///   onSubmitted: (_) => controller.submit(),
/// )
/// ```
class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    super.key,
    this.label = 'Password',
    this.controller,
    this.onChanged,
    this.hintText,
    this.errorText,
    this.helperText,
    this.iconName,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.isNewPassword = false,
    this.autofillHints,
  });

  final String? label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final String? hintText;
  final String? errorText;
  final String? helperText;

  /// Optional leading [MedIcon] name (the design uses none on auth screens).
  final String? iconName;

  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  /// True on sign-up and reset forms.
  ///
  /// Drives the autofill hint: `newPassword` tells the OS to *offer to
  /// generate and save* one, while `password` tells it to fill the existing
  /// one. Using the wrong hint is why password managers sometimes save a
  /// sign-in as a new credential.
  final bool isNewPassword;

  /// Overrides the hint chosen from [isNewPassword].
  final Iterable<String>? autofillHints;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscured = true;

  void _toggle() => setState(() => _obscured = !_obscured);

  @override
  Widget build(BuildContext context) {
    final strings = context.l10n;

    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      onChanged: widget.onChanged,
      hintText: widget.hintText,
      errorText: widget.errorText,
      helperText: widget.helperText,
      iconName: widget.iconName,
      obscureText: _obscured,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      focusNode: widget.focusNode,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      autofillHints:
          widget.autofillHints ??
          (widget.isNewPassword
              ? const [AutofillHints.newPassword]
              : const [AutofillHints.password]),
      suffix: _EyeToggle(
        obscured: _obscured,
        onTap: widget.enabled ? _toggle : null,
        showLabel: strings.showPassword,
        hideLabel: strings.hidePassword,
      ),
    );
  }
}

/// The show/hide control. Visual glyph is 20px, as the design's field icons
/// are; the tap target is 48px, centred on it (audit §3.3.8).
class _EyeToggle extends StatelessWidget {
  const _EyeToggle({
    required this.obscured,
    required this.showLabel,
    required this.hideLabel,
    this.onTap,
  });

  final bool obscured;
  final String showLabel;
  final String hideLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      // Announces the action, not the state — "Show password" is what tapping
      // it will do.
      label: obscured ? showLabel : hideLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 48.w,
            height: 48.h,
            child: Center(
              child: AppIcon(
                // The filled glyph reads as "currently visible".
                obscured ? MedIcon.eye : MedIcon.bold(MedIcon.eye),
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
