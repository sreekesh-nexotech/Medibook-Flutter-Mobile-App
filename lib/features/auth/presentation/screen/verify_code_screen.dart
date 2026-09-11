import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/config/feature_flags.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/otp_box.dart';
import '../components/screen_fade_rise.dart';
import '../controllers/auth_flow_draft.dart';
import '../controllers/verify_controller.dart';
import '../../application/providers/auth_provider.dart';
import '../controllers/verify_request.dart';

/// Verify Code (`/verify`) — the one code-entry screen, now serving three
/// flows (CM-03 sign-up, CM-04 mobile sign-in, CM-06 password reset).
///
/// ## The parameters
///
/// The audit found *"a code-entry screen exists, but only inside the email
/// password-reset flow. Sign-up never reaches it, and no screen asks for a
/// mobile number"*. Cloning the screen per flow would have been three copies
/// of the same four boxes, so instead every caller encodes a [VerifyRequest]
/// into the `/verify` query and this screen reads everything from it:
///
/// ```dart
/// context.go(VerifyRequest(
///   purpose: VerifyPurpose.signup,      // signup | mobileLogin | passwordReset
///   channel: ResetChannel.sms,          // sms | email
///   destination: '+919845658525',       // echoed in the copy
/// ).path);                              // → /verify?purpose=signup&channel=sms&to=…
/// ```
///
/// [VerifyPurpose] decides the header, the blurb, the button label, where the
/// back arrow goes and what a correct code *does*; [ResetChannel] decides
/// whether the copy says "mobile number" or "email address". A `/verify` link
/// with no query at all still resolves to the email reset it shipped as.
///
/// The route table is untouched: one `/verify` entry, no new rows to wire.
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  static const int _length = 4;

  final List<TextEditingController> _digits = List.generate(
    _length,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _nodes = List.generate(_length, (_) => FocusNode());

  VerifyFormController get _form =>
      ref.read(verifyFormControllerProvider.notifier);

  /// The request this screen was opened with, decoded from the route query.
  VerifyRequest get _request =>
      VerifyRequest.fromQuery(GoRouterState.of(context).uri.queryParameters);

  String get _code => _digits.map((c) => c.text).join();

  @override
  void dispose() {
    for (final controller in _digits) {
      controller.dispose();
    }
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// What the code was sent to, for the copy. Falls back to the demo address
  /// only while demo mode is on, so with the flag off an empty destination
  /// simply renders as "your mobile number" / "your email address".
  String _destinationLabel(VerifyRequest request) {
    if (request.destination.isNotEmpty) return request.destination;
    if (FeatureFlags.demoMode && request.channel == ResetChannel.email) {
      return AppConstants.demoEmail;
    }
    return 'your ${request.channelLabel}';
  }

  void _onDigitChanged(int index, String value) {
    // Digits only; keep just the last one entered.
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    final digit = cleaned.isEmpty ? '' : cleaned.substring(cleaned.length - 1);
    if (_digits[index].text != digit) {
      _digits[index].value = TextEditingValue(
        text: digit,
        selection: TextSelection.collapsed(offset: digit.length),
      );
    }

    _form.onCodeChanged(_code);

    if (digit.isEmpty) {
      // A cleared box sends the caret back, so a correction does not need a
      // second tap.
      if (index > 0) _nodes[index - 1].requestFocus();
      return;
    }
    if (index < _length - 1) {
      _nodes[index + 1].requestFocus();
    } else {
      _nodes[index].unfocus();
    }
  }

  Future<void> _verify() async {
    final request = _request;
    for (final node in _nodes) {
      if (node.hasFocus) node.unfocus();
    }

    final accepted = await _form.verify(request: request, code: _code);
    if (!accepted || !mounted) return;

    switch (request.purpose) {
      case VerifyPurpose.signup:
        final draft = _form.completeSignup();
        final first = draft?.firstName ?? '';
        ref
            .read(toastControllerProvider.notifier)
            .show(
              first.isEmpty
                  ? 'Welcome to Medibook!'
                  : 'Welcome to Medibook, $first!',
            );
        context.go(AppRoutes.home);
      case VerifyPurpose.mobileLogin:
        context.go(AppRoutes.home);
      case VerifyPurpose.passwordReset:
        context.go(AppRoutes.reset);
      case VerifyPurpose.phoneChange:
        // CM-47. The only purpose that runs on an existing session, so the
        // number is committed here and the session is left alone — see
        // `VerifyRequest.signsIn`.
        final user = ref.read(authProvider).user;
        if (user != null) {
          ref
              .read(authProvider.notifier)
              .updateUser(
                user.copyWith(phone: request.destination, phoneVerified: true),
              );
        }
        ref
            .read(toastControllerProvider.notifier)
            .show('Mobile number updated');
        context.go(AppRoutes.profileEdit);
    }
  }

  Future<void> _resend() async {
    final request = _request;
    if (FeatureFlags.demoMode) {
      // Nothing is sent in demo mode, so saying "code re-sent" would be a
      // success message for something that did not happen. The code itself is
      // already stated on screen behind the same flag.
      showStubbedToast(context, ref, 'Sending a code');
      return;
    }
    final sent = await _form.resend(request);
    if (!sent || !mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show('Code re-sent to your ${request.channelLabel}');
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final form = ref.watch(verifyFormControllerProvider);
    final codeError = form.errorOf(VerifyFields.code);
    final failure = form.failure;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ScreenFadeRise(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInnerHeader(
                title: request.title,
                onBack: () => context.go(request.backPath),
                bottomGap: 8,
                background: AppColors.surface,
                backSemanticLabel: 'Back',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 32.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: request.blurb,
                          style: AppText.poppins(
                            size: AppFontSize.base,
                            color: AppColors.textBody,
                            height: 1.55,
                          ),
                          children: [
                            TextSpan(
                              text: _destinationLabel(request),
                              style: AppText.poppins(
                                size: AppFontSize.base,
                                weight: AppText.semibold,
                                color: AppColors.textStrong,
                                height: 1.55,
                              ),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                      SizedBox(height: 22.h),
                      if (failure != null) ...[
                        AppInlineError(failure: failure),
                        SizedBox(height: 16.h),
                      ],
                      Semantics(
                        label: 'Verification code, $_length digits',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < _length; i++) ...[
                              if (i > 0) SizedBox(width: 14.w),
                              OtpBox(
                                controller: _digits[i],
                                focusNode: _nodes[i],
                                hasError: codeError != null,
                                onChanged: (value) => _onDigitChanged(i, value),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 10.h),
                      if (codeError != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            codeError,
                            textAlign: TextAlign.center,
                            style: AppText.poppins(
                              size: AppFontSize.xs,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                        SizedBox(height: 6.h),
                      ],
                      if (FeatureFlags.demoMode)
                        Text(
                          'Demo code: ${AppConstants.demoOtpCode}',
                          textAlign: TextAlign.center,
                          style: AppText.poppins(
                            size: AppFontSize.xs,
                            color: AppColors.textMuted,
                          ),
                        ),
                      SizedBox(height: 22.h),
                      AppButton(
                        label: _confirmLabel(request),
                        fullWidth: true,
                        loading: form.isBusy,
                        onPressed: _verify,
                      ),
                      SizedBox(height: 22.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't get the code? ",
                            style: AppText.poppins(
                              size: AppFontSize.base,
                              color: AppColors.textBody,
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Resend code',
                            child: ExcludeSemantics(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: form.isBusy ? null : _resend,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8.h),
                                  child: Text(
                                    'Resend Code',
                                    style: AppText.poppins(
                                      size: AppFontSize.base,
                                      weight: AppText.semibold,
                                      color: AppColors.textLink,
                                    ),
                                  ),
                                ),
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

  /// The submit label.
  ///
  /// A real password reset has no verify endpoint of its own — the code is
  /// submitted with the new password on `/reset` — so outside demo mode this
  /// step only checks the code is well-formed and the button says "Continue"
  /// rather than claiming the code was verified.
  String _confirmLabel(VerifyRequest request) {
    if (request.purpose == VerifyPurpose.passwordReset &&
        !FeatureFlags.demoMode) {
      return 'Continue';
    }
    return request.confirmLabel;
  }
}
