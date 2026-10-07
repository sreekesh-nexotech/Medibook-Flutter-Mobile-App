import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/app/theme/theme.dart';
import 'package:medibook/features/booking/presentation/booking_routes.dart';
import 'package:medibook/features/booking/domain/entities/booked_appointment.dart';
import 'package:medibook/features/booking/domain/entities/booking_result.dart';
import 'package:medibook/features/booking/domain/entities/payment_order.dart';
import 'package:medibook/features/payment/application/providers/payment_providers.dart';
import 'package:medibook/features/payment/presentation/screen/payment_result_screen.dart';

import '../../support/offline_overrides.dart';

/// BL-PAY-003: the "payment window closed" result names the booking that
/// lapsed instead of "There is no booking attached to this outcome".
void main() {
  setUp(() => HiveInit.store = InMemoryLocalStore());

  testWidgets('the expired result names the released booking', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/result',
      routes: [
        GoRoute(
          path: '/result',
          builder: (_, _) => const PaymentResultScreen(
            status: PaymentResultStatus.expired,
            appointmentId: 'appt1',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(overrides: offlineOverrides());
    addTearDown(container.dispose);
    // Held as the payment screen would hold it.
    container.listen(paymentFlowProvider, (_, _) {});
    container.read(paymentFlowProvider.notifier).start(_booking());

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: AppConstants.designSize,
          builder: (_, _) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The payment window closed'), findsOneWidget);
    expect(find.textContaining('LKSB-2610-00187'), findsOneWidget);
    expect(find.textContaining('Dr. Meera Varghese'), findsOneWidget);
    expect(find.textContaining('Nothing was charged'), findsOneWidget);
    expect(find.textContaining('no booking attached'), findsNothing);
  });
}

BookingResult _booking() => BookingResult(
  appointment: BookedAppointment(
    id: 'appt1',
    bookingRef: 'LKSB-2610-00187',
    status: AppointmentStatus.pendingPayment,
    paymentStatus: AppointmentPaymentStatus.pending,
    hospitalId: 'h1',
    hospitalName: 'Lakeshore',
    departmentName: 'General Medicine',
    doctorId: 'doc1',
    doctorName: 'Dr. Meera Varghese',
    personId: 'p1',
    scheduledDate: '2026-10-06',
    scheduledStartAt: DateTime.utc(2026, 10, 6, 4, 10),
    scheduledEndAt: DateTime.utc(2026, 10, 6, 4, 20),
    consultationFeePaise: 40000,
    serviceFeePaise: 0,
    discountPaise: 0,
    convenienceFeePaise: 2400,
    taxPaise: 0,
    totalPaise: 42400,
    currency: 'INR',
    version: 1,
    bookingDeadlineAt: DateTime.utc(2026, 10, 5, 10, 5),
  ),
  paymentOrder: const PaymentOrder(
    id: 'order1',
    appointmentId: 'appt1',
    amountPaise: 42400,
    currency: 'INR',
    gatewayOrderId: 'order_NXa',
    keyId: 'rzp_test',
    status: PaymentOrderStatus.created,
    expiresAt: null,
  ),
);
