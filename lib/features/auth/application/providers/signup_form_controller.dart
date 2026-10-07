import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/utils/validators.dart';
import 'onboarding_provider.dart';
import '../../domain/entities/user.dart';
import 'auth_flow_draft.dart';
import 'auth_form_controller.dart';
import 'code_delivery.dart';

/// Field keys for the sign-up form (§4.1).
abstract final class SignupFields {
  SignupFields._();

  static const String firstName = 'firstName';
  static const String lastName = 'lastName';
  static const String email = 'email';
  static const String phone = 'phone';
  static const String dateOfBirth = 'dateOfBirth';
  static const String password = 'password';
  static const String confirmPassword = 'confirmPassword';
  static const String addressLabel = 'addressLabel';
  static const String addressLine1 = 'addressLine1';
  static const String addressLine2 = 'addressLine2';
  static const String city = 'city';
  static const String stateName = 'stateName';
  static const String pincode = 'pincode';
  static const String terms = 'terms';
}

/// The sign-up form.
///
/// The backend verifies the mobile number **before** the account exists
/// (`signup/start` → `signup/verify`), so this controller's submit does not
/// create anything: it sends the whole form (password included, once) to
/// `signup/start`, stores the [SignupDraft] for the trip to `/verify`, and
/// hands back the [OtpChallenge] the verify step needs.
///
/// Backend rules mirrored here so the user hears them before the round trip:
/// a password is optional but must be ≥ 10 characters when given; the account
/// holder must be 18+; the mobile must be an Indian number.
class SignupFormController extends AuthFormController {
  SignupFormController(this._ref);

  final Ref _ref;

  /// The backend's minimum (§4.1 "Password rules").
  static const int passwordMinLength = 10;

  /// Account holders must be 18+ (§4.1, `409 UNDER_AGE`).
  static const int minimumAge = 18;

  /// The password as last typed, so the confirm field can be re-checked
  /// against it on every keystroke. Lives and dies with this autoDispose
  /// controller and is never persisted (Coding Standards §9).
  String _password = '';

  @override
  String? validateField(String field, String value) => switch (field) {
    SignupFields.firstName =>
      Validators.requiredField('your first name', value) ??
          Validators.personName(value),
    // Optional on the backend; checked only when given.
    SignupFields.lastName =>
      value.trim().isEmpty ? null : Validators.personName(value),
    // Optional on the backend; checked only when given.
    SignupFields.email => value.trim().isEmpty ? null : Validators.email(value),
    SignupFields.phone => Validators.phone(value),
    SignupFields.dateOfBirth => _dateOfBirthError(value),
    // Optional on the backend (OTP-only accounts are normal), but a typed
    // password must meet the 10-character rule.
    SignupFields.password =>
      value.isEmpty ? null : Validators.password(value, min: passwordMinLength),
    SignupFields.confirmPassword => Validators.confirmPassword(
      value,
      _password,
    ),
    SignupFields.addressLabel => null,
    // The address block is optional as a whole; line 1 is validated only
    // when something was typed anywhere in the block.
    SignupFields.addressLine1 =>
      value.trim().isEmpty
          ? null
          : Validators.addressLine(value, label: 'a street address'),
    SignupFields.addressLine2 => null,
    SignupFields.city => null,
    SignupFields.stateName => null,
    SignupFields.pincode =>
      value.trim().isEmpty ? null : Validators.pincode(value),
    SignupFields.terms =>
      value.isEmpty
          ? 'Accept the Terms, Privacy Policy and User Guidelines to continue'
          : null,
    _ => null,
  };

  /// [value] is the ISO date the screen stores; empty when unpicked.
  static String? _dateOfBirthError(String value) {
    final picked = DateTime.tryParse(value);
    final error = Validators.dateOfBirth(picked);
    if (error != null) return error;
    final now = DateTime.now();
    final eighteenth = DateTime(
      picked!.year + minimumAge,
      picked.month,
      picked.day,
    );
    if (eighteenth.isAfter(now)) {
      return 'You must be $minimumAge or older to open an account. A family '
          'member can add you as a dependant.';
    }
    return null;
  }

  /// The password field's `onChanged` — re-checks the confirm field as well.
  void onPasswordChanged(String password, {required String confirm}) {
    _password = password;
    onChanged(SignupFields.password, password);
    onChanged(SignupFields.confirmPassword, confirm);
  }

  /// The terms checkbox, routed through [onChanged] so it behaves like every
  /// other field.
  void onTermsChanged(bool accepted) =>
      onChanged(SignupFields.terms, accepted ? 'accepted' : '');

