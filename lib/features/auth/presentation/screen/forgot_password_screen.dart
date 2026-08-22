import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/app/config/feature_flags.dart';
import 'package:medibook/app/router/app_routes.dart';
import 'package:medibook/app/theme/colors.dart';
import 'package:medibook/app/theme/typography.dart';
import 'package:medibook/core/widgets/app_button.dart';
import 'package:medibook/core/widgets/app_inner_header.dart';
import 'package:medibook/core/widgets/app_text_field.dart';
import 'package:medibook/core/widgets/toast/toast_controller.dart';
import 'package:medibook/features/auth/presentation/components/screen_fade_rise.dart';
import 'package:medibook/features/auth/presentation/controllers/forgot_form_controller.dart';

/// Forgot Password (`/forgot`). Back → Login. Send Code → Verify + toast.
/// The email is carried to Verify as a query so it can echo the address.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    // Demo affordance: prefill the email so Send Code works immediately.
    _email = TextEditingController(
      text: FeatureFlags.demoMode ? AppConstants.demoEmail : '',
    );
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _sendCode() {
    final valid = ref
        .read(forgotFormControllerProvider.notifier)
        .validate(email: _email.text);
    if (!valid) return;
    final email = _email.text.trim();
    ref.read(toastControllerProvider.notifier).show('Code sent to $email');
    context.go('${AppRoutes.verify}?email=${Uri.encodeQueryComponent(email)}');
  }

  @override
  Widget build(BuildContext context) {
    final errors = ref.watch(forgotFormControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ScreenFadeRise(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInnerHeader(
                title: 'Reset Password',
                onBack: () => context.go(AppRoutes.login),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 32.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Enter your Email, we will send you a verification code.',
                        style: AppText.poppins(
                          size: 14,
                          color: AppColors.textBody,
                          height: 1.55,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      AppTextField(
                        label: 'Email',
                        controller: _email,
                        hintText: 'Your Email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        errorText: errors.emailError,
                        onChanged: (_) => ref
                            .read(forgotFormControllerProvider.notifier)
                            .clearEmailError(),
                      ),
                      SizedBox(height: 24.h),
                      AppButton(
                        label: 'Send Code',
                        fullWidth: true,
                        onPressed: _sendCode,
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
