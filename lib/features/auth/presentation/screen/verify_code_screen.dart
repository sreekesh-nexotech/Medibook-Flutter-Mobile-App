import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/feature_flags.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/router/guards/pending_link.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_countdown.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/otp_box.dart';
import '../components/screen_fade_rise.dart';
import '../../application/providers/verify_controller.dart';
import '../../application/providers/verify_request.dart';

/// Verify Code (`/verify`) — the one code-entry screen, serving sign-up
/// (§4.2), mobile sign-in (§4.4) and password reset (§4.7 step 2).
///
/// Every caller encodes a [VerifyRequest] — purpose, destination and the
/// backend `challenge_id` from the "start" call — into the `/verify` query,
/// and this screen reads everything from it. The number of boxes comes from
/// the challenge's `code_length`, not a constant. A resend mints a new
/// challenge, so the request is replaced in place (the route is updated too,
/// so a rebuild keeps the live id).
class VerifyCodeScreen extends ConsumerStatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  ConsumerState<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends ConsumerState<VerifyCodeScreen> {
  List<TextEditingController> _digits = const [];
  List<FocusNode> _nodes = const [];
  VerifyRequest? _request;

  VerifyFormController get _form =>
      ref.read(verifyFormControllerProvider.notifier);

  /// The request this screen was opened with, decoded once from the route
  /// query and then replaced by [_resend] when a new challenge is minted.
  VerifyRequest get _current => _request ??= VerifyRequest.fromQuery(
    GoRouterState.of(context).uri.queryParameters,
  );

  String get _code => _digits.map((c) => c.text).join();

  int get _length => _current.codeLength;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureBoxes();
  }

  void _ensureBoxes() {
    if (_digits.length == _length) return;
    for (final controller in _digits) {
      controller.dispose();
    }
    for (final node in _nodes) {
      node.dispose();
    }
    _digits = List.generate(_length, (_) => TextEditingController());
    _nodes = List.generate(_length, (_) => FocusNode());
  }

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

  /// What the code was sent to, for the copy.
  String _destinationLabel(VerifyRequest request) {
    if (request.destination.isNotEmpty) return request.destination;
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
    final request = _current;
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
        context.go(ref.read(pendingLinkProvider).take() ?? AppRoutes.home);
      case VerifyPurpose.mobileLogin:
        // A link opened before signing in, else Home (CL NAV-005).
        context.go(ref.read(pendingLinkProvider).take() ?? AppRoutes.home);
      case VerifyPurpose.passwordReset:
        context.go(AppRoutes.reset);
    }
  }

  /// When "Resend" unlocks (`resend_after_seconds` after the code was
  /// sent). Asking sooner is refused by the server (BL-AUTH-020).
  late DateTime _resendAt = DateTime.now().add(
    Duration(seconds: _current.resendAfterSeconds),
  );

  bool get _canResend => !DateTime.now().isBefore(_resendAt);

  Future<void> _resend() async {
    if (!_canResend) return;
    final challenge = await _form.resend(_current);
    if (challenge == null || !mounted) return;
    setState(() {
      _request = _current.withChallenge(
        challenge.challengeId,
        codeLength: challenge.codeLength,
        resendAfterSeconds: challenge.resendAfterSeconds,
        expiresAt: challenge.expiresAt,
      );
      _resendAt = DateTime.now().add(
        Duration(seconds: challenge.resendAfterSeconds),
      );
      _ensureBoxes();
    });
    // Keep the route in step so a rebuild reads the live challenge.
    context.replace(_current.path);
    ref
        .read(toastControllerProvider.notifier)
        .show('Code re-sent to your ${_current.channelLabel}');
  }

  @override
  Widget build(BuildContext context) {
    final request = _current;
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
                              color: AppColors.dangerText,
                            ),
                          ),
                        ),
                        SizedBox(height: 6.h),
                      ],
                      if (request.expiresAt case final expiresAt?) ...[
                        AppCountdown(
                          // A new code restarts it.
                          key: ValueKey(request.challengeId),
                          deadline: expiresAt,
                          builder: (context, remaining, label) => Text(
                            remaining > Duration.zero
                                ? 'Code expires in $label'
                                : 'This code has expired. Tap Resend Code '
                                      'for a new one.',
                            textAlign: TextAlign.center,
                            style: AppText.poppins(
                              size: AppFontSize.xs,
                              color: remaining > Duration.zero
                                  ? AppColors.textMuted
                                  : AppColors.danger,
                            ),
                          ),
                        ),
                        SizedBox(height: 6.h),
                      ],
                      if (FeatureFlags.demoMode)
                        Text(
                          'Demo code: ${DemoCredentials.otpCode}',
                          textAlign: TextAlign.center,
                          style: AppText.poppins(
                            size: AppFontSize.xs,
                            color: AppColors.textMuted,
                          ),
                        ),
                      SizedBox(height: 22.h),
                      AppButton(
                        label: request.confirmLabel,
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
                          if (!_canResend)
                            // Not tappable until the server will take it.
                            AppCountdown(
                              key: ValueKey(_resendAt),
                              deadline: _resendAt,
                              onExpired: () {
                                if (mounted) setState(() {});
                              },
                              builder: (context, remaining, label) => Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.h),
                                child: Text(
                                  'Resend in $label',
                                  style: AppText.poppins(
                                    size: AppFontSize.base,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            )
                          else
                            Semantics(
                              button: true,
                              label: 'Resend code',
                              child: ExcludeSemantics(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: form.isBusy ? null : _resend,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 8.h,
                                    ),
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
}
