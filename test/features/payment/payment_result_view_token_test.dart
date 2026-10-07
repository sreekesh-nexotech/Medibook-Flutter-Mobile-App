import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/app/router/app_routes.dart';
import 'package:medibook/app/theme/theme.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/booking/presentation/booking_routes.dart';
import 'package:medibook/features/payment/presentation/screen/payment_result_screen.dart';

import '../../support/offline_overrides.dart';

/// BL-PAY-029 (owner decision): the token card is reached from a "View token"
/// button on the payment result and on a confirmed appointment.
void main() {
  setUp(() => HiveInit.store = InMemoryLocalStore());

  Widget app(String status, {String? appointmentId}) {
    final router = GoRouter(
      initialLocation: '/result',
      routes: [
        GoRoute(
          path: '/result',
          builder: (_, _) =>
              PaymentResultScreen(status: status, appointmentId: appointmentId),
        ),
        GoRoute(
          path: AppRoutes.success,
          builder: (_, state) => Scaffold(
            body: Text('token card ${state.uri.queryParameters['appt']}'),
          ),
        ),
      ],
    );
    return ProviderScope(
      overrides: offlineOverrides(),
      child: ScreenUtilInit(
        designSize: AppConstants.designSize,
        builder: (_, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final status in [
    PaymentResultStatus.success,
    PaymentResultStatus.pendingApproval,
  ]) {
    testWidgets('"$status" offers View token, which opens the token card', (
      tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(app(status, appointmentId: 'appt-1'));
      await tester.pumpAndSettle();

      expect(find.text('View token'), findsOneWidget);
      await tester.tap(find.text('View token'));
      await tester.pumpAndSettle();

      expect(find.text('token card appt-1'), findsOneWidget);
    });
  }

  for (final status in [
    PaymentResultStatus.failed,
    PaymentResultStatus.expired,
    PaymentResultStatus.late,
  ]) {
    testWidgets('"$status" has no View token', (tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(app(status, appointmentId: 'appt-1'));
      await tester.pumpAndSettle();

      expect(find.text('View token'), findsNothing);
    });
  }

  testWidgets('no View token when no booking is attached', (tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(app(PaymentResultStatus.success));
    await tester.pumpAndSettle();

    expect(find.text('View token'), findsNothing);
  });

  test('a token card applies to confirmed bookings that are still ahead', () {
    expect(
      AppointmentStatus.values.where((s) => s.hasTokenCard),
      unorderedEquals([
        AppointmentStatus.pendingApproval,
        AppointmentStatus.scheduled,
        AppointmentStatus.checkedIn,
        AppointmentStatus.inConsultation,
      ]),
    );
  });

  // BL-APPT-032 (owner decision): no live queue on an unpaid booking; a
  // booking awaiting the hospital's confirmation keeps it.
  test('the live queue is offered once a booking is past payment', () {
    expect(AppointmentStatus.pendingPayment.offersLiveQueue, isFalse);
    expect(AppointmentStatus.pendingApproval.offersLiveQueue, isTrue);
    expect(
      AppointmentStatus.values.where((s) => s.offersLiveQueue),
      unorderedEquals([
        AppointmentStatus.pendingApproval,
        AppointmentStatus.scheduled,
        AppointmentStatus.checkedIn,
        AppointmentStatus.inConsultation,
      ]),
    );
  });
}
