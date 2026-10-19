import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/app/di/dependencies.dart';
import 'package:medibook/app/router/app_routes.dart';
import 'package:medibook/core/network/api_client.dart' as api;
import 'package:medibook/features/appointments/application/providers/appointments_provider.dart';
import 'package:medibook/features/appointments/application/providers/rebook_provider.dart';
import 'package:medibook/features/appointments/application/usecases/rebook.dart';
import 'package:medibook/features/appointments/infrastructure/repositories/appointment_mappers.dart';
import 'package:medibook/features/notifications/application/providers/notifications_provider.dart';
import 'package:medibook/features/notifications/application/usecases/notification_target.dart';
import 'package:medibook/features/notifications/infrastructure/repositories/notifications_repository_impl.dart';
import 'package:medibook/features/notifications/presentation/components/notification_card.dart';
import 'package:medibook/features/notifications/presentation/screen/notifications_screen.dart';

import '../../support/harness.dart';
import '../appointments/support/fixtures.dart';
import 'support/fixtures.dart';

/// UB-20: a hospital (schedule-change) cancel carries `rebook_prompt` in the
/// inbox `data` (a JSON boolean) and in push data (the string "true"); the
/// app then offers "Rebook", which opens booking with the same doctor.
void main() {
  Map<String, Object?> prompted([Object? flag = true]) =>
      NotificationFixtures.json(extraData: {'rebook_prompt': flag});

  group('mapping', () {
    test('rebook_prompt is read as a boolean or as push\'s "true"', () {
      expect(NotificationMappers.notification(prompted()).rebookPrompt, isTrue);
      expect(
        NotificationMappers.notification(prompted('true')).rebookPrompt,
        isTrue,
      );
      expect(
        NotificationMappers.notification(prompted(false)).rebookPrompt,
        isFalse,
      );
      expect(
        NotificationMappers.notification(prompted('false')).rebookPrompt,
        isFalse,
      );
      expect(
        NotificationMappers.notification(
          NotificationFixtures.json(),
        ).rebookPrompt,
        isFalse,
      );
    });

    test('only a prompted appointment.cancelled offers Rebook', () {
      expect(
        NotificationTargets.rebookAppointmentId(
          NotificationMappers.notification(prompted()),
        ),
        NotificationFixtures.appointmentId,
      );
      expect(
        NotificationTargets.rebookAppointmentId(
          NotificationMappers.notification(prompted(false)),
        ),
        isNull,
      );
      expect(
        NotificationTargets.rebookAppointmentId(
          NotificationMappers.notification(
            NotificationFixtures.json(
              event: 'appointment.confirmed',
              kind: 'confirmation',
              extraData: {'rebook_prompt': true},
            ),
          ),
        ),
        isNull,
      );
    });
  });

  test('the rebook request is the cancelled visit\'s doctor', () async {
    final appointments = FakeAppointmentsRepository()
      ..detailValue = AppointmentMappers.detail(Fixtures.cancelledDetailJson());
    final container = ProviderContainer(
      overrides: [
        ...appDependencies(),
        appointmentsRepositoryProvider.overrideWithValue(appointments),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      rebookRequestProvider(Fixtures.appointmentId),
      (_, _) {},
    );
    addTearDown(sub.close);
    final request = await container.read(
      rebookRequestProvider(Fixtures.appointmentId).future,
    );
    final appointment = appointments.detailValue!.appointment;
    expect(request.doctorId, appointment.doctor.id);
    expect(
      request.departmentKey,
      appointment.department.code ?? appointment.department.id,
    );
  });

  group('card', () {
    testWidgets('shows Rebook only when offered, and taps through', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              NotificationCard(
                notification: NotificationMappers.notification(prompted()),
                onOpen: () {},
                onRebook: () => taps++,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rebook'), findsOneWidget);
      await tester.tap(find.text('Rebook'));
      await tester.pump();
      expect(taps, 1);

      await tester.pumpWidget(
        harness(
          Column(
            children: [
              NotificationCard(
                notification: NotificationMappers.notification(prompted()),
                onOpen: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rebook'), findsNothing);
    });
  });

  testWidgets('Rebook on the inbox opens booking with the same doctor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final notifications = FakeNotificationsRepository()
      ..pages.add(
        api.Page(
          results: [NotificationMappers.notification(prompted())],
          page: 1,
          pageSize: 25,
          total: 1,
          hasNext: false,
        ),
      );
    final appointments = FakeAppointmentsRepository()
      ..detailValue = AppointmentMappers.detail(Fixtures.cancelledDetailJson());
    final inbox = InboxController(
      repository: notifications,
      openSocket: FakeInboxSocket.new,
      refreshSession: () async {},
      enabled: false,
    );
    final router = GoRouter(
      initialLocation: AppRoutes.notifications,
      routes: [
        GoRoute(
          path: AppRoutes.notifications,
          builder: (_, _) => const NotificationsScreen(),
        ),
        GoRoute(
          path: AppRoutes.booking,
          builder: (_, state) =>
              Scaffold(body: Text('booking ${state.uri.query}')),
        ),
        GoRoute(
          path: '/appointment/:id',
          builder: (_, _) => const Scaffold(body: Text('detail')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...appDependencies(),
          notificationsRepositoryProvider.overrideWithValue(notifications),
          appointmentsRepositoryProvider.overrideWithValue(appointments),
          inboxProvider.overrideWith((ref) => inbox),
        ],
        child: ScreenUtilInit(
          designSize: AppConstants.designSize,
          builder: (_, _) => MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Rebook'), findsOneWidget);

    await tester.tap(find.text('Rebook'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final appointment = appointments.detailValue!.appointment;
    final again = RebookRequest.of(appointment);
    expect(
      find.text(
        'booking ${Uri.parse(AppRoutes.rebookPath(dept: again.departmentKey, doctor: again.doctorId)).query}',
      ),
      findsOneWidget,
    );
    expect(notifications.readIds, [NotificationFixtures.id]);
  });
}
