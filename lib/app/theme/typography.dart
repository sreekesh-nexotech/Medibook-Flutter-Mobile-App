import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Medibook type system.
///
/// Poppins drives all UI; Inter is the secondary face for dense data / tiny
/// meta. Font sizes are scaled with `.sp` (flutter_screenutil), so these are
/// getters/factories, never `const` — `const` would freeze the size and break
/// responsive scaling (see the ScreenUtil guide in docs-flutter/).
///
/// The design uses many one-off sizes (15, 17, 19, 26…) alongside the token
/// scale, so screens should call [AppText.poppins] / [AppText.inter] with the
/// exact px from the design and let ScreenUtil handle the `.sp` conversion.
abstract final class AppText {
  AppText._();

  static const String fontSans = 'Poppins';
  static const String fontAlt = 'Inter';

  // Weight aliases (Poppins Medium/SemiBold do most of the work).
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  /// Primary UI face. Pass the raw design px in [size]; it is `.sp`-scaled here.
  static TextStyle poppins({
    required double size,
    FontWeight weight = regular,
    Color color = const Color(0xFF141414),
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontSans,
      fontSize: size.sp,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Secondary face for dense data / tiny meta labels.
  static TextStyle inter({
    required double size,
    FontWeight weight = regular,
    Color color = const Color(0xFF141414),
    double? height,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: fontAlt,
      fontSize: size.sp,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }
}

/// The token type scale (px values seen in the app: 11–40). Reference these
/// when a design element maps cleanly onto a scale step; use raw px via
/// [AppText.poppins] for the many one-off sizes.
abstract final class AppFontSize {
  AppFontSize._();

  static const double display = 40; // splash / success headline
  static const double h1 = 28; // "Alexandra!" welcome
  static const double h2 = 22; // screen titles "Records"
  static const double h3 = 20; // section / card titles
  static const double title = 18; // doctor name, list headers
  static const double body = 16; // primary body, inputs, buttons
  static const double base = 14; // default running text, labels
  static const double sm = 13; // secondary captions
  static const double xs = 12; // meta, helper, time-ago
  static const double xxs = 11; // badge text
}
