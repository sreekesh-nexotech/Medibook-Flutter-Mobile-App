/// A dialling code the phone field can be set to.
class CountryCode {
  const CountryCode({
    required this.iso,
    required this.dialCode,
    required this.name,
    required this.nationalDigits,
  });

  /// ISO-3166 alpha-2 ("IN").
  final String iso;

  /// Dialling code including the plus ("+91").
  final String dialCode;

  final String name;

  /// Expected national-number length, for the field's [maxLength].
  final int nationalDigits;

  /// "🇮🇳" — derived from the ISO code's regional-indicator code points, so
  /// no flag asset or font is needed.
  String get flag {
    if (iso.length != 2) return '';
    const base = 0x1F1E6;
    final upper = iso.toUpperCase();
    return String.fromCharCodes([
      base + upper.codeUnitAt(0) - 0x41,
      base + upper.codeUnitAt(1) - 0x41,
    ]);
  }

  /// "+91 India".
  String get label => '$dialCode  $name';

  @override
  bool operator ==(Object other) => other is CountryCode && other.iso == iso;

  @override
  int get hashCode => iso.hashCode;
}

/// The dialling codes offered. India first, then the corridors this patient
/// base actually uses.
abstract final class CountryCodes {
  CountryCodes._();

  static const CountryCode india = CountryCode(
    iso: 'IN',
    dialCode: '+91',
    name: 'India',
    nationalDigits: 10,
  );

  static const List<CountryCode> all = [
    india,
    CountryCode(
      iso: 'AE',
      dialCode: '+971',
      name: 'United Arab Emirates',
      nationalDigits: 9,
    ),
    CountryCode(
      iso: 'SA',
      dialCode: '+966',
      name: 'Saudi Arabia',
      nationalDigits: 9,
    ),
    CountryCode(iso: 'QA', dialCode: '+974', name: 'Qatar', nationalDigits: 8),
    CountryCode(iso: 'OM', dialCode: '+968', name: 'Oman', nationalDigits: 8),
    CountryCode(iso: 'KW', dialCode: '+965', name: 'Kuwait', nationalDigits: 8),
    CountryCode(
      iso: 'GB',
      dialCode: '+44',
      name: 'United Kingdom',
      nationalDigits: 10,
    ),
    CountryCode(
      iso: 'US',
      dialCode: '+1',
      name: 'United States',
      nationalDigits: 10,
    ),
    CountryCode(
      iso: 'SG',
      dialCode: '+65',
      name: 'Singapore',
      nationalDigits: 8,
    ),
    CountryCode(
      iso: 'AU',
      dialCode: '+61',
      name: 'Australia',
      nationalDigits: 9,
    ),
  ];

  static CountryCode byDialCode(String dialCode) =>
      all.firstWhere((c) => c.dialCode == dialCode, orElse: () => india);
}

/// Phone numbers as people read them. The server stores E.164
/// (`+919808659500`); screens show `+91 98086 59500`.
abstract final class PhoneFormat {
  PhoneFormat._();

  /// [e164] with a space after the dialling code; an Indian number is also
  /// split 5 + 5. Anything not recognised is returned unchanged.
  static String display(String e164) {
    final value = e164.replaceAll(' ', '');
    for (final code in CountryCodes.all) {
      if (!value.startsWith(code.dialCode)) continue;
      final national = value.substring(code.dialCode.length);
      if (national.length != code.nationalDigits ||
          !RegExp(r'^\d+$').hasMatch(national)) {
        continue;
      }
      if (code == CountryCodes.india) {
        return '${code.dialCode} ${national.substring(0, 5)} '
            '${national.substring(5)}';
      }
      return '${code.dialCode} $national';
    }
    return e164;
  }
}
