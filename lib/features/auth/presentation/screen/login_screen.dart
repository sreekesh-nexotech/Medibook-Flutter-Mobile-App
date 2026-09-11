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
import '../../../../core/widgets/app_checkbox.dart';
import '../../../../core/widgets/app_phone_field.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../application/providers/auth_provider.dart';
import '../components/auth_channel_tabs.dart';
import '../components/auth_fields.dart';
import '../components/auth_logo.dart';
import '../components/field_focus_group.dart';
import '../components/lockout_notice.dart';
import '../components/screen_fade_rise.dart';
import '../components/social_row.dart';
import '../controllers/auth_flow_draft.dart';
import '../controllers/auth_form_controller.dart';
import '../controllers/login_form_controller.dart';
import '../controllers/verify_request.dart';

/// Sign in (`/login`) — the app's start screen.
///
/// ## CM-04: two credentials, one screen
///
/// The audit found *"login takes an email address. There is no mobile-number
/// field and no country-code control"*. An [AuthChannelTabs] switch now
/// chooses between them and the form swaps its one credential field:
///
/// * **Email** → password, submitted straight to `authProvider`.
/// * **Mobile** → [AppPhoneField] (country code, digits only, real
///   validation), which sends a one-time code and continues to `/verify` as a
///   [VerifyPurpose.mobileLogin].
///
/// ## CM-05: the lockout, inline
///
/// The five-attempt budget and the 60-second cooldown were already modelled in
/// `authProvider`; nothing said so on screen. [LockoutNotice] now renders the
/// live state directly above the fields — how many attempts are left, then a
/// firmer warning on the last one, then a running `mm:ss` countdown once the
/// form is locked — and the submit button is `disabled` with a reason for as
/// long as the cooldown lasts. It is deliberately *inline* rather than the
/// `/lockout` route: the countdown belongs next to the field the user is about
/// to try again in, and taking them to a separate screen would lose the email
/// they had typed.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _email;
  late final TextEditingController _password;
  final TextEditingController _phone = TextEditingController();

  CountryCode _country = CountryCodes.india;
  ResetChannel _channel = ResetChannel.email;

  late final Map<String, TextEditingController> _controllers = {
    LoginFields.email: _email,
    LoginFields.password: _password,
    LoginFields.phone: _phone,
  };

  /// Focus nodes for the three fields, reporting each blur to the controller so
  /// a field the user has left is re-validated from then on (audit §3.5.4).
  late final FieldFocusGroup _focus = FieldFocusGroup(
    onBlur: (field) => _form.onBlur(field, _controllers[field]?.text ?? ''),
  );

  LoginFormController get _form =>
      ref.read(loginFormControllerProvider.notifier);

  bool get _isMobile => _channel == ResetChannel.sms;

  @override
  void initState() {
    super.initState();
    // Demo affordance (gated): prefill so a reviewer can just tap Log In.
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
    _phone.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFieldChanged(String field, String value) =>
      _form.onChanged(field, value);

  /// Switching credential clears the form: leaving the email tab's errors on
  /// screen while the mobile tab is showing would be nonsense.
  void _onChannelChanged(ResetChannel channel) {
    if (channel == _channel) return;
    _focus.unfocus();
    _form.reset();
    setState(() => _channel = channel);
  }

  void _onCountryChanged(CountryCode country) {
    setState(() => _country = country);
    _form.onChanged(LoginFields.phone, Validators.digitsOf(_phone.text));
  }

  Future<void> _submit() async {
    _focus.unfocus();
    if (_isMobile) {
      await _submitMobile();
    } else {
      await _submitEmail();
    }
  }

  Future<void> _submitEmail() async {
    if (!_form.validateEmailForm(
      email: _email.text,
      password: _password.text,
    )) {
      return;
    }
    final signedIn = await _form.signInWithPassword(
      email: _email.text,
      password: _password.text,
    );
    if (!signedIn || !mounted) return;
    context.go(AppRoutes.home);
  }

  Future<void> _submitMobile() async {
    final digits = Validators.digitsOf(_phone.text);
    if (!_form.validateMobileForm(phone: digits)) return;

    final destination = '${_country.dialCode}$digits';
    final sent = await _form.requestLoginCode(phoneE164: destination);
    if (!sent || !mounted) return;
    context.go(
      VerifyRequest(
        purpose: VerifyPurpose.mobileLogin,
        channel: ResetChannel.sms,
        destination: destination,
      ).path,
    );
  }

  /// No OAuth client is configured in this build, so the honest answer is to
  /// name the provider that is not wired up rather than land on Home as though
  /// a federated sign-in had succeeded.
  void _onSocialTap(SocialProvider provider) =>
      showStubbedToast(context, ref, provider.actionLabel);

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(loginFormControllerProvider);
    final auth = ref.watch(authProvider);
    final isLockedOut = auth.isLockedOut;
    final failure = form.failure;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: ScreenFadeRise(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24.w, 34.h, 24.w, 32.h),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AuthLogo()),
                  SizedBox(height: 26.h),
                  Text(
                    'Hi, Welcome Back!',
                    textAlign: TextAlign.center,
                    style: AppText.poppins(
                      size: AppFontSize.h2,
                      weight: AppText.bold,
                      color: AppColors.textStrong,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "Hope you're doing fine.",
                    textAlign: TextAlign.center,
                    style: AppText.poppins(
                      size: AppFontSize.base,
                      color: AppColors.textMuted,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  AuthChannelTabs(
                    value: _channel,
                    caption: 'Sign in with',
                    onChanged: _onChannelChanged,
                    enabled: !form.isBusy,
                  ),
                  SizedBox(height: 20.h),
                  LockoutNotice(
                    state: auth,
                    onExpired: () =>
                        ref.read(authProvider.notifier).clearLockoutIfExpired(),
                  ),
                  if (LockoutNotice.showsFor(auth)) SizedBox(height: 16.h),
                  // A locked-out form already explains itself in the notice
                  // above; repeating the same sentence as a second error box
                  // would just be louder, not clearer.
                  if (failure != null && !isLockedOut) ...[
                    AppInlineError(failure: failure),
                    SizedBox(height: 16.h),
                  ],
                  if (_isMobile)
                    ..._mobileFields(form, locked: form.isBusy || isLockedOut)
                  else
                    ..._emailFields(form, locked: form.isBusy || isLockedOut),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Expanded bounds the checkbox so its internal Expanded
                      // label gets finite width (it crashes unbounded rows).
                      Expanded(
                        child: Semantics(
                          label:
                              'Stay signed in. Always on in this build — '
                              'use Log Out in Profile to end the session.',
                          child: const ExcludeSemantics(
                            // Not a control: this build always persists the
                            // session, so an editable "Remember me" would be
                            // claiming a choice the app does not offer.
                            child: AppCheckbox(
                              value: true,
                              label: 'Stay signed in',
                            ),
                          ),
                        ),
                      ),
                      _TextLink(
                        label: 'Forgot password?',
                        onTap: () => context.go(AppRoutes.forgot),
                      ),
                    ],
                  ),
                  SizedBox(height: 22.h),
                  AppButton(
                    label: _isMobile ? 'Send Code' : 'Log In',
                    fullWidth: true,
                    loading: form.isBusy,
                    disabled: isLockedOut,
                    semanticLabel: isLockedOut
                        ? 'Log In, paused after too many failed attempts'
                        : null,
                    onPressed: _submit,
                  ),
                  SizedBox(height: 22.h),
                  const _OrDivider(),
                  SizedBox(height: 22.h),
                  SocialRow(onProviderTap: _onSocialTap),
                  SizedBox(height: 26.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account yet? ",
                        style: AppText.poppins(
                          size: AppFontSize.base,
                          color: AppColors.textBody,
                        ),
                      ),
                      _TextLink(
                        label: 'Sign up',
                        weight: AppText.semibold,
                        size: AppFontSize.base,
                        onTap: () => context.go(AppRoutes.signup),
                      ),
                    ],
                  ),
                  if (FeatureFlags.demoMode) ...[
                    SizedBox(height: 18.h),
                    Text(
                      'Demo login is prefilled — just tap Log In.',
                      textAlign: TextAlign.center,
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _emailFields(AuthFormState form, {required bool locked}) {
    return [
      AuthTextField(
        field: LoginFields.email,
        label: 'Email',
        controller: _email,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: 'Your Email',
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email, AutofillHints.username],
        enabled: !locked,
        onEditingComplete: () => _focus.requestFocus(LoginFields.password),
      ),
      SizedBox(height: 16.h),
      AuthPasswordField(
        field: LoginFields.password,
        label: 'Password',
        controller: _password,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: 'Password',
        enabled: !locked,
        onSubmit: _submit,
      ),
    ];
  }

  List<Widget> _mobileFields(AuthFormState form, {required bool locked}) {
    return [
      AuthPhoneField(
        field: LoginFields.phone,
        controller: _phone,
        countryCode: _country,
        onCountryChanged: _onCountryChanged,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        helperText: "We'll text you a 4-digit code.",
        enabled: !locked,
        onSubmit: _submit,
      ),
    ];
  }
}

/// A plain inline text link — the house style for the two links on this screen.
class _TextLink extends StatelessWidget {
  const _TextLink({
    required this.label,
    required this.onTap,
    this.size = AppFontSize.sm,
    this.weight = AppText.medium,
  });

  final String label;
  final VoidCallback onTap;
  final double size;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            // Vertical padding, not a fixed height, so the target stays
            // reachable and the text still grows with OS text scaling.
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Text(
              label,
              style: AppText.poppins(
                size: size,
                weight: weight,
                color: AppColors.textLink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "OR" rule between Log In and the social row.
class _OrDivider extends StatelessWidget {
  const _OrDivider();

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
            style: AppText.poppins(
              size: AppFontSize.sm,
              color: AppColors.textMuted,
            ),
          ),
        ),
        line,
      ],
    );
  }
}
