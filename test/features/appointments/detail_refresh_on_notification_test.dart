import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/features/appointments/application/providers/appointments_provider.dart';
import 'package:medibook/features/appointments/infrastructure/repositories/appointment_mappers.dart';
import 'package:medibook/features/appointments/presentation/screen/appointment_detail_screen.dart';
import 'package:medibook/features/notifications/application/providers/notifications_provider.dart';

import '../notifications/support/fixtures.dart';
import 'support/fixtures.dart';

/// UAT RUN3: a payment confirmed by Razorpay's webhook while the patient
/// looks at the booking must turn the screen to "Confirmed" without leaving
/// it. The only signal is the inbox socket's `notification.created`.
void main() {
  testWidgets('a new notification re-reads the open booking', (tester) async {
    final appointments = FakeAppointmentsRepository()
      ..detailValue = AppointmentMappers.detail(Fixtures.detailJson());
    late FakeInboxSocket socket;
    final inbox = InboxController(
      repository: FakeNotificationsRepository(),
      openSocket: (path) => socket = FakeInboxSocket(path),
      refreshSession: () async {},
      enabled: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appointmentsRepositoryProvider.overrideWithValue(appointments),
          inboxProvider.overrideWith((ref) => inbox),
        ],
        child: ScreenUtilInit(
          designSize: AppConstants.designSize,
          builder: (_, _) => const MaterialApp(
            home: AppointmentDetailScreen(id: Fixtures.appointmentId),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Payment pending'), findsWidgets);
    final before = appointments.invalidations;

    // The webhook confirmed it on the server …
    appointments.detailValue = AppointmentMappers.detail({
      ...Fixtures.detailJson(),
      'status': 'scheduled',
      'payment_status': 'paid',
    });
    // … and the patient's inbox hears "Payment received".
    socket.emit('notification.created', {
      'id': 'n-1',
      'kind': 'payment',
      'title': 'Payment received',
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(appointments.invalidations, greaterThan(before));
    expect(find.text('Confirmed for the slot below.'), findsOneWidget);
  });
}
