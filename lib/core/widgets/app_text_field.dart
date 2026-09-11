import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';
import 'app_icon.dart';

/// A labelled text input. Stateless by design — the owning screen holds the
/// [TextEditingController] and any obscure-toggle state. Field: `h 52`,
/// `surfaceAlt` fill, 1px border (`danger` on error), `--radius-md`.
///
/// ## Added parameters (audit §3.5)
///
/// Everything below the original set is **additive with a safe default**, so
/// existing call sites are untouched:
///
/// | Parameter            | Why                                              |
/// |----------------------|--------------------------------------------------|
/// | [autofillHints]      | §3.5.5 — password managers and OS autofill       |
/// | [inputFormatters]    | §3.5.3 — stop letters reaching a phone field     |
/// | [maxLength]          | cap a PIN code / OTP at its real length          |
/// | [onSubmitted]        | let the keyboard's Done advance the form         |
/// | [enabled]            | a field that is read-only while saving           |
/// | [suffix]             | the eye toggle, a unit, a clear button           |
/// | [textCapitalization] | names capitalise, emails do not                  |
/// | [maxLines]           | an address or a note needs more than one line    |
///
/// A multi-line field ([maxLines] > 1) grows instead of staying at 52px, and
/// centres its text at the top rather than the middle.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.controller,
    this.onChanged,
    this.hintText,
    this.errorText,
    this.iconName,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.onSubmitted,
    this.enabled = true,
    this.suffix,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.helperText,
    this.semanticLabel,
    this.showError = false,
  });

  final String? label;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// Placeholder text.
  final String? hintText;
  final String? errorText;

  /// Optional leading [MedIcon] name.
  final String? iconName;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  /// OS/password-manager autofill hints, e.g.
  /// `[AutofillHints.password]`, `[AutofillHints.telephoneNumberNational]`.
  final Iterable<String>? autofillHints;

  /// Input filters — the cheapest way to stop bad input existing at all, e.g.
  /// `[FilteringTextInputFormatter.digitsOnly]`.
  final List<TextInputFormatter>? inputFormatters;

  /// Hard character cap. No counter is rendered (the design has none); this
  /// only limits input.
  final int? maxLength;

  /// Keyboard action handler ("Next" / "Done").
  final ValueChanged<String>? onSubmitted;

  /// False greys the field and ignores input.
  final bool enabled;

  /// Trailing widget inside the field — the eye toggle, a unit, "Verify".
  final Widget? suffix;

  final TextCapitalization textCapitalization;

  /// 1 keeps the fixed 52px field. Greater than 1 lets the field grow.
  final int maxLines;

  /// A quiet line under the field, shown when there is no [errorText].
  final String? helperText;

  /// Overrides what a screen reader announces for the field. Defaults to
  /// [label], then [hintText].
  final String? semanticLabel;

  /// Paints the error border **without** rendering a message line.
  ///
  /// For a composed control that shows one shared error beneath several fields
  /// (see `AppPhoneField`, where the dial-code chip and the number field share
  /// an error) — passing an empty [errorText] would reserve a blank line and
  /// knock the row out of alignment.
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final hasMessage = errorText != null;
    final hasError = hasMessage || showError;
    final isMultiline = maxLines > 1;

    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      obscureText: obscureText,
      keyboardType:
          keyboardType ?? (isMultiline ? TextInputType.multiline : null),
      textInputAction: textInputAction,
      autofillHints: enabled ? autofillHints : null,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      enabled: enabled,
      textCapitalization: textCapitalization,
      maxLines: obscureText ? 1 : maxLines,
      minLines: isMultiline ? maxLines : 1,
      cursorColor: AppColors.brand,
      textAlignVertical: isMultiline
          ? TextAlignVertical.top
          : TextAlignVertical.center,
      style: AppText.poppins(
        size: AppFontSize.body,
        color: enabled ? AppColors.textPrimary : AppColors.textMuted,
      ),
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        // The design has no character counter; maxLength still caps input.
        counterText: '',
        hintText: hintText,
        hintStyle: AppText.poppins(
          size: AppFontSize.body,
          color: AppColors.textMuted,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.medium,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        Container(
          // A single-line field keeps its exact 52px design height; a
          // multi-line one grows from the same top/bottom rhythm.
          height: isMultiline ? null : 52.h,
          constraints: isMultiline ? BoxConstraints(minHeight: 52.h) : null,
          padding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: isMultiline ? 14.h : 0,
          ),
          decoration: BoxDecoration(
            color: enabled ? AppColors.surfaceAlt : AppColors.grey100,
            borderRadius: AppRadii.md,
            border: Border.all(
              color: hasError ? AppColors.danger : AppColors.border,
              width: 1.w,
            ),
          ),
          child: Row(
            crossAxisAlignment: isMultiline
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (iconName != null) ...[
                AppIcon(iconName!, size: 20, color: AppColors.textMuted),
                SizedBox(width: 10.w),
              ],
              Expanded(
                child: Semantics(
                  textField: true,
                  label: semanticLabel ?? label ?? hintText,
                  child: field,
                ),
              ),
              if (suffix != null) ...[SizedBox(width: 8.w), suffix!],
            ],
          ),
        ),
        if (hasMessage) ...[
          SizedBox(height: 6.h),
          Text(
            errorText!,
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.danger,
            ),
          ),
        ] else if (helperText != null) ...[
          SizedBox(height: 6.h),
          Text(
            helperText!,
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
