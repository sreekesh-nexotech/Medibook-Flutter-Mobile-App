import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/app_password_field.dart';
import '../../../../core/widgets/app_phone_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/auth_form_controller.dart';
import 'field_focus_group.dart';

/// The design-system inputs, bound to an [AuthFormState] by field key.
///
/// Every auth screen wires the same four things to every field — its error
/// from the form state, its [FocusNode] from the screen's [FieldFocusGroup],
/// its `onChanged` back to the controller, and the `next`/`done` action that
/// moves the keyboard on. Writing that out per field is where the
/// inconsistencies the audit found crept in (§3.5.3 a field with no rule,
/// §3.5.4 an error that never re-checks, §3.5.5 a password with no autofill),
/// so it is wired once here.
///
/// These are thin wrappers, not new controls: the visuals, sizing and
/// behaviour are entirely [AppTextField] / [AppPasswordField] /
/// [AppPhoneField] from the design system.
///
/// ```dart
/// AuthTextField(
///   field: SignupFields.email,
///   label: 'Email',
///   controller: _email,
///   state: form,
///   focus: _focus,
///   onChanged: _onFieldChanged,
///   keyboardType: TextInputType.emailAddress,
///   autofillHints: const [AutofillHints.email],
///   onEditingComplete: () => _focus.requestFocus(SignupFields.phone),
/// )
/// ```
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.field,
    required this.label,
    required this.controller,
    required this.state,
    required this.focus,
    required this.onChanged,
    this.hintText,
    this.helperText,
    this.keyboardType,
    this.autofillHints,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.onEditingComplete,
    this.onSubmit,
    this.enabled = true,
  });

  /// The key this field is validated and keyed by.
  final String field;

  final String label;
  final TextEditingController controller;

  /// The owning form's state — the source of this field's error text.
  final AuthFormState state;

  final FieldFocusGroup focus;

  /// Reports every keystroke as `(field, value)` to the form controller.
  final void Function(String field, String value) onChanged;

  final String? hintText;
  final String? helperText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final TextCapitalization textCapitalization;

  /// Where the keyboard's "next" goes. Null → this is the last field and the
  /// action becomes "done".
  final VoidCallback? onEditingComplete;

  /// Submits the form — used when this is the last field.
  final VoidCallback? onSubmit;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isLast = onEditingComplete == null;
    return AppTextField(
      label: label,
      controller: controller,
      focusNode: focus.node(field),
      errorText: state.errorOf(field),
      helperText: helperText,
      hintText: hintText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      enabled: enabled,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onChanged: (value) => onChanged(field, value),
      onSubmitted: (_) => isLast ? onSubmit?.call() : onEditingComplete?.call(),
    );
  }
}

/// [AppPasswordField] bound to an [AuthFormState] — the show/hide eye and the
/// autofill hints come with it (audit §3.5.5).
class AuthPasswordField extends StatelessWidget {
  const AuthPasswordField({
    super.key,
    required this.field,
    required this.label,
    required this.controller,
    required this.state,
    required this.focus,
    required this.onChanged,
    this.hintText,
    this.helperText,
    this.isNewPassword = false,
    this.onEditingComplete,
    this.onSubmit,
    this.enabled = true,
  });

  final String field;
  final String label;
  final TextEditingController controller;
  final AuthFormState state;
  final FieldFocusGroup focus;
  final void Function(String field, String value) onChanged;
  final String? hintText;
  final String? helperText;

  /// True on sign-up, reset and change-password, so a password manager offers
  /// to generate and save rather than to fill.
  final bool isNewPassword;

  final VoidCallback? onEditingComplete;
  final VoidCallback? onSubmit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isLast = onEditingComplete == null;
    return AppPasswordField(
      label: label,
      controller: controller,
      focusNode: focus.node(field),
      errorText: state.errorOf(field),
      helperText: helperText,
      hintText: hintText,
      isNewPassword: isNewPassword,
      enabled: enabled,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onChanged: (value) => onChanged(field, value),
      onSubmitted: (_) => isLast ? onSubmit?.call() : onEditingComplete?.call(),
    );
  }
}

/// [AppPhoneField] bound to an [AuthFormState] — the country-code chip, the
/// digits-only formatter and `Validators.phone` come with it (audit §3.5.3).
class AuthPhoneField extends StatelessWidget {
  const AuthPhoneField({
    super.key,
    required this.field,
    required this.controller,
    required this.countryCode,
    required this.onCountryChanged,
    required this.state,
    required this.focus,
    required this.onChanged,
    this.label = 'Mobile Number',
    this.helperText,
    this.onEditingComplete,
    this.onSubmit,
    this.enabled = true,
  });

  final String field;
  final TextEditingController controller;
  final CountryCode countryCode;
  final ValueChanged<CountryCode> onCountryChanged;
  final AuthFormState state;
  final FieldFocusGroup focus;
  final void Function(String field, String value) onChanged;
  final String label;
  final String? helperText;
  final VoidCallback? onEditingComplete;
  final VoidCallback? onSubmit;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isLast = onEditingComplete == null;
    return AppPhoneField(
      label: label,
      controller: controller,
      countryCode: countryCode,
      onCountryChanged: onCountryChanged,
      focusNode: focus.node(field),
      errorText: state.errorOf(field),
      helperText: helperText,
      enabled: enabled,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onChanged: (value) => onChanged(field, value),
      onSubmitted: (_) => isLast ? onSubmit?.call() : onEditingComplete?.call(),
    );
  }
}