  /// The date picker wrote a value.
  void onDateOfBirthChanged(DateTime? value) =>
      onChanged(SignupFields.dateOfBirth, value?.toIso8601String() ?? '');

  /// Validate the whole form. True when it may be submitted.
  bool validateForm({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required DateTime? dateOfBirth,
    required String password,
    required String confirmPassword,
    required String addressLabel,
    required String addressLine1,
    required String addressLine2,
    required String city,
    required String stateName,
    required String pincode,
    required bool acceptedTerms,
  }) {
    _password = password;
    final valid = validateAll(<String, String>{
      SignupFields.firstName: firstName,
      SignupFields.lastName: lastName,
      SignupFields.email: email,
      SignupFields.phone: phone,
      SignupFields.dateOfBirth: dateOfBirth?.toIso8601String() ?? '',
      SignupFields.password: password,
      SignupFields.confirmPassword: confirmPassword,
      SignupFields.addressLabel: addressLabel,
      SignupFields.addressLine1: addressLine1,
      SignupFields.addressLine2: addressLine2,
      SignupFields.city: city,
      SignupFields.stateName: stateName,
      SignupFields.pincode: pincode,
      SignupFields.terms: acceptedTerms ? 'accepted' : '',
    });
    if (!valid) return false;

    // A partly filled address block: line 1, city, state and PIN are all
    // required together (§6.2).
    final started = [
      addressLine1,
      city,
      stateName,
      pincode,
    ].any((v) => v.trim().isNotEmpty);
    if (started) {
      var ok = true;
      if (addressLine1.trim().isEmpty) {
        setFieldError(SignupFields.addressLine1, 'Enter a street address');
        ok = false;
      }
      if (city.trim().isEmpty) {
        setFieldError(SignupFields.city, 'Enter a city');
        ok = false;
      }
      if (stateName.trim().isEmpty) {
        setFieldError(SignupFields.stateName, 'Enter a state');
        ok = false;
      }
      if (pincode.trim().isEmpty) {
        setFieldError(SignupFields.pincode, 'Enter a PIN code');
        ok = false;
      }
      return ok;
    }
    return true;
  }

  /// Submit the form to `signup/start`: the backend validates it and sends
  /// the code. Stores [draft] for the trip to `/verify`. Returns the
  /// challenge, or null with the failure rendered.
  Future<OtpChallenge?> startMobileVerification(
    SignupDraft draft, {
    String? password,
  }) async {
    if (state.isBusy) return null;
    setBusy(true);
    try {
      // The offers opt-in is answered on the onboarding consent screen, not
      // on this form, so it joins the request here (`consents.marketing`,
      // §4.1) — otherwise the account is always created opted out.
      final signup = draft.copyWith(
        marketingOptIn: _ref.read(onboardingProvider).offersOptIn,
      );
      final challenge = await CodeDelivery.requestSignupCode(
        _ref,
        signup.toRequest(password: password),
      );
      if (challenge == null) {
        _render(CodeDelivery.lastFailure(_ref));
        return null;
      }
      setFailure(null);
      _ref.read(signupDraftProvider.notifier).save(signup);
      return challenge;
    } finally {
      setBusy(false);
    }
  }

  /// Server field errors land on their fields ("already registered" on the
  /// phone, the password rule, …); anything else is form-level.
  void _render(Failure? failure) {
    if (failure is ValidationFailure && failure.fieldErrors.isNotEmpty) {
      for (final entry in failure.fieldErrors.entries) {
        final field = switch (entry.key) {
          'first_name' => SignupFields.firstName,
          'last_name' => SignupFields.lastName,
          'email' => SignupFields.email,
          'phone_e164' => SignupFields.phone,
          'date_of_birth' => SignupFields.dateOfBirth,
          'password' => SignupFields.password,
          'address.address_line1' => SignupFields.addressLine1,
          'address.city' => SignupFields.city,
          'address.state' => SignupFields.stateName,
          'address.pincode' => SignupFields.pincode,
          'consents' => SignupFields.terms,
          _ => '',
        };
        if (field.isEmpty) {
          setFailure(failure);
        } else {
          setFieldError(field, entry.value);
        }
      }
      return;
    }
    if (failure is ConflictFailure && failure.apiCode == 'UNDER_AGE') {
      setFieldError(SignupFields.dateOfBirth, failure.userMessage);
      return;
    }
    setFailure(failure);
  }
}

/// autoDispose: the form's errors belong to one visit to the sign-up screen.
/// The *values* the user typed survive a trip to `/verify` in
/// [signupDraftProvider], which is not autoDispose for exactly that reason.
final signupFormControllerProvider =
    StateNotifierProvider.autoDispose<SignupFormController, AuthFormState>(
      (ref) => SignupFormController(ref),
    );
