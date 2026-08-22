import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:medibook/app/router/app_routes.dart';
import 'package:medibook/app/theme/colors.dart';
import 'package:medibook/app/theme/typography.dart';
import 'package:medibook/core/widgets/app_button.dart';
import 'package:medibook/core/widgets/app_inner_header.dart';
import 'package:medibook/core/widgets/app_text_field.dart';
import 'package:medibook/core/widgets/toast/toast_controller.dart';
import 'package:medibook/features/auth/presentation/components/screen_fade_rise.dart';
import 'package:medibook/features/auth/presentation/controllers/reset_form_controller.dart';

/// New Password (`/reset`). Back → Verify. Reset Password → Login + toast.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _reset() {
    final valid = ref
        .read(resetFormControllerProvider.notifier)
        .validate(password: _password.text, confirm: _confirm.text);
    if (!valid) return;
    ref
        .read(toastControllerProvider.notifier)
        .show('Password reset — please log in');
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final errors = ref.watch(resetFormControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ScreenFadeRise(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInnerHeader(
                title: 'New Password',
                onBack: () => context.go(AppRoutes.verify),
                bottomGap: 8,
                background: AppColors.surface,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 32.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create a new password for your account.',
                        style: AppText.poppins(
                          size: 14,
                          color: AppColors.textBody,
                          height: 1.55,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      AppTextField(
                        label: 'New Password',
                        controller: _password,
                        hintText: 'At least 6 characters',
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        errorText: errors.passwordError,
                        onChanged: (_) => ref
                            .read(resetFormControllerProvider.notifier)
                            .clearPasswordError(),
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'Confirm Password',
                        controller: _confirm,
                        hintText: 'Repeat the password',
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        errorText: errors.confirmError,
                        onChanged: (_) => ref
                            .read(resetFormControllerProvider.notifier)
                            .clearConfirmError(),
                      ),
                      SizedBox(height: 24.h),
                      AppButton(
                        label: 'Reset Password',
                        fullWidth: true,
                        onPressed: _reset,
                      ),
                    ],
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
