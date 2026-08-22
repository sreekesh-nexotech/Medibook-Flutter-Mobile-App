import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medibook/app/app.dart';
import 'package:medibook/core/widgets/app_icon_button.dart';

/// Pixel-QC capture rig — NOT a regression test.
///
/// Boots the real app (router, shell, providers), drives it screen to screen
/// through the actual UI flows, and writes 390x844@2x PNGs to
/// `MEDIBOOK_SHOT_DIR` (default `build/qc_shots`) for pixel comparison against
/// the design prototype's Chromium screenshots.
///
/// Run: MEDIBOOK_SHOT_DIR=... flutter test test/qc/capture_screens_test.dart
void main() {
  final outDir = Platform.environment['MEDIBOOK_SHOT_DIR'] ?? 'build/qc_shots';

  testWidgets('capture all screens', (tester) async {
    Directory(outDir).createSync(recursive: true);

    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    // Simulate the iPhone status bar so SafeArea insets match the design's
    // 44px status zone (88 physical @2x).
    tester.view.padding = const FakeViewPadding(top: 88);
    addTearDown(tester.view.reset);

    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        child: RepaintBoundary(key: boundaryKey, child: const MedibookApp()),
      ),
    );

    // Fixed pumps — never pumpAndSettle: the home banner runs a periodic timer.
    Future<void> settle([int frames = 30]) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    await settle();

    Future<void> shot(String name) async {
      // Let pending IO (svg/image decodes) finish, then pump a frame.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await settle(10);
      final ro =
          boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img =
          await tester.runAsync(() => ro.toImage(pixelRatio: 2.0)) as ui.Image;
      final ByteData bytes = await tester.runAsync(
              () => img.toByteData(format: ui.ImageByteFormat.png))
          as ByteData;
      File('$outDir/$name.png').writeAsBytesSync(bytes.buffer.asUint8List());
      debugPrint('shot $name');
    }

    Future<void> tapText(String text, {int at = 0}) async {
      final f = find.text(text).at(at);
      await tester.ensureVisible(f);
      await settle(5);
      await tester.tap(f, warnIfMissed: false);
      await settle();
    }

    // Inner-screen headers put the back button as the first AppIconButton.
    Future<void> tapBack() async {
      await tester.tap(find.byType(AppIconButton).first, warnIfMissed: false);
      await settle();
    }

    // ---- Auth flow ----
    await shot('login');
    await tapText('Sign up');
    await shot('signup');
    await tapText('Log In'); // link back
    await tapText('Forgot password?');
    await shot('forgot');
    await tapText('Send Code');
    await tester.pump(const Duration(milliseconds: 2600)); // toast expires
    await shot('verify');
    final otp = find.byType(EditableText);
    const code = ['1', '2', '3', '4'];
    for (var i = 0; i < 4; i++) {
      await tester.enterText(otp.at(i), code[i]);
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tapText('Verify');
    await shot('reset');
    final pw = find.byType(EditableText);
    await tester.enterText(pw.at(0), 'medibook123');
    await tester.pump(const Duration(milliseconds: 40));
    await tester.enterText(pw.at(1), 'medibook123');
    await tester.pump(const Duration(milliseconds: 40));
    await tapText('Reset Password'); // -> login + toast
    await tester.pump(const Duration(milliseconds: 2600)); // let the toast expire

    // ---- Home ----
    await tapText('Log In');
    await shot('home');

    // ---- Search (+ Doctor Details for Dr. Anya Sharma, the prototype's
    // reference doctor) ----
    await tapText('Search doctors or departments...');
    await shot('search');
    await tapText('Dr. Anya Sharma');
    await shot('doctor');
    await tapBack(); // -> search
    await tapBack(); // -> home

    // ---- Notifications (bell = the only AppIconButton on Home) ----
    await tester.tap(find.byType(AppIconButton).first, warnIfMissed: false);
    await settle();
    await shot('notifications');
    await tapBack();

    // ---- Appointments in seeded state (before booking adds A-26) ----
    await tapText('Appointments'); // bottom nav
    await shot('appointments');
    await tapText('Dr. Priya Mehta');
    await shot('appt_detail');
    await tapText('Reschedule');
    await shot('reschedule');
    await tapBack(); // -> appt detail
    await tapBack(); // -> appointments
    await tapText('Home'); // bottom nav

    // ---- Booking flow ----
    await tapText('Appointment'); // quick-booking tile
    await shot('booking_step1');
    await tapText('General');
    await tapText('Continue');
    await shot('booking_step2');
    await tapText('Dr. Anil Kumar'); // doctor detail ('doctor' shot: see search)
    await tapText('Book an appointment');
    await shot('booking_step3');
    await tapText('Continue');
    await shot('booking_step4');
    await tapText('Confirm and Pay');
    await shot('success');
    await tapText('View Appointment');
    await shot('appt_detail_new');
    await tapBack(); // -> appointments list

    // ---- Records / Profile via bottom nav ----
    await tapText('Records');
    await shot('records');
    await tapText('Profile');
    await shot('profile');
    await tapText('Logout');
    await shot('sheet_logout');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
