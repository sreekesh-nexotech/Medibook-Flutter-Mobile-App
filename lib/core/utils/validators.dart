/// Input & business validators, ported from the prototype's rules
/// (`Medibook App.dc.html`) and extended for the forms the audit found
/// unguarded (§3.5.3: "sign-up phone accepts anything, including empty and
/// letters").
///
/// Pure functions — no UI, no state. Each returns `null` when valid, or a
/// user-facing error string when invalid, so they drop straight into an
/// [AppTextField]'s `errorText` slot.
abstract final class Validators {
  Validators._();

  /// Same pattern the design used: `/^[^\s@]+@[^\s@]+\.[^\s@]+$/`.
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Indian mobile: exactly 10 digits, first digit 6-9.
  static final RegExp _phone = RegExp(r'^[6-9]\d{9}$');

  /// Indian PIN code: 6 digits, cannot start with 0.
  static final RegExp _pincode = RegExp(r'^[1-9]\d{5}$');

  static final RegExp _digitsOnly = RegExp(r'^\d+$');

  static final RegExp _bloodGroup = RegExp(r'^(A|B|AB|O)[+-]$');

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

  // ---- Added for the CM-01 / CM-04 forms (audit §3.5.3) ----

  /// A 10-digit Indian mobile number, national format (no country code).
  ///
  /// Rejects empty input, letters, punctuation, wrong lengths and numbers
  /// starting 0-5 — the four cases the audit found the sign-up form accepting.
  /// Spaces and dashes are tolerated in the input and stripped before checking,
  /// because `AppPhoneField` lets the user type them.
  static String? phone(String value) {
    final digits = digitsOf(value);
    if (digits.isEmpty) return 'Enter your mobile number';
    if (digits.length != 10) return 'Mobile number must be 10 digits';
    if (!_phone.hasMatch(digits)) return 'Mobile number must start with 6-9';
    return null;
  }

  static bool isPhone(String value) => _phone.hasMatch(digitsOf(value));

  /// A 6-digit Indian PIN code.
  static String? pincode(String value) {
    final digits = digitsOf(value);
    if (digits.isEmpty) return 'Enter a PIN code';
    if (digits.length != 6) return 'PIN code must be 6 digits';
    if (!_pincode.hasMatch(digits)) return 'Enter a valid PIN code';
    return null;
  }

  /// A numeric one-time code of [length] digits (default 4, per the design).
  static String? otp(String value, {int length = 4}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter the code';
    if (!_digitsOnly.hasMatch(trimmed)) return 'The code is digits only';
    if (trimmed.length != length) return 'Enter all $length digits';
    return null;
  }

  /// Generic "this field cannot be blank", with the field's own name in the
  /// message so the error reads like a sentence.
  static String? requiredField(String label, String value) =>
      value.trim().isEmpty ? 'Enter $label' : null;

  /// A person's name: non-empty, at least two characters, letters/spaces/
  /// apostrophes/hyphens only (so "D'Souza" and "Anne-Marie" pass).
  static String? personName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter a name';
    if (trimmed.length < 2) return 'Name is too short';
    if (!RegExp(r"^[A-Za-z][A-Za-z '.\-]*$").hasMatch(trimmed)) {
      return 'Use letters only';
    }
    return null;
  }

  /// A postal address line — non-empty and long enough to be a real line.
  static String? addressLine(String value, {String label = 'an address'}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter $label';
    if (trimmed.length < 4) return 'Address looks too short';
    return null;
  }

  /// One of the eight ABO/Rh groups, e.g. `O+`, `AB-`.
  static String? bloodGroup(String value) {
    final normalised = value.trim().toUpperCase().replaceAll(' ', '');
    if (normalised.isEmpty) return 'Select a blood group';
    if (!_bloodGroup.hasMatch(normalised)) {
      return 'Enter a valid blood group (A+, O-, AB+ …)';
    }
    return null;
  }

  /// The canonical blood-group list, for pickers.
  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  /// A date of birth that is in the past and plausible (≤ 120 years ago).
  static String? dateOfBirth(DateTime? value, {DateTime? now}) {
    if (value == null) return 'Select a date of birth';
    final reference = now ?? DateTime.now();
    if (value.isAfter(reference)) return 'Date of birth cannot be in the future';
    if (reference.difference(value).inDays > 120 * 366) {
      return 'Enter a valid date of birth';
    }
    return null;
  }

  /// Strips everything but digits — the normalisation [phone] and [pincode] use
  /// and the one `inputFormatters` should mirror.
  static String digitsOf(String value) =>
      value.replaceAll(RegExp(r'\D'), '');
}
