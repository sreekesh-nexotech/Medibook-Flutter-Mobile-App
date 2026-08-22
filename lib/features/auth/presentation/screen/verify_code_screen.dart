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
import 'package:medibook/core/widgets/toast/toast_controller.dart';
import 'package:medibook/features/auth/presentation/components/otp_box.dart';
import 'package:medibook/features/auth/presentation/components/screen_fade_rise.dart';
import 'package:medibook/features/auth/presentation/controllers/verify_controller.dart';

/// Verify Code (`/verify`). Back → Forgot. Only [AppConstants.demoOtpCode]
/// (`1234`) passes → Reset; a wrong code shows the error line + red borders.
/// The four digit boxes own [TextEditingController]s + [FocusNode]s here; the
/// error string lives in the autoDispose [verifyControllerProvider].
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  final List<TextEditingController> _digits = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _nodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _digits) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  /// The email entered on Forgot, passed via query; falls back to the demo
  /// address so the copy still reads sensibly if reached directly.
  String get _email {
    final param = GoRouterState.of(context).uri.queryParameters['email'];
    if (param != null && param.isNotEmpty) return param;
    return FeatureFlags.demoMode ? AppConstants.demoEmail : '';
  }

  void _onDigitChanged(int index, String value) {
    // Digits only; keep just the last one entered (mirrors the prototype).
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    final ch = cleaned.isEmpty ? '' : cleaned.substring(cleaned.length - 1);
    if (_digits[index].text != ch) {
      _digits[index].value = TextEditingValue(
        text: ch,
        selection: TextSelection.collapsed(offset: ch.length),
      );
    }
    ref.read(verifyControllerProvider.notifier).clearError();
    if (ch.isNotEmpty && index < _digits.length - 1) {
      _nodes[index + 1].requestFocus();
    }
  }

  void _verify() {
    final code = _digits.map((c) => c.text).join();
    if (code == AppConstants.demoOtpCode) {
      context.go(AppRoutes.reset);
    } else {
      ref.read(verifyControllerProvider.notifier).showIncorrect();
    }
  }

  void _resend() {
    ref.read(toastControllerProvider.notifier).show('Code re-sent to $_email');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verifyControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ScreenFadeRise(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInnerHeader(
                title: 'Verify Code',
                onBack: () => context.go(AppRoutes.forgot),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 32.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: 'We sent a 4-digit code to ',
                          style: AppText.poppins(
                            size: 14,
                            color: AppColors.textBody,
                            height: 1.55,
                          ),
                          children: [
                            TextSpan(
                              text: _email,
                              style: AppText.poppins(
                                size: 14,
                                weight: AppText.semibold,
                                color: AppColors.textStrong,
                                height: 1.55,
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      SizedBox(height: 26.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _digits.length; i++) ...[
                            if (i > 0) SizedBox(width: 14.w),
                            OtpBox(
                              controller: _digits[i],
                              focusNode: _nodes[i],
                              hasError: state.hasError,
                              onChanged: (v) => _onDigitChanged(i, v),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 10.h),
                      if (state.hasError) ...[
                        Text(
                          state.otpError!,
                          textAlign: TextAlign.center,
                          style: AppText.poppins(
                            size: 12,
                            color: AppColors.danger,
                          ),
                        ),
                        SizedBox(height: 6.h),
                      ],
                      if (FeatureFlags.demoMode)
                        Text(
                          'Demo code: ${AppConstants.demoOtpCode}',
                          textAlign: TextAlign.center,
                          style: AppText.poppins(
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      SizedBox(height: 26.h),
                      AppButton(
                        label: 'Verify',
                        fullWidth: true,
                        onPressed: _verify,
                      ),
                      SizedBox(height: 22.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't get the code? ",
                            style: AppText.poppins(
                              size: 14,
                              color: AppColors.textBody,
                            ),
                          ),
                          GestureDetector(
                            onTap: _resend,
                            child: Text(
                              'Resend Code',
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
