import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../controllers/auth_form_controller.dart';
import 'auth_fields.dart';
import 'field_focus_group.dart';

/// The "new password" + "confirm password" pair, shared by the logged-out
/// reset screen (`/reset`) and the signed-in change-password screen
/// (`/change-password`, CM-51).
///
/// The two screens are deliberately *not* one screen — CM-51's whole point is
/// the current-password field the reset flow must not have, and the two submit
/// to different places — but the pair of fields below that is identical, down
/// to the `newPassword` autofill hint and the `next`/`done` chaining. This is
/// the part worth sharing: a widget, not logic, so neither controller has to
/// know about the other.
///
/// Both fields are [AuthPasswordField], so the show/hide eye and the autofill
/// hints come with them (audit §3.5.5), and both report every keystroke to
/// [onChanged] so a "passwords do not match" error clears as soon as either
/// half is fixed rather than on the first keystroke (audit §3.5.4).
class NewPasswordFields extends StatelessWidget {
  const NewPasswordFields({
    super.key,
    required this.passwordField,
    required this.confirmField,
    required this.passwordController,
    required this.confirmController,
    required this.state,
    required this.focus,
    required this.onChanged,
    required this.onSubmit,
    this.passwordLabel = 'New Password',
    this.confirmLabel = 'Confirm Password',
    this.passwordHelperText = 'At least 6 characters',
    this.enabled = true,
  });

  /// The owning controller's field key for the new password.
  final String passwordField;

  /// The owning controller's field key for the confirmation.
  final String confirmField;

  final TextEditingController passwordController;
  final TextEditingController confirmController;

  final AuthFormState state;
  final FieldFocusGroup focus;

  /// Reports `(field, value)` to the form controller on every keystroke.
  final void Function(String field, String value) onChanged;

  /// Submits the form — the confirm field is the last one, so its keyboard
  /// action is "done".
  final VoidCallback onSubmit;

  final String passwordLabel;
  final String confirmLabel;
  final String? passwordHelperText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthPasswordField(
          field: passwordField,
          label: passwordLabel,
          controller: passwordController,
          state: state,
          focus: focus,
          onChanged: onChanged,
          hintText: passwordHelperText,
          helperText: state.errorOf(passwordField) == null
              ? passwordHelperText
              : null,
          isNewPassword: true,
          enabled: enabled,
          onEditingComplete: () => focus.requestFocus(confirmField),
        ),
        SizedBox(height: 16.h),
        AuthPasswordField(
          field: confirmField,
          label: confirmLabel,
          controller: confirmController,
          state: state,
          focus: focus,
          onChanged: onChanged,
          hintText: 'Repeat the password',
          isNewPassword: true,
          enabled: enabled,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}
