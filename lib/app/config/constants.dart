import 'package:flutter/widgets.dart';

/// Global, non-style constants: the Figma base size, animation timings, the 4/8
/// spacing scale, radii and shadow primitives, and the demo/prototype behaviour
/// values (banner interval, toast lifetime, demo OTP).
///
/// Style *colors* live in `app/theme/colors.dart`; text styles in
/// `app/theme/typography.dart`. This file holds numbers, durations and the
/// prototype constants extracted from `Medibook App.dc.html`.
abstract final class AppConstants {
  AppConstants._();

  /// Figma / prototype artboard size. The Medibook mobile frame is 390 x 844
  /// (iPhone). flutter_screenutil scales every `.w/.h/.sp/.r` against this.
  static const Size designSize = Size(390, 844);

  // ---- Animation timings (restrained; 150ms ease, no bounce) ----
  static const Duration screenIn = Duration(milliseconds: 220);
  static const Duration fadeIn = Duration(milliseconds: 220);
  static const Duration sheetUp = Duration(milliseconds: 250);
  static const Duration toastIn = Duration(milliseconds: 220);
  static const Duration pressScale = Duration(milliseconds: 50);
  static const Duration easeShort = Duration(milliseconds: 150);

  // ---- Prototype behaviour ----
  static const Duration toastLifetime = Duration(milliseconds: 2300);
  static const Duration bannerInterval = Duration(milliseconds: 4000);
  static const Duration searchAutoFocusDelay = Duration(milliseconds: 260);

  /// Demo affordances. Keep reachable only behind [FeatureFlags.demoMode];
  /// never ship these on a production auth path.
  static const String demoOtpCode = '1234';
  static const String demoEmail = 'alexandra.johnson@example.com';
  static const String demoPassword = 'medibook123';

  /// Booking token counter seed (`A-26`, increments per confirmed booking).
  static const int tokenCounterStart = 26;
}

/// The 4/8 spacing scale (design-system `tokens/spacing.css`).
/// Consume as `AppSpacing.md.w` / `.h` — never a hardcoded pixel.
abstract final class AppSpacing {
  AppSpacing._();

  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16; // default screen gutter & card padding
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
}

/// Raw radius values (design-system `tokens/spacing.css`). Wrap with `.r`
/// (ScreenUtil) at call sites; see `AppRadii` in `theme.dart` for ready-made
/// [BorderRadius] helpers.
abstract final class AppRadius {
  AppRadius._();

  static const double sm = 8; // chips, small inputs
  static const double md = 12; // buttons, inputs, list rows
  static const double lg = 16; // cards, banners
  static const double xl = 24; // sheets, hero header bottom
  static const double pill = 999; // tokens, status pills, segmented tabs
}
