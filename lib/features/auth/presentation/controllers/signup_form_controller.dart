import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import 'auth_flow_draft.dart';
import 'auth_form_controller.dart';
import 'code_delivery.dart';

/// Field keys for the sign-up form (CM-01).
abstract final class SignupFields {
  SignupFields._();

  static const String firstName = 'firstName';
  static const String lastName = 'lastName';
  static const String email = 'email';
  static const String phone = 'phone';
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
/// CM-01 turned one "Full Name" box into the set a real registration needs:
/// first and last name, a validated mobile number, a confirmed password and a
/// postal address. CM-03 then put a mobile OTP in front of account creation,
/// so this controller's submit does **not** create anything — it stores the
/// [SignupDraft] and asks for a code, and `/verify` finishes the job.
class SignupFormController extends AuthFormController {
  SignupFormController(this._ref);

  final Ref _ref;

  /// The password as last typed, so the confirm field can be re-checked
  /// against it on every keystroke. Lives and dies with this autoDispose
  /// controller — the same lifetime as the screen's own
  /// `TextEditingController` — and is never persisted (Coding Standards §9).
  String _password = '';

  @override
  String? validateField(String field, String value) => switch (field) {
    SignupFields.firstName =>
      Validators.requiredField('your first name', value) ??
          Validators.personName(value),
    SignupFields.lastName =>
      Validators.requiredField('your last name', value) ??
          Validators.personName(value),
    SignupFields.email => Validators.email(value),
    SignupFields.phone => Validators.phone(value),
    SignupFields.password => Validators.password(value),
    SignupFields.confirmPassword => Validators.confirmPassword(
      value,
      _password,
    ),
    SignupFields.addressLabel => Validators.requiredField('a label', value),
    SignupFields.addressLine1 => Validators.addressLine(
      value,
      label: 'a street address',
    ),
    // Line 2 is genuinely optional — flat number, landmark, nothing.
    SignupFields.addressLine2 => null,
    SignupFields.city => Validators.requiredField('a city', value),
    SignupFields.stateName => Validators.requiredField('a state', value),
    SignupFields.pincode => Validators.pincode(value),
    SignupFields.terms =>
      value.isEmpty
          ? 'Accept the Terms, Privacy Policy and User Guidelines to continue'
          : null,
    _ => null,
  };

  /// The password field's `onChanged`.
  ///
  /// Re-checks the confirm field as well: when the two fields disagree it is
  /// just as likely the *first* one is being corrected, and an error that
  /// stays put while the user fixes the cause is the §3.5.4 finding all over
  /// again.
  void onPasswordChanged(String password, {required String confirm}) {
    _password = password;
    onChanged(SignupFields.password, password);
    onChanged(SignupFields.confirmPassword, confirm);
  }

  /// The terms checkbox.
  ///
  /// Routed through [onChanged] so it behaves like every other field: silent
  /// until the form has been submitted once, then corrected the instant the
  /// box is ticked.
  void onTermsChanged(bool accepted) =>
      onChanged(SignupFields.terms, accepted ? 'accepted' : '');

  /// Validate the whole form. True when it may be submitted.
  bool validateForm({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
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
    return validateAll(<String, String>{
      SignupFields.firstName: firstName,
      SignupFields.lastName: lastName,
      SignupFields.email: email,
      SignupFields.phone: phone,
      SignupFields.password: password,
      SignupFields.confirmPassword: confirmPassword,
      SignupFields.addressLabel: addressLabel,
      SignupFields.addressLine1: addressLine1,
      SignupFields.addressLine2: addressLine2,
      SignupFields.city: city,
      SignupFields.stateName: stateName,
      SignupFields.pincode: pincode,
      // The checkbox has no text, so its "value" is simply whether it is on.
      SignupFields.terms: acceptedTerms ? 'accepted' : '',
    });
  }

  /// Store [draft] and ask for the mobile code that gates account creation
  /// (CM-03). Returns true when `/verify` should be opened.
  Future<bool> startMobileVerification(SignupDraft draft) async {
    if (state.isBusy) return false;
    setBusy(true);
    try {
      final failure = await CodeDelivery.requestSmsCode(_ref, draft.phoneE164);
      setFailure(failure);
      if (failure != null) return false;
      _ref.read(signupDraftProvider.notifier).save(draft);
      return true;
    } finally {
      setBusy(false);
    }
  }
}

/// autoDispose: the form's errors belong to one visit to the sign-up screen.
/// The *values* the user typed survive a trip to `/verify` in
/// [signupDraftProvider], which is not autoDispose for exactly that reason.
final signupFormControllerProvider =
    StateNotifierProvider.autoDispose<SignupFormController, AuthFormState>(
      (ref) => SignupFormController(ref),
    );
