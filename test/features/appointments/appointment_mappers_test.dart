import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/core/utils/money.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/payment.dart';
import 'package:medibook/features/appointments/domain/entities/queue_status.dart';
import 'package:medibook/features/appointments/infrastructure/repositories/appointment_mappers.dart';

import 'support/fixtures.dart';

/// The JSON → entity mappers against the shapes the live backend returned
/// (§10). A wrong shape must throw, so nothing malformed is ever cached.
void main() {
  group('Appointment', () {
    test('maps every §10 field, money in paise, instants in UTC', () {
      final a = AppointmentMappers.appointment(Fixtures.appointmentJson());
      expect(a.id, Fixtures.appointmentId);
      expect(a.bookingRef, 'LKSB-2609-00182');
      expect(a.status, AppointmentStatus.pendingPayment);
      expect(a.paymentStatus, AppointmentPaymentStatus.pending);
      expect(a.source, AppointmentSource.online);
      expect(a.hospital.name, 'Lakeshore Multispeciality Hospital');
      expect(a.hospital.timezone, 'Asia/Kolkata');
      expect(a.department.code, 'general_medicine');
      expect(a.doctor.room, 'OPD-01');
      expect(a.tokenLabel, 'A002');
      expect(a.tokenNo, 2);
      expect(a.scheduledDate, '2026-10-02');
      expect(a.scheduledStartAt.isUtc, isTrue);
      expect(a.scheduledStartAt, DateTime.utc(2026, 10, 2, 11, 30));
      expect(a.bookingDeadlineAt, isNotNull);
      expect(a.consultationFee, const Money.paise(50000));
      expect(a.convenienceFee, const Money.paise(2000));
      expect(a.tax, const Money.paise(400));
      expect(a.total, const Money.paise(52400));
      expect(a.taxLines, hasLength(2));
      expect(a.taxLines.last.rateBp, 1800);
      expect(a.taxLines.last.supplier, 'platform');
      expect(a.cancelledBy, isNull);
      expect(a.version, 1);
    });

    test('a hospital block without a timezone still maps (older server)', () {
      final json = Fixtures.appointmentJson();
      (json['hospital']! as Map<String, Object?>).remove('timezone');
      expect(AppointmentMappers.appointment(json).hospital.timezone, isNull);
    });

    test('an unknown status is a format error, never a silent default', () {
      expect(
        () => AppointmentMappers.appointment(
          Fixtures.appointmentJson(status: 'rescheduled'),
        ),
        throwsA(isA<ResponseFormatException>()),
      );
    });

    test('a missing required field is a format error', () {
      final json = Fixtures.appointmentJson()..remove('booking_ref');
      expect(
        () => AppointmentMappers.appointment(json),
        throwsA(isA<ResponseFormatException>()),
      );
    });

    test('status buckets follow §10.1', () {
      expect(AppointmentStatus.pendingPayment.isUpcoming, isTrue);
      expect(AppointmentStatus.inConsultation.isUpcoming, isTrue);
      expect(AppointmentStatus.completed.isUpcoming, isFalse);
      expect(AppointmentStatus.noShow.isUpcoming, isFalse);
      expect(AppointmentStatus.checkedIn.isInQueue, isTrue);
    });
  });

  group('AppointmentDetail', () {
    test('carries actions, payment order, receipt and refunds', () {
      final d = AppointmentMappers.detail(Fixtures.detailJson());
      expect(d.actions.canCancel, isTrue);
      expect(d.actions.canRetryPayment, isTrue);
      expect(d.actions.canReview, isFalse);
      expect(d.actions.cancelBlockedReason, isNull);
      expect(d.paymentOrder?.gatewayOrderId, 'order_fakee00f1a22d66c40');
      expect(d.paymentOrder?.amount, const Money.paise(52400));
      expect(d.receipt, isNull);
      expect(d.refunds, isEmpty);
      expect(d.reviewed, isFalse);
    });

    test('a cancelled detail exposes the blocked reason verbatim', () {
      final d = AppointmentMappers.detail(Fixtures.cancelledDetailJson());
      expect(d.appointment.status, AppointmentStatus.cancelled);
      expect(d.appointment.cancelledBy, CancelledBy.patient);
      expect(d.appointment.version, 2);
      expect(d.actions.canCancel, isFalse);
      expect(d.actions.cancelBlockedReason, 'APPOINTMENT_NOT_ACTIONABLE');
    });

    test('a detail without actions gets the safe all-false default', () {
      final json = Fixtures.detailJson()..remove('actions');
      final d = AppointmentMappers.detail(json);
      expect(d.actions.canCancel, isFalse);
      expect(d.actions.canRetryPayment, isFalse);
    });
  });

  group('Queue, preview, cancel', () {
    test('queue: estimated wait is the API number, states parsed', () {
      final q = AppointmentMappers.queue(Fixtures.queueJson());
      expect(q.sessionState, SessionState.scheduled);
      expect(q.queueState, QueueState.available);
      expect(q.currentToken, isNull);
      expect(q.yourToken, 'A002');
      expect(q.tokensAhead, 0);
      expect(q.estimatedWaitMinutes, 0);
      expect(q.isNotOpenYet, isTrue);
      expect(q.isOnBreak, isFalse);
    });

    test('queue: paused / on_break reads as a break', () {
      final paused = AppointmentMappers.queue({
        ...Fixtures.queueJson(),
        'session_state': 'paused',
      });
      final onBreak = AppointmentMappers.queue({
        ...Fixtures.queueJson(),
        'session_state': 'open',
        'queue_state': 'on_break',
      });
      expect(paused.isOnBreak, isTrue);
      expect(onBreak.isOnBreak, isTrue);
    });

    test('cancellation preview: refund from the backend, in paise', () {
      final p = AppointmentMappers.cancellationPreview(Fixtures.previewJson());
      expect(p.allowed, isTrue);
      expect(p.refund, const Money.paise(45000));
      expect(p.nonRefundable, const Money.paise(3000));
      expect(p.refundBp, 10000);
      expect(p.refundPercentLabel, '100%');
      expect(p.cutoffAt, DateTime.utc(2026, 10, 2, 7, 30));
    });

    test('cancel outcome: appointment + refunds', () {
      final o = AppointmentMappers.cancelOutcome(Fixtures.cancelOutcomeJson());
      expect(o.appointment.status, AppointmentStatus.cancelled);
      expect(o.refunds, isEmpty);
    });
  });

  group('Events, token card, receipt, persons', () {
    test('events page', () {
      final page = AppointmentMappers.eventPage(Fixtures.eventsPageJson());
      expect(page.results, hasLength(2));
      expect(page.results.last.eventType, 'cancelled');
      expect(page.results.last.fromStatus, 'pending_payment');
      expect(page.hasNext, isFalse);
    });

    test('token card keeps hospital-local times and the address', () {
      final t = AppointmentMappers.tokenCard(Fixtures.tokenCardJson());
      expect(t.startTime, '17:00');
      expect(t.qrPayload, 'LKSB-2609-00182');
      expect(t.hospitalAddress.oneLine, contains('Kochi'));
      expect(t.session?.label, 'Evening OPD');
    });

    test('receipt: signed lines, payment lines, GSTINs', () {
      final r = AppointmentMappers.receipt(Fixtures.receiptJson());
      expect(r.receiptNo, 'RC/26-27/000311');
      expect(r.total, const Money.paise(48000));
      expect(r.lines, hasLength(3));
      expect(r.lines[1].isDeduction, isTrue);
      expect(r.lines[1].amount, const Money.paise(-5000));
      expect(r.lines[2].rateBp, 1800);
      expect(r.paymentLines.single.method, 'upi');
      expect(r.hospital.gstin, '32ABCDE1234F1Z5');
      expect(r.platform?.gstin, '27AABCM9407L1ZK');
      expect(r.pdfAvailable, isTrue);
      // The lines sum to the subtotal — no reconstruction in the app.
      expect(Money.total(r.lines.map((l) => l.amount)), r.subtotal);
    });

    test('refund and payment statuses parse', () {
      final refund = AppointmentMappers.refund({
        'id': 'rf-1',
        'payment_id': 'p-1',
        'appointment_id': Fixtures.appointmentId,
        'amount_paise': 45000,
        'reason': 'patient_cancellation',
        'status': 'processing',
        'requested_at': '2026-09-30T10:00:00+00:00',
        'processed_at': null,
      });
      expect(refund.status, RefundStatus.processing);
      expect(refund.amount, const Money.paise(45000));
      final payment = AppointmentMappers.payment({
        'id': 'p-1',
        'order_id': 'o-1',
        'appointment_id': Fixtures.appointmentId,
        'amount_paise': 48000,
        'method': 'upi',
        'gateway': 'razorpay',
        'status': 'captured',
        'captured_at': '2026-09-30T10:02:10+00:00',
        'failure_code': null,
        'failure_reason': null,
        'created_at': '2026-09-30T10:02:10+00:00',
      });
      expect(payment.status, PaymentStatus.captured);
    });

    test('persons: "For" label folds relation, self stays bare', () {
      final people = AppointmentMappers.personList({
        'results': [
          {
            'id': 'p-self',
            'is_self': true,
            'first_name': 'Anita',
            'last_name': 'Menon',
            'relation': 'self',
          },
          {
            'id': 'p-child',
            'is_self': false,
            'first_name': 'Arjun',
            'last_name': 'Nair',
            'relation': 'child',
          },
        ],
        'page': 1,
        'page_size': 100,
        'total': 2,
        'has_next': false,
      });
      expect(people.first.forLabel, 'Anita Menon');
      expect(people.last.forLabel, 'Arjun Nair (Child)');
    });
  });
}
