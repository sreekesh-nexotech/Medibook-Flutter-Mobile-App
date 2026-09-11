import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/auth_fields.dart';
import '../components/field_focus_group.dart';
import '../components/new_password_fields.dart';
import '../components/screen_fade_rise.dart';
import '../controllers/change_password_form_controller.dart';

/// Change Password (`/change-password`) — CM-51.
///
/// The audit found *"a new-password screen exists, but only in the logged-out
/// reset flow. Profile has no entry point and no current-password field"*.
/// This is the signed-in screen, and the **current-password field** is the
/// substantive difference: being signed in is not proof of intent — a
/// borrowed, unlocked phone is exactly the case it defends against — so the
/// old password is required, and a wrong one is reported against that field
/// rather than as a form-level error.
///
/// What it shares with `/reset` is [NewPasswordFields], the new + confirm
/// pair; what it does not share is the controller, the current-password field
/// and the destination. Leaving with half-typed passwords asks first, via
/// [AppUnsavedChangesGuard].
///
/// The Profile entry point is wired by the profile feature; this screen only
/// has to exist at [AppRoutes.changePassword].
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  late final Map<String, TextEditingController> _controllers = {
    ChangePasswordFields.current: _current,
    ChangePasswordFields.password: _password,
    ChangePasswordFields.confirm: _confirm,
  };

  late final FieldFocusGroup _focus = FieldFocusGroup(
    onBlur: (field) => _form.onBlur(field, _controllers[field]?.text ?? ''),
  );

  ChangePasswordFormController get _form =>
      ref.read(changePasswordFormControllerProvider.notifier);

  bool get _hasUnsavedChanges =>
      _current.text.isNotEmpty ||
      _password.text.isNotEmpty ||
      _confirm.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // The guard reads the three fields, so it has to be rebuilt as they change.
    for (final controller in _controllers.values) {
      controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller
        ..removeListener(_onTextChanged)
        ..dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  void _onFieldChanged(String field, String value) {
    if (field == ChangePasswordFields.password) {
      _form.onPasswordChanged(value, confirm: _confirm.text);
      return;
    }
    _form.onChanged(field, value);
  }

  void _discard() {
    for (final controller in _controllers.values) {
      controller.clear();
    }
    _form.reset();
  }

  /// Leaves the form.
  ///
  /// `Navigator.maybePop`, **not** `context.pop()`: go_router's `pop` calls
  /// `NavigatorState.pop` directly and so bypasses the `PopScope` that
  /// [AppUnsavedChangesGuard] installs. Using it here would mean the system
  /// back gesture warns about unsaved work while this screen's own Back and
  /// Cancel silently discard it.
  void _close() {
    if (context.canPop()) {
      Navigator.maybePop(context);
    } else {
      context.go(AppRoutes.profile);
    }
  }

  Future<void> _submit() async {
    _focus.unfocus();
    if (!_form.validateForm(
      current: _current.text,
      password: _password.text,
      confirm: _confirm.text,
    )) {
      return;
    }

    final changed = await _form.submit(
      current: _current.text,
      password: _password.text,
    );
    if (!changed || !mounted) return;

    _discard();
    ref.read(toastControllerProvider.notifier).show('Password updated');
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(changePasswordFormControllerProvider);
    final failure = form.failure;

    return AppUnsavedChangesGuard(
      hasUnsavedChanges: _hasUnsavedChanges && !form.isBusy,
      onDiscard: _discard,
      title: 'Discard this password change?',
      consequence: 'Your password has not been changed yet.',
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: ScreenFadeRise(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppInnerHeader(
                  title: 'Change Password',
                  onBack: _close,
                  bottomGap: 8,
                  background: AppColors.surface,
                  backSemanticLabel: 'Back to Profile',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 32.h),
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Enter your current password, then choose a new '
                            'one. You will stay signed in on this device.',
                            style: AppText.poppins(
                              size: AppFontSize.base,
                              color: AppColors.textBody,
                              height: 1.55,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          if (failure != null) ...[
                            AppInlineError(failure: failure),
                            SizedBox(height: 16.h),
                          ],
                          AuthPasswordField(
                            field: ChangePasswordFields.current,
                            label: 'Current Password',
                            controller: _current,
                            state: form,
                            focus: _focus,
                            onChanged: _onFieldChanged,
                            hintText: 'Your current password',
                            enabled: !form.isBusy,
                            onEditingComplete: () => _focus.requestFocus(
                              ChangePasswordFields.password,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          NewPasswordFields(
                            passwordField: ChangePasswordFields.password,
                            confirmField: ChangePasswordFields.confirm,
                            passwordController: _password,
                            confirmController: _confirm,
                            state: form,
                            focus: _focus,
                            onChanged: _onFieldChanged,
                            onSubmit: _submit,
                            confirmLabel: 'Confirm New Password',
                            enabled: !form.isBusy,
                          ),
                          SizedBox(height: 24.h),
                          AppButton(
                            label: 'Update Password',
                            fullWidth: true,
                            loading: form.isBusy,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
