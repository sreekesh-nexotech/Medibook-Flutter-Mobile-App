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
import 'package:medibook/core/widgets/app_checkbox.dart';
import 'package:medibook/core/widgets/app_text_field.dart';
import 'package:medibook/features/auth/presentation/components/auth_logo.dart';
import 'package:medibook/features/auth/presentation/components/screen_fade_rise.dart';
import 'package:medibook/features/auth/presentation/components/social_row.dart';
import 'package:medibook/features/auth/presentation/controllers/login_form_controller.dart';

/// Login (`/login`) — the app's start screen. No header; content top 34.h
/// (design 78 − the 44 faux status bar). Demo credentials are prefilled behind
/// [FeatureFlags.demoMode].
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    // Demo affordance: prefill so a reviewer can just tap Log In.
    _email = TextEditingController(
      text: FeatureFlags.demoMode ? AppConstants.demoEmail : '',
    );
    _password = TextEditingController(
      text: FeatureFlags.demoMode ? AppConstants.demoPassword : '',
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    final valid = ref
        .read(loginFormControllerProvider.notifier)
        .validate(email: _email.text, password: _password.text);
    if (valid) context.go(AppRoutes.home);
  }

  void _social() => context.go(AppRoutes.home);

  @override
  Widget build(BuildContext context) {
    final errors = ref.watch(loginFormControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ScreenFadeRise(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24.w, 34.h, 24.w, 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AuthLogo()),
                SizedBox(height: 26.h),
                Text(
                  'Hi, Welcome Back!',
                  textAlign: TextAlign.center,
                  style: AppText.poppins(
                    size: 24,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  "Hope you're doing fine.",
                  textAlign: TextAlign.center,
                  style: AppText.poppins(size: 14, color: AppColors.textMuted),
                ),
                SizedBox(height: 28.h),
                AppTextField(
                  label: 'Email',
                  controller: _email,
                  hintText: 'Your Email',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  errorText: errors.emailError,
                  onChanged: (_) => ref
                      .read(loginFormControllerProvider.notifier)
                      .clearEmailError(),
                ),
                SizedBox(height: 16.h),
                AppTextField(
                  label: 'Password',
                  controller: _password,
                  hintText: 'Password',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  errorText: errors.passwordError,
                  onChanged: (_) => ref
                      .read(loginFormControllerProvider.notifier)
                      .clearPasswordError(),
                ),
                SizedBox(height: 16.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppCheckbox(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v),
                      label: 'Remember me',
                    ),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.forgot),
                      child: Text(
                        'Forgot password?',
                        style: AppText.poppins(
                          size: 13,
                          weight: AppText.medium,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 22.h),
                AppButton(
                  label: 'Log In',
                  fullWidth: true,
                  onPressed: _login,
                ),
                SizedBox(height: 22.h),
                _OrDivider(),
                SizedBox(height: 22.h),
                SocialRow(onTap: _social),
                SizedBox(height: 26.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account yet? ",
                      style: AppText.poppins(
                        size: 14,
                        color: AppColors.textBody,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.signup),
                      child: Text(
                        'Sign up',
                        style: AppText.poppins(
                          size: 14,
                          weight: AppText.semibold,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                if (FeatureFlags.demoMode) ...[
                  SizedBox(height: 18.h),
                  Text(
                    'Demo login is prefilled — just tap Log In.',
                    textAlign: TextAlign.center,
                    style: AppText.poppins(size: 12, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "OR" rule between Log In and the social row.
class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1.h, color: AppColors.border),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Text(
            'OR',
            style: AppText.poppins(size: 13, color: AppColors.textMuted),
          ),
        ),
        line,
      ],
    );
  }
}
