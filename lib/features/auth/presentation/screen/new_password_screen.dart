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
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/field_focus_group.dart';
import '../components/new_password_fields.dart';
import '../components/screen_fade_rise.dart';
import '../controllers/auth_flow_draft.dart';
import '../controllers/reset_form_controller.dart';
import '../controllers/verify_request.dart';

/// New Password (`/reset`) — the last step of the **logged-out** reset flow.
///
/// This is not the signed-in change-password screen: that one is
/// `change_password_screen.dart` (CM-51), which asks for the current password
/// because a signed-in session is not proof of intent. The two share
/// [NewPasswordFields] — the new + confirm pair, with the show/hide eye, the
/// `newPassword` autofill hint and the live "passwords do not match" recheck —
/// and nothing else.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  late final Map<String, TextEditingController> _controllers = {
    ResetFields.password: _password,
    ResetFields.confirm: _confirm,
  };

  late final FieldFocusGroup _focus = FieldFocusGroup(
    onBlur: (field) => _form.onBlur(field, _controllers[field]?.text ?? ''),
  );

  ResetFormController get _form =>
      ref.read(resetFormControllerProvider.notifier);

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFieldChanged(String field, String value) {
    if (field == ResetFields.password) {
      _form.onPasswordChanged(value, confirm: _confirm.text);
      return;
    }
    _form.onChanged(field, value);
  }

  Future<void> _submit() async {
    _focus.unfocus();
    if (!_form.validateForm(password: _password.text, confirm: _confirm.text)) {
      return;
    }
    final changed = await _form.submit(password: _password.text);
    if (!changed || !mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show('Password reset — please log in');
    context.go(AppRoutes.login);
  }

  /// Back goes to the code step the user came from, carrying the same draft so
  /// `/verify` still knows where the code was sent.
  String get _backPath {
    final draft = ref.read(passwordResetDraftProvider);
    if (draft == null) return AppRoutes.forgot;
    return VerifyRequest(
      purpose: VerifyPurpose.passwordReset,
      channel: draft.channel,
      destination: draft.destination,
    ).path;
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(resetFormControllerProvider);
    final failure = form.failure;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ScreenFadeRise(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInnerHeader(
                title: 'New Password',
                onBack: () => context.go(_backPath),
                bottomGap: 8,
                background: AppColors.surface,
                backSemanticLabel: 'Back to the verification code',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 32.h),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Create a new password for your account.',
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
                        NewPasswordFields(
                          passwordField: ResetFields.password,
                          confirmField: ResetFields.confirm,
                          passwordController: _password,
                          confirmController: _confirm,
                          state: form,
                          focus: _focus,
                          onChanged: _onFieldChanged,
                          onSubmit: _submit,
                          enabled: !form.isBusy,
                        ),
                        SizedBox(height: 24.h),
                        AppButton(
                          label: 'Reset Password',
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
    );
  }
}
