import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:medibook/app/router/app_routes.dart';
import 'package:medibook/app/theme/colors.dart';
import 'package:medibook/app/theme/typography.dart';
import 'package:medibook/core/widgets/app_button.dart';
import 'package:medibook/core/widgets/app_checkbox.dart';
import 'package:medibook/core/widgets/app_inner_header.dart';
import 'package:medibook/core/widgets/app_text_field.dart';
import 'package:medibook/core/widgets/toast/toast_controller.dart';
import 'package:medibook/features/auth/presentation/components/screen_fade_rise.dart';
import 'package:medibook/features/auth/presentation/controllers/signup_form_controller.dart';

/// Sign Up (`/signup`). Back → Login. Success → Home + welcome toast.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _terms = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _signup() {
    final valid = ref
        .read(signupFormControllerProvider.notifier)
        .validate(
          name: _name.text,
          email: _email.text,
          password: _password.text,
          acceptedTerms: _terms,
        );
    if (!valid) return;
    final first = _name.text.trim().split(' ').first;
    ref
        .read(toastControllerProvider.notifier)
        .show('Welcome to Medibook, $first!');
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final errors = ref.watch(signupFormControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ScreenFadeRise(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInnerHeader(
                title: 'Create Account',
                onBack: () => context.go(AppRoutes.login),
                bottomGap: 8,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 32.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Book doctors, lab tests and records in one place.',
                        textAlign: TextAlign.center,
                        style: AppText.poppins(
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      AppTextField(
                        label: 'Full Name',
                        controller: _name,
                        hintText: 'Your Name',
                        textInputAction: TextInputAction.next,
                        errorText: errors.nameError,
                        onChanged: (_) => ref.read(signupFormControllerProvider.notifier).clearNameError(),
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'Email',
                        controller: _email,
                        hintText: 'Your Email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        errorText: errors.emailError,
                        onChanged: (_) => ref.read(signupFormControllerProvider.notifier).clearEmailError(),
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'Phone Number',
                        controller: _phone,
                        hintText: '+91 00000 00000',
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'Password',
                        controller: _password,
                        hintText: 'Create a password',
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        errorText: errors.passwordError,
                        onChanged: (_) => ref.read(signupFormControllerProvider.notifier).clearPasswordError(),
                      ),
                      SizedBox(height: 18.h),
                      AppCheckbox(
                        value: _terms,
                        error: errors.termsError,
                        label:
                            'I agree to the Terms & Conditions, Privacy Policy, and User Guidelines.',
                        onChanged: (v) {
                          setState(() => _terms = v);
                          ref.read(signupFormControllerProvider.notifier).clearTermsError();
                        },
                      ),
                      SizedBox(height: 24.h),
                      AppButton(
                        label: 'Sign Up',
                        fullWidth: true,
                        onPressed: _signup,
                      ),
                      SizedBox(height: 24.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: AppText.poppins(
                              size: 14,
                              color: AppColors.textBody,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go(AppRoutes.login),
                            child: Text(
                              'Log In',
                              style: AppText.poppins(
                                size: 14,
                                weight: AppText.semibold,
                                color: AppColors.accentBlue,
                              ),
                            ),
                          ),
                        ],
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
