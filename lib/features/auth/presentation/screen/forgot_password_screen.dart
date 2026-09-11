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
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_phone_field.dart';
import '../components/auth_channel_tabs.dart';
import '../components/auth_fields.dart';
import '../components/field_focus_group.dart';
import '../components/screen_fade_rise.dart';
import '../controllers/auth_flow_draft.dart';
import '../controllers/auth_form_controller.dart';
import '../controllers/forgot_form_controller.dart';
import '../controllers/verify_request.dart';

/// Reset Password (`/forgot`) — step one of the logged-out reset.
///
/// ## CM-06 — either channel
///
/// The flow used to run on email only, which locked out any patient who had
/// registered with a mobile number. The same [AuthChannelTabs] switch the
/// sign-in screen uses now chooses the channel, and the chosen one is recorded
/// in `passwordResetDraftProvider` so `/verify` and `/reset` follow it through.
///
/// The prefilled demo email stays behind [FeatureFlags.demoMode] — with the
/// flag off, nothing on this screen is prefilled and no demo copy is rendered.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _email;
  final TextEditingController _phone = TextEditingController();

  CountryCode _country = CountryCodes.india;
  ResetChannel _channel = ResetChannel.email;

  late final Map<String, TextEditingController> _controllers = {
    ForgotFields.email: _email,
    ForgotFields.phone: _phone,
  };

  late final FieldFocusGroup _focus = FieldFocusGroup(
    onBlur: (field) => _form.onBlur(field, _controllers[field]?.text ?? ''),
  );

  ForgotFormController get _form =>
      ref.read(forgotFormControllerProvider.notifier);

  bool get _isMobile => _channel == ResetChannel.sms;

  @override
  void initState() {
    super.initState();
    // Demo affordance (gated): prefill so Send Code works immediately.
    _email = TextEditingController(
      text: FeatureFlags.demoMode ? AppConstants.demoEmail : '',
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFieldChanged(String field, String value) =>
      _form.onChanged(field, value);

  void _onChannelChanged(ResetChannel channel) {
    if (channel == _channel) return;
    _focus.unfocus();
    _form.reset();
    setState(() => _channel = channel);
  }

  void _onCountryChanged(CountryCode country) {
    setState(() => _country = country);
    _form.onChanged(ForgotFields.phone, Validators.digitsOf(_phone.text));
  }

  Future<void> _sendCode() async {
    _focus.unfocus();

    final String destination;
    if (_isMobile) {
      final digits = Validators.digitsOf(_phone.text);
      if (!_form.validateMobileForm(phone: digits)) return;
      destination = '${_country.dialCode}$digits';
    } else {
      if (!_form.validateEmailForm(email: _email.text)) return;
      destination = _email.text.trim();
    }

    final sent = await _form.sendResetCode(
      channel: _channel,
      destination: destination,
    );
    if (!sent || !mounted) return;
    context.go(
      VerifyRequest(
        purpose: VerifyPurpose.passwordReset,
        channel: _channel,
        destination: destination,
      ).path,
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(forgotFormControllerProvider);
    final failure = form.failure;

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
                bottomGap: 8,
                background: AppColors.surface,
                backSemanticLabel: 'Back to sign in',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 32.h),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _isMobile
                              ? 'Enter your mobile number and we will text you '
                                    'a verification code.'
                              : 'Enter your email and we will send you a '
                                    'verification code.',
                          style: AppText.poppins(
                            size: AppFontSize.base,
                            color: AppColors.textBody,
                            height: 1.55,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        AuthChannelTabs(
                          value: _channel,
                          caption: 'Send the code to my',
                          onChanged: _onChannelChanged,
                          enabled: !form.isBusy,
                        ),
                        SizedBox(height: 20.h),
                        if (failure != null) ...[
                          AppInlineError(failure: failure),
                          SizedBox(height: 16.h),
                        ],
                        if (_isMobile)
                          _phoneField(form, busy: form.isBusy)
                        else
                          _emailField(form, busy: form.isBusy),
                        SizedBox(height: 24.h),
                        AppButton(
                          label: 'Send Code',
                          fullWidth: true,
                          loading: form.isBusy,
                          onPressed: _sendCode,
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

  Widget _emailField(AuthFormState form, {required bool busy}) {
    return AuthTextField(
      field: ForgotFields.email,
      label: 'Email',
      controller: _email,
      state: form,
      focus: _focus,
      onChanged: _onFieldChanged,
      hintText: 'Your Email',
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email, AutofillHints.username],
      enabled: !busy,
      onSubmit: _sendCode,
    );
  }

  Widget _phoneField(AuthFormState form, {required bool busy}) {
    return AuthPhoneField(
      field: ForgotFields.phone,
      controller: _phone,
      countryCode: _country,
      onCountryChanged: _onCountryChanged,
      state: form,
      focus: _focus,
      onChanged: _onFieldChanged,
      helperText: 'The number on your account.',
      enabled: !busy,
      onSubmit: _sendCode,
    );
  }
}
