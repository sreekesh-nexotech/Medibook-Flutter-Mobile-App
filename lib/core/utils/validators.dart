/// Input & business validators, ported from the prototype's rules
/// (`Medibook App.dc.html`). Pure functions — no UI, no state.
///
/// Each returns `null` when valid, or a user-facing error string when invalid,
/// so they drop straight into a form field's error slot.
abstract final class Validators {
  Validators._();

  /// Same pattern the design used: `/^[^\s@]+@[^\s@]+\.[^\s@]+$/`.
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static bool isEmail(String value) => _email.hasMatch(value.trim());

  static String? email(String value) =>
      isEmail(value) ? null : 'Enter a valid email address';

  static String? password(String value, {int min = 6}) =>
      value.length >= min ? null : 'At least $min characters';

  static String? requiredPassword(String value) =>
      value.isEmpty ? 'Enter your password' : null;

  static String? name(String value) =>
      value.trim().isEmpty ? 'Enter your name' : null;

  static String? confirmPassword(String value, String original) =>
      value == original ? null : 'Passwords do not match';

  /// OTP is valid only when all four digits are entered.
  static bool otpComplete(List<String> otp) =>
      otp.length == 4 && otp.every((d) => d.isNotEmpty);
}
