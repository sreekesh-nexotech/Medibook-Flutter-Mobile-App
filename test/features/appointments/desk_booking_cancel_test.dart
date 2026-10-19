import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/config/constants.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/appointments/application/providers/appointments_provider.dart';
import 'package:medibook/features/appointments/application/usecases/cancel_blocked_reason.dart';
import 'package:medibook/features/appointments/infrastructure/repositories/appointment_mappers.dart';
import 'package:medibook/features/appointments/presentation/screen/appointment_detail_screen.dart';
import 'package:medibook/features/notifications/application/providers/notifications_provider.dart';

import '../notifications/support/fixtures.dart';
import 'support/fixtures.dart';

/// UB-12: a desk walk-in shows in the patient's app, but only the hospital
/// desk can cancel it. The detail screen says so up front (from `source`),
/// and a refused `POST …/cancel` keeps the server's sentence.
void main() {
  const desk =
      'This booking was made at the hospital desk; please ask the hospital '
      'to cancel it.';

  Map<String, Object?> walkInJson() => {
    ...Fixtures.detailJson(),
    'status': 'scheduled',
    'payment_status': 'paid',
    'source': 'walk_in',
    'token_source': 'offline',
    'actions': {
      'can_cancel': false,
      'cancel_blocked_reason': 'APPOINTMENT_NOT_ACTIONABLE',
      'can_retry_payment': false,
      'can_review': false,
    },
  };

  group('CancelBlockedReason', () {
    test('a walk-in names the hospital desk', () {
      final detail = AppointmentMappers.detail(walkInJson());
      expect(CancelBlockedReason.of(detail.appointment, detail.actions), desk);
    });

    test('an online booking keeps the server reason', () {
      final detail = AppointmentMappers.detail({
        ...walkInJson(),
        'source': 'online',
        'actions': {
          'can_cancel': false,
          'cancel_blocked_reason': 'TOKEN_ALREADY_CALLED',
        },
      });
      expect(
        CancelBlockedReason.of(detail.appointment, detail.actions),
        startsWith('Your token has already been called'),
      );
    });

    test('nothing when Cancel is allowed or the visit is closed', () {
      final open = AppointmentMappers.detail(Fixtures.detailJson());
      expect(CancelBlockedReason.of(open.appointment, open.actions), isNull);
      final closed = AppointmentMappers.detail(Fixtures.cancelledDetailJson());
      expect(
        CancelBlockedReason.of(closed.appointment, closed.actions),
        isNull,
      );
    });
  });

  test('409 desk_booking keeps the server sentence', () {
    final failure = NetworkExceptions.toFailure(
      const HttpStatusException(
        statusCode: 409,
        code: 'APPOINTMENT_NOT_ACTIONABLE',
        serverMessage: desk,
        meta: {'reason': 'desk_booking'},
      ),
      StackTrace.empty,
    );
    expect(failure.userMessage, desk);

    final other = NetworkExceptions.toFailure(
      const HttpStatusException(
        statusCode: 409,
        code: 'APPOINTMENT_NOT_ACTIONABLE',
      ),
      StackTrace.empty,
    );
    expect(other.userMessage, 'This appointment can no longer be changed.');
  });

  testWidgets('the detail screen shows why Cancel is off for a walk-in', (
    tester,
  ) async {
    final appointments = FakeAppointmentsRepository()
      ..detailValue = AppointmentMappers.detail(walkInJson());
    final inbox = InboxController(
      repository: FakeNotificationsRepository(),
      openSocket: FakeInboxSocket.new,
      refreshSession: () async {},
      enabled: false,
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
    expect(find.text(desk), findsOneWidget);
    expect(find.bySemanticsLabel('Cancel unavailable — $desk'), findsOneWidget);
  });
}
