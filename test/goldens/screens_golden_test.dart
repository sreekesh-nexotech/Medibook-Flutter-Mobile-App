import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medibook/features/auth/presentation/screen/login_screen.dart';
import 'package:medibook/features/notifications/presentation/screen/notifications_screen.dart';
import 'package:medibook/features/records/presentation/screen/records_screen.dart';
import 'package:medibook/features/profile/presentation/screen/profile_screen.dart';
import 'package:medibook/features/appointments/presentation/screen/appointments_screen.dart';
import 'package:medibook/features/booking/presentation/screen/booking_success_screen.dart';

import '../support/harness.dart';

/// Full-screen golden baselines for the screens that render deterministically.
///
/// Covered here: screens with no periodic timers, no generated dates, and no
/// network/asset-image dependence, using initials-only avatars — so their PNGs
/// are stable across runs. Generate with:
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
  Future<void> screenGolden(WidgetTester tester, Widget screen, String name) async {
    // Full phone surface — the default 800x600 test view clips 844-tall screens.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screenHarness(screen));
    await tester.pumpAndSettle();
    await expectLater(find.byType(screen.runtimeType), matchesGoldenFile('images/screen_$name.png'));
  }

  testWidgets('screen/login', (t) => screenGolden(t, const LoginScreen(), 'login'));

  testWidgets('screen/notifications', (t) => screenGolden(t, const NotificationsScreen(), 'notifications'));

  testWidgets('screen/records', (t) => screenGolden(t, const RecordsScreen(), 'records'));

  testWidgets('screen/profile', (t) => screenGolden(t, const ProfileScreen(), 'profile'));

  testWidgets('screen/appointments', (t) => screenGolden(t, const AppointmentsScreen(), 'appointments'));

  // Seeded appointment "1" (Today · 10:30 AM with Dr. Priya Mehta, token A-25).
  testWidgets('screen/booking-success', (t) => screenGolden(
        t, const BookingSuccessScreen(appointmentId: '1'), 'booking_success'));
}
