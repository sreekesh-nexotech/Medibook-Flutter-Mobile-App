import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/booking/application/providers/booking_providers.dart';
import 'package:medibook/features/booking/domain/entities/token_card.dart';
import 'package:medibook/features/booking/infrastructure/repositories/booking_mappers.dart';
import 'package:medibook/features/booking/presentation/screen/booking_success_screen.dart';

import '../../support/harness.dart';
import '../../support/offline_overrides.dart';

/// The token card ("View token" on an appointment, and after paying).
void main() {
  Map<String, Object?> payload({String? token, String? qr}) => {
    'booking_ref': 'LKSB-2610-00190',
    'token_label': ?token,
    'qr_payload': ?qr,
    'status': 'confirmed',
    'patient_name': 'Sanjay Varma',
    'hospital': {'name': 'Lakeshore Multispeciality Hospital'},
    'doctor': {'name': 'Dr. Meera Varghese'},
    'date': '2026-10-07',
    'start_time': '11:50',
    'end_time': '12:00',
    'starts_at': '2026-10-07T06:20:00Z',
    'ends_at': '2026-10-07T06:30:00Z',
  };

  Future<void> pump(
    WidgetTester tester,
    Future<TokenCard> Function() card,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    HiveInit.store = InMemoryLocalStore();
    await tester.pumpWidget(
      screenHarness(
        const BookingSuccessScreen(appointmentId: 'appt-1'),
        overrides: [
          ...offlineOverrides(),
          tokenCardProvider('appt-1').overrideWith((_) => card()),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  // BL-APPT-064: token and desk-code fallbacks.
  group('fallbacks', () {
    test('the desk code is the server payload, else the reference', () {
      expect(
        BookingMappers.tokenCard(payload(qr: 'DESK-42')).qrPayload,
        'DESK-42',
      );
      expect(BookingMappers.tokenCard(payload()).qrPayload, 'LKSB-2610-00190');
    });

    testWidgets('a token is shown as its label', (tester) async {
      await pump(
        tester,
        () async => BookingMappers.tokenCard(payload(token: 'A001')),
      );
      expect(find.textContaining('A001'), findsWidgets);
      expect(find.textContaining('Assigned by the hospital'), findsNothing);
    });

    testWidgets('no token yet says the hospital assigns it', (tester) async {
      await pump(tester, () async => BookingMappers.tokenCard(payload()));
      expect(find.textContaining('Assigned by the hospital'), findsWidgets);
    });
  });

  // BL-APPT-065: someone else's booking. The server answers 404, which the
  // repository turns into a NotFoundFailure.
  testWidgets('someone else\'s booking is not shown', (tester) async {
    final failure = NetworkExceptions.toFailure(
      const HttpStatusException(statusCode: 404, code: 'NOT_FOUND'),
      StackTrace.empty,
    );
    expect(failure, isA<NotFoundFailure>());
    await pump(tester, () async => throw failure);
    expect(find.text('That booking is not on this account'), findsOneWidget);
    expect(find.text('See my appointments'), findsOneWidget);
  });
}
