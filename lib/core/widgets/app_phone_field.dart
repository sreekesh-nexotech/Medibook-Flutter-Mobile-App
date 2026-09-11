import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../app/localization/l10n.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/theme.dart';
import '../../app/theme/typography.dart';
import '../utils/validators.dart';
import 'app_bottom_sheet.dart';
import 'app_icon.dart';
import 'app_text_field.dart';

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

/// The country-code chip, as a standalone control.
///
/// [AppTextField] has a single trailing slot, so the dial-code selector is
/// composed *beside* the field rather than inside it — see [AppPhoneField],
/// which is what screens should actually use.
class AppCountryCodeChip extends StatelessWidget {
  const AppCountryCodeChip({
    super.key,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  final CountryCode value;
  final ValueChanged<CountryCode>? onChanged;
  final bool enabled;

  Future<void> _pick(BuildContext context) async {
    final picked = await showCountryCodePicker(context, selected: value);
    if (picked != null) onChanged?.call(picked);
  }

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onChanged != null;

    return Semantics(
      button: interactive,
      enabled: interactive,
      label: '${context.l10n.countryCode} ${value.dialCode} ${value.name}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: interactive ? () => _pick(context) : null,
          child: Container(
            height: 52.h,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            decoration: BoxDecoration(
              color: enabled ? AppColors.surfaceAlt : AppColors.grey100,
              borderRadius: AppRadii.md,
              border: Border.all(color: AppColors.border, width: 1.w),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value.flag, style: TextStyle(fontSize: 16.sp)),
                SizedBox(width: 6.w),
                Text(
                  value.dialCode,
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    weight: AppText.medium,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (interactive) ...[
                  SizedBox(width: 4.w),
                  AppIcon(MedIcon.back, size: 14, color: AppColors.textMuted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A mobile-number input: a country-code selector (default `+91`) beside the
/// national number, sharing one label and one error line.
///
/// Audit §3.5.3 — *"sign-up phone accepts anything, including empty and
/// letters"*. Three things fix that here, and all three matter:
///
/// 1. **The keyboard is numeric** and [FilteringTextInputFormatter.digitsOnly]
///    strips anything else, so letters cannot be typed in the first place.
/// 2. **`maxLength`** comes from the selected country
///    ([CountryCode.nationalDigits]), so an 11th digit cannot be added.
/// 3. **[Validators.phone]** is applied on demand via [validate], which
///    rejects empty input, wrong lengths and Indian numbers not starting 6-9.
///
/// Backs CM-04 (mobile login) and CM-01 (sign-up phone).
///
/// The caller owns the national-number [controller] and the selected
/// [countryCode], exactly as with [AppTextField] — the widget holds no value.
/// [e164] and [nationalNumber] read the current value for submission.
///
/// ```dart
/// AppPhoneField(
///   controller: phoneController,
///   countryCode: state.countryCode,
///   onCountryChanged: controller.pickCountry,
///   errorText: state.phoneError,
///   onChanged: controller.onPhoneChanged,
/// )
/// ```
class AppPhoneField extends StatelessWidget {
  const AppPhoneField({
    super.key,
    this.label = 'Mobile Number',
    this.controller,
    this.countryCode = CountryCodes.india,
    this.onCountryChanged,
    this.onChanged,
    this.errorText,
    this.helperText,
    this.hintText = '98765 43210',
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
  });

  final String? label;
  final TextEditingController? controller;
  final CountryCode countryCode;
  final ValueChanged<CountryCode>? onCountryChanged;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final String? helperText;
  final String? hintText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  /// The national number as digits only.
  String get nationalNumber => Validators.digitsOf(controller?.text ?? '');

  /// `+919845658525`.
  String get e164 => '${countryCode.dialCode}$nationalNumber';

  /// Validates the current value, or null when it is valid.
  String? validate() {
    if (countryCode.iso == 'IN') return Validators.phone(nationalNumber);
    final digits = nationalNumber;
    if (digits.isEmpty) return 'Enter your mobile number';
    if (digits.length != countryCode.nationalDigits) {
      return 'Mobile number must be ${countryCode.nationalDigits} digits';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.medium,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppCountryCodeChip(
              value: countryCode,
              onChanged: onCountryChanged,
              enabled: enabled,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: AppTextField(
                controller: controller,
                onChanged: onChanged,
                hintText: hintText,
                keyboardType: TextInputType.phone,
                textInputAction: textInputAction,
                focusNode: focusNode,
                onSubmitted: onSubmitted,
                enabled: enabled,
                maxLength: countryCode.nationalDigits,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                semanticLabel:
                    '${label ?? 'Mobile number'}, '
                    '${countryCode.dialCode} ${countryCode.name}',
                // The error message is rendered once, below the whole row, so
                // the chip and the field stay aligned — `showError` paints the
                // border without reserving a message line.
                showError: hasError,
              ),
            ),
          ],
        ),
        if (hasError) ...[
          SizedBox(height: 6.h),
          Text(
            errorText!,
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.danger,
            ),
          ),
        ] else if (helperText != null) ...[
          SizedBox(height: 6.h),
          Text(
            helperText!,
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Shows the dial-code picker and resolves to the chosen code, or null when
/// dismissed. Uses the house sheet language from `app_bottom_sheet.dart`.
Future<CountryCode?> showCountryCodePicker(
  BuildContext context, {
  CountryCode selected = CountryCodes.india,
}) {
  return showAppSheet<CountryCode>(
    context,
    title: 'Select country code',
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final code in CountryCodes.all)
          _CountryRow(
            code: code,
            isSelected: code == selected,
            onTap: () => Navigator.of(sheetContext).pop(code),
          ),
      ],
    ),
  );
}

class _CountryRow extends StatelessWidget {
  const _CountryRow({
    required this.code,
    required this.isSelected,
    required this.onTap,
  });

  final CountryCode code;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: code.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: 48.h),
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Row(
              children: [
                Text(code.flag, style: TextStyle(fontSize: 18.sp)),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    code.name,
                    style: AppText.poppins(
                      size: AppFontSize.body,
                      weight: isSelected ? AppText.semibold : AppText.regular,
                      color: isSelected
                          ? AppColors.brand
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  code.dialCode,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
