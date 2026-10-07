import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medibook/features/auth/presentation/screen/login_screen.dart';
import 'package:medibook/features/notifications/presentation/screen/notifications_screen.dart';
import 'package:medibook/features/records/presentation/screen/records_screen.dart';
import 'package:medibook/features/profile/presentation/screen/profile_screen.dart';
import 'package:medibook/features/appointments/presentation/screen/appointments_screen.dart';
import 'package:medibook/features/booking/presentation/screen/booking_success_screen.dart';

import 'package:medibook/app/bootstrap/hive_init.dart';

import '../support/harness.dart';
import '../support/offline_overrides.dart';

/// Full-screen golden baselines for the screens that render deterministically.
///
/// The screens read the backend, so they are pumped behind [offlineOverrides]
/// and the baselines capture each screen's **offline / empty** design state
/// (no timers, no generated dates, no images). Loaded-data rendering is
/// covered by the per-feature widget tests with fake repositories. Generate
/// with:
///   flutter test --update-goldens test/goldens/screens_golden_test.dart
///
/// DELIBERATELY NOT golden-tested (covered by the code-level pixel audit in
/// `docs/PIXEL-AUDIT.md` instead, because they are non-deterministic under the
/// test engine):
///   • Home — the promo banner runs a periodic Timer (pumpAndSettle would hang)
///     and renders the doctor portrait asset.
///   • Verify Code — reads GoRouterState in build (needs a router ancestor).
///   • Booking step 3 / Reschedule / Confirm — date chips come from
///     DateTime.now(); pin a clock before golden-testing these.
///   • Doctor Detail / booking doctor cards for Dr. Anya — load a portrait asset.
void main() {
  Future<void> screenGolden(
    WidgetTester tester,
    Widget screen,
    String name, {
    bool inShell = false,
  }) async {
    // Full phone surface — the default 800x600 test view clips 844-tall screens.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    HiveInit.store = InMemoryLocalStore();
    await tester.pumpWidget(
      screenHarness(
        // A tab screen with a text field needs the Material ancestor the
        // shell's Scaffold gives it in the app.
        inShell
            ? Material(type: MaterialType.transparency, child: screen)
            : screen,
        overrides: offlineOverrides(),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(screen.runtimeType),
      matchesGoldenFile('images/screen_$name.png'),
    );
  }

  testWidgets(
    'screen/login',
    (t) => screenGolden(t, const LoginScreen(), 'login'),
  );

  testWidgets(
    'screen/notifications',
    (t) => screenGolden(t, const NotificationsScreen(), 'notifications'),
  );

  testWidgets(
    'screen/records',
    (t) => screenGolden(t, const RecordsScreen(), 'records', inShell: true),
  );

  testWidgets(
    'screen/profile',
    (t) => screenGolden(t, const ProfileScreen(), 'profile'),
  );

  testWidgets(
    'screen/appointments',
    (t) => screenGolden(t, const AppointmentsScreen(), 'appointments'),
  );

  // An id the offline fetcher cannot resolve — the screen's error state.
  testWidgets(
    'screen/booking-success',
    (t) => screenGolden(
      t,
      const BookingSuccessScreen(appointmentId: '1'),
      'booking_success',
    ),
  );
}
