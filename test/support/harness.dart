import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:medibook/app/config/constants.dart';
import 'package:medibook/app/theme/theme.dart';

/// Test harness for widget + golden tests.
///
/// Wraps a widget under test in the same environment the app runs in:
/// [ProviderScope] (optionally with overrides), [ScreenUtilInit] at the design
/// size, the app theme, and a fixed device size + `textScaleFactor: 1.0` so
/// goldens are deterministic.
///
/// Usage in a golden test:
/// ```dart
/// await tester.pumpWidget(harness(const AppButton(label: 'Log In')));
/// await tester.pumpAndSettle();
/// await expectLater(find.byType(AppButton), matchesGoldenFile('goldens/button.png'));
/// ```
Widget harness(
  Widget child, {
  List<Override> overrides = const [],
  Size surface = const Size(390, 844),
  Color background = const Color(0xFFF3F3F3),
}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: AppConstants.designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: (context, widget) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
            child: widget!,
          ),
          home: Scaffold(
            backgroundColor: background,
            body: Center(child: child),
          ),
        );
      },
    ),
  );
}

/// Pumps a full screen (already a routed page) at the device [surface] size.
Widget screenHarness(Widget screen, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: ScreenUtilInit(
      designSize: AppConstants.designSize,
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: widget!,
        ),
        home: screen,
      ),
    ),
  );
}
