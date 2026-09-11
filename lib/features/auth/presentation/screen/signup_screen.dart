import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_phone_field.dart';
import '../components/auth_fields.dart';
import '../components/field_focus_group.dart';
import '../components/legal_consent_checkbox.dart';
import '../components/screen_fade_rise.dart';
import '../controllers/auth_flow_draft.dart';
import '../controllers/auth_form_controller.dart';
import '../controllers/signup_form_controller.dart';
import '../controllers/verify_request.dart';

/// Create Account (`/signup`).
///
/// ## CM-01 — the fields a registration actually needs
///
/// The audit found *"sign-up asks for one 'Full Name'. First name, last name,
/// address and confirm-password have no field"*, and §3.5.3 that the phone box
/// *"accepts anything, including empty and letters. It is the only field on
/// that form with no rule"*. This form now collects:
///
/// | Field | Rule |
/// |---|---|
/// | First name / Last name | required, `Validators.personName` |
/// | Email | `Validators.email` |
/// | Mobile number | [AppPhoneField] — country code, digits only, `Validators.phone` |
/// | Password / Confirm password | `Validators.password` / `Validators.confirmPassword` |
/// | Address (label, line 1, line 2, city, state, PIN) | required except line 2; `Validators.pincode` |
///
/// ## CM-02 — the consent is readable
///
/// [LegalConsentCheckbox] makes Terms, Privacy Policy and User Guidelines
/// tappable links into `/legal/:slug`, which is what the audit's *"the checkbox
/// exists, but … no document screen exists"* was missing on this side.
///
/// ## CM-03 — the mobile number is verified before the account exists
///
/// Submitting does **not** create anything. It stores a [SignupDraft], asks for
/// an SMS code and continues to `/verify` as a [VerifyPurpose.signup]; the
/// account (and the address, saved to `addressesStoreProvider`) is committed
/// there once the code is accepted. Returning here re-fills every field except
/// the two passwords, which are deliberately never carried across a route.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  /// Pre-filled with the label nine addresses out of ten use, so the required
  /// field is not busywork — it stays editable.
  final TextEditingController _addressLabel = TextEditingController(
    text: 'Home',
  );
  final TextEditingController _addressLine1 = TextEditingController();
  final TextEditingController _addressLine2 = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _stateName = TextEditingController();
  final TextEditingController _pincode = TextEditingController();

  CountryCode _country = CountryCodes.india;
  bool _acceptedTerms = false;

  late final Map<String, TextEditingController> _controllers = {
    SignupFields.firstName: _firstName,
    SignupFields.lastName: _lastName,
    SignupFields.email: _email,
    SignupFields.phone: _phone,
    SignupFields.password: _password,
    SignupFields.confirmPassword: _confirm,
    SignupFields.addressLabel: _addressLabel,
    SignupFields.addressLine1: _addressLine1,
    SignupFields.addressLine2: _addressLine2,
    SignupFields.city: _city,
    SignupFields.stateName: _stateName,
    SignupFields.pincode: _pincode,
  };

  late final FieldFocusGroup _focus = FieldFocusGroup(
    onBlur: (field) => _form.onBlur(field, _controllers[field]?.text ?? ''),
  );

  SignupFormController get _form =>
      ref.read(signupFormControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Coming back from /verify: re-fill everything the draft kept.
    final draft = ref.read(signupDraftProvider);
    if (draft != null) _restore(draft);
  }

  void _restore(SignupDraft draft) {
    _firstName.text = draft.firstName;
    _lastName.text = draft.lastName;
    _email.text = draft.email;
    _phone.text = draft.phoneNational;
    _country = draft.countryCode;
    _addressLabel.text = draft.addressLabel;
    _addressLine1.text = draft.addressLine1;
    _addressLine2.text = draft.addressLine2;
    _city.text = draft.city;
    _stateName.text = draft.stateName;
    _pincode.text = draft.pincode;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  void _onFieldChanged(String field, String value) {
    if (field == SignupFields.password) {
      _form.onPasswordChanged(value, confirm: _confirm.text);
      return;
    }
    _form.onChanged(field, value);
  }

  void _onCountryChanged(CountryCode country) {
    setState(() => _country = country);
    _form.onChanged(SignupFields.phone, Validators.digitsOf(_phone.text));
  }

  void _onTermsChanged(bool accepted) {
    setState(() => _acceptedTerms = accepted);
    _form.onTermsChanged(accepted);
  }

  Future<void> _submit() async {
    _focus.unfocus();
    final digits = Validators.digitsOf(_phone.text);
    final valid = _form.validateForm(
      firstName: _firstName.text,
      lastName: _lastName.text,
      email: _email.text,
      phone: digits,
      password: _password.text,
      confirmPassword: _confirm.text,
      addressLabel: _addressLabel.text,
      addressLine1: _addressLine1.text,
      addressLine2: _addressLine2.text,
      city: _city.text,
      stateName: _stateName.text,
      pincode: _pincode.text,
      acceptedTerms: _acceptedTerms,
    );
    if (!valid) return;

    final draft = SignupDraft(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      countryCode: _country,
      phoneNational: digits,
      addressLabel: _addressLabel.text.trim(),
      addressLine1: _addressLine1.text.trim(),
      addressLine2: _addressLine2.text.trim(),
      city: _city.text.trim(),
      stateName: _stateName.text.trim(),
      pincode: _pincode.text.trim(),
    );

    final sent = await _form.startMobileVerification(draft);
    if (!sent || !mounted) return;
    context.go(
      VerifyRequest(
        purpose: VerifyPurpose.signup,
        channel: ResetChannel.sms,
        destination: draft.phoneE164,
      ).path,
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(signupFormControllerProvider);
    final failure = form.failure;
    final busy = form.isBusy;

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
                background: AppColors.surface,
                backSemanticLabel: 'Back to sign in',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 32.h),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Book doctors, lab tests and records in one place.',
                          textAlign: TextAlign.center,
                          style: AppText.poppins(
                            size: AppFontSize.base,
                            color: AppColors.textMuted,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        if (failure != null) ...[
                          AppInlineError(failure: failure),
                          SizedBox(height: 16.h),
                        ],
                        ..._identityFields(form, busy: busy),
                        SizedBox(height: 24.h),
                        const _SectionLabel('Address'),
                        SizedBox(height: 12.h),
                        ..._addressFields(form, busy: busy),
                        SizedBox(height: 18.h),
                        LegalConsentCheckbox(
                          value: _acceptedTerms,
                          onChanged: _onTermsChanged,
                          enabled: !busy,
                          errorText: form.errorOf(SignupFields.terms),
                          onOpenDocument: (slug) =>
                              context.push(AppRoutes.legalPath(slug)),
                        ),
                        SizedBox(height: 20.h),
                        AppButton(
                          label: 'Create Account',
                          fullWidth: true,
                          loading: busy,
                          onPressed: _submit,
                        ),
                        SizedBox(height: 10.h),
                        Text(
                          "We'll text a 4-digit code to your mobile number to "
                          'confirm it before the account is created.',
                          textAlign: TextAlign.center,
                          style: AppText.poppins(
                            size: AppFontSize.xs,
                            height: 1.45,
                            color: AppColors.textMuted,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: AppText.poppins(
                                size: AppFontSize.base,
                                color: AppColors.textBody,
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: 'Log In',
                              child: ExcludeSemantics(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => context.go(AppRoutes.login),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 8.h,
                                    ),
                                    child: Text(
                                      'Log In',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _identityFields(AuthFormState form, {required bool busy}) {
    return [
      AuthTextField(
        field: SignupFields.firstName,
        label: 'First Name',
        controller: _firstName,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: 'Alexandra',
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.givenName],
        enabled: !busy,
        onEditingComplete: () => _focus.requestFocus(SignupFields.lastName),
      ),
      SizedBox(height: 16.h),
      AuthTextField(
        field: SignupFields.lastName,
        label: 'Last Name',
        controller: _lastName,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: 'Johnson',
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.familyName],
        enabled: !busy,
        onEditingComplete: () => _focus.requestFocus(SignupFields.email),
      ),
      SizedBox(height: 16.h),
      AuthTextField(
        field: SignupFields.email,
        label: 'Email',
        controller: _email,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: 'you@example.com',
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email, AutofillHints.username],
        enabled: !busy,
        onEditingComplete: () => _focus.requestFocus(SignupFields.phone),
      ),
      SizedBox(height: 16.h),
      AuthPhoneField(
        field: SignupFields.phone,
        controller: _phone,
        countryCode: _country,
        onCountryChanged: _onCountryChanged,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        helperText: "We'll verify this number with a code.",
        enabled: !busy,
        onEditingComplete: () => _focus.requestFocus(SignupFields.password),
      ),
      SizedBox(height: 16.h),
      AuthPasswordField(
        field: SignupFields.password,
        label: 'Password',
        controller: _password,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: 'At least 6 characters',
        helperText: form.errorOf(SignupFields.password) == null
            ? 'At least 6 characters'
            : null,
        isNewPassword: true,
        enabled: !busy,
        onEditingComplete: () =>
            _focus.requestFocus(SignupFields.confirmPassword),
      ),
      SizedBox(height: 16.h),
      AuthPasswordField(
        field: SignupFields.confirmPassword,
        label: 'Confirm Password',
        controller: _confirm,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: 'Repeat the password',
        isNewPassword: true,
        enabled: !busy,
        onEditingComplete: () => _focus.requestFocus(SignupFields.addressLabel),
      ),
    ];
  }

  List<Widget> _addressFields(AuthFormState form, {required bool busy}) {
    return [
      AuthTextField(
        field: SignupFields.addressLabel,
        label: 'Label',
        controller: _addressLabel,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: 'Home, Work…',
        textCapitalization: TextCapitalization.words,
        maxLength: 24,
        enabled: !busy,
        onEditingComplete: () => _focus.requestFocus(SignupFields.addressLine1),
      ),
      SizedBox(height: 16.h),
      AuthTextField(
        field: SignupFields.addressLine1,
        label: 'Address Line 1',
        controller: _addressLine1,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: 'House / street',
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.streetAddressLine1],
        enabled: !busy,
        onEditingComplete: () => _focus.requestFocus(SignupFields.addressLine2),
      ),
      SizedBox(height: 16.h),
      AuthTextField(
        field: SignupFields.addressLine2,
        label: 'Address Line 2 (optional)',
        controller: _addressLine2,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: 'Flat, landmark',
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.streetAddressLine2],
        enabled: !busy,
        onEditingComplete: () => _focus.requestFocus(SignupFields.city),
      ),
      SizedBox(height: 16.h),
      AuthTextField(
        field: SignupFields.city,
        label: 'City',
        controller: _city,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: 'Bengaluru',
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.addressCity],
        enabled: !busy,
        onEditingComplete: () => _focus.requestFocus(SignupFields.stateName),
      ),
      SizedBox(height: 16.h),
      AuthTextField(
        field: SignupFields.stateName,
        label: 'State',
        controller: _stateName,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: 'Karnataka',
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.addressState],
        enabled: !busy,
        onEditingComplete: () => _focus.requestFocus(SignupFields.pincode),
      ),
      SizedBox(height: 16.h),
      AuthTextField(
        field: SignupFields.pincode,
        label: 'PIN Code',
        controller: _pincode,
        state: form,
        focus: _focus,
        onChanged: _onFieldChanged,
        hintText: '560001',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        maxLength: 6,
        autofillHints: const [AutofillHints.postalCode],
        enabled: !busy,
        onSubmit: _submit,
      ),
    ];
  }
}

/// A small group heading inside the form.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        label,
        style: AppText.poppins(
          size: AppFontSize.title,
          weight: AppText.semibold,
          color: AppColors.textStrong,
        ),
      ),
    );
  }
}
