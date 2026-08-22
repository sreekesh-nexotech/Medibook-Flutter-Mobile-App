import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../config/constants.dart';
import 'colors.dart';
import 'typography.dart';

/// Ready-made [BorderRadius] helpers, `.r`-scaled. Non-const by necessity
/// (ScreenUtil). Use `AppRadii.lg` for a card, `AppRadii.pill` for a token.
abstract final class AppRadii {
  AppRadii._();

  static BorderRadius get sm => BorderRadius.circular(AppRadius.sm.r);
  static BorderRadius get md => BorderRadius.circular(AppRadius.md.r);
  static BorderRadius get lg => BorderRadius.circular(AppRadius.lg.r);
  static BorderRadius get xl => BorderRadius.circular(AppRadius.xl.r);
  static BorderRadius get pill => BorderRadius.circular(AppRadius.pill.r);

  /// Hero header / bottom-sheet top corners (24px both top corners).
  static BorderRadius get sheetTop => BorderRadius.vertical(
    top: Radius.circular(AppRadius.xl.r),
  );
}

/// Soft, low, neutral ambient shadows. `--shadow-sm` is the card default.
abstract final class AppShadows {
  AppShadows._();

  static List<BoxShadow> get xs => [
    BoxShadow(
      color: const Color(0xFF1D3557).withValues(alpha: 0.05),
      blurRadius: 2.r,
      offset: Offset(0, 1.h),
    ),
  ];

  /// The Medibook card shadow: `0 2px 8px rgba(136,133,133,.18)`.
  static List<BoxShadow> get sm => [
    BoxShadow(
      color: const Color(0xFF888585).withValues(alpha: 0.18),
      blurRadius: 8.r,
      offset: Offset(0, 2.h),
    ),
  ];

  static List<BoxShadow> get md => [
    BoxShadow(
      color: const Color(0xFF1D3557).withValues(alpha: 0.10),
      blurRadius: 20.r,
      offset: Offset(0, 6.h),
    ),
  ];

  static List<BoxShadow> get lg => [
    BoxShadow(
      color: const Color(0xFF1D3557).withValues(alpha: 0.14),
      blurRadius: 32.r,
      offset: Offset(0, 12.h),
    ),
  ];

  /// Toast shadow — `0 8px 24px rgba(20,20,20,0.28)`.
  static List<BoxShadow> get toast => [
    BoxShadow(
      color: const Color(0xFF141414).withValues(alpha: 0.28),
      blurRadius: 24.r,
      offset: Offset(0, 8.h),
    ),
  ];
}

/// App theme assembly. Medibook is a light, single-theme design (no dark mode
/// exists in the source); we set a light [ThemeData] with the brand seed and
/// Poppins as the default family. Most surfaces are painted explicitly by the
/// design-system widgets, so the theme mainly sets defaults and the scaffold
/// background.
abstract final class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      surface: AppColors.surface,
      // ignore: deprecated_member_use
      background: AppColors.bgApp,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bgApp,
      fontFamily: AppText.fontSans,
      splashFactory: InkRipple.splashFactory,
      // The design never shows a text-selection or focus tint beyond inputs;
      // keep Material chrome quiet.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgApp,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }
}
