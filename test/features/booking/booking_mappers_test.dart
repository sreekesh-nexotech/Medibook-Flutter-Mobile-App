import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/booking/domain/entities/availability.dart';
import 'package:medibook/features/booking/domain/entities/booked_appointment.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';
import 'package:medibook/features/booking/domain/entities/payment_order.dart';
import 'package:medibook/features/booking/domain/entities/slots.dart';
import 'package:medibook/features/booking/infrastructure/repositories/booking_mappers.dart';

/// The wire → entity mapping, pinned against the shapes the live backend
/// returned on 2026-09-30 (`docs/integration-gaps/booking-payment-discovery.md`).
void main() {
  group('discovery', () {
    test('hospital card keeps ratings as strings and parses instants', () {
      final card = BookingMappers.hospitalCard({
        'id': 'h1',
        'slug': 'lakeshore-multispeciality-kochi',
        'name': 'Lakeshore Multispeciality Hospital',
        'city': 'Kochi',
        'area': 'Kadavanthra',
        'rating': '3.90',
        'rating_count': 21,
        'distance_km': null,
        'departments': [
          {'id': 'd1', 'code': 'cardiology', 'name': 'Cardiology'},
        ],
        'next_available_at': '2026-09-30T11:30:00+00:00',
        'online_booking_enabled': true,
        'logo_file_id': null,
        'cover_file_id': null,
      });
      expect(card.rating, '3.90');
      expect(card.ratingValue, closeTo(3.9, 0.001));
      expect(card.distanceKm, isNull);
      expect(card.nextAvailableAt, DateTime.utc(2026, 9, 30, 11, 30));
      expect(card.offers('cardiology'), isTrue);
      expect(card.offers('ent'), isFalse);
      expect(card.locationLabel, 'Kadavanthra, Kochi');
    });

    test('hospital detail carries hours, holidays, policy and window', () {
      final detail = BookingMappers.hospitalDetail({
        'id': 'h1',
        'slug': 's',
        'name': 'Lakeshore',
        'city': 'Kochi',
        'area': null,
        'rating': null,
        'rating_count': 0,
        'departments': const [],
        'next_available_at': null,
        'online_booking_enabled': true,
        'timezone': 'Asia/Kolkata',
        'address': {
          'address_line1': 'NH 66 Bypass, Maradu',
          'address_line2': 'Near Vyttila Hub',
          'address_line3': null,
          'city': 'Kochi',
          'state': 'Kerala',
          'pincode': '682040',
          'phone_e164': '+914842701000',
        },
        'hours': [
          {
            'weekday': 6,
            'is_closed': true,
            'opens_at': null,
            'closes_at': null,
          },
          {
            'weekday': 0,
            'is_closed': false,
            'opens_at': '08:30',
            'closes_at': '20:00',
          },
        ],
        'holidays': [
          {
            'id': 'x',
            'name': 'Foundation day',
            'date_from': '2026-10-08',
            'date_to': '2026-10-08',
            'department_id': null,
          },
        ],
        'banners': [
          {'id': 'b1', 'title': 'Free BP check', 'body': 'Walk in 9–11 am.'},
        ],
        'cancellation_policy': {
          'cutoff_hours': 4,
          'refund_before_cutoff_bp': 10000,
          'refund_after_cutoff_bp': 0,
          'refund_includes_convenience_fee': false,
          'token_cancel_limit_min': null,
          'hospital_cancellation_refund_bp': 10000,
        },
        'follow_up_window_days': 7,
        'booking_window_days': 30,
        'version': 3,
      });
      expect(detail.card.hasRating, isFalse);
      expect(detail.card.locationLabel, 'Kochi');
      expect(detail.hours, hasLength(2));
      expect(detail.holidays.single.name, 'Foundation day');
      expect(detail.banners.single.hospitalId, 'h1');
      expect(detail.cancellationPolicy?.cutoffHours, 4);
      expect(detail.bookingWindowDays, 30);
      expect(detail.address?.oneLine, contains('682040'));
    });

    test('doctor card requires the embedded department and hospital', () {
      expect(
        () => BookingMappers.doctorCard({
          'id': 'd',
          'name': 'Dr. X',
          'consultation_fee_paise': 1,
          'department': {'id': 'x', 'code': 'c', 'name': 'C'},
        }),
        throwsA(isA<ResponseFormatException>()),
      );
      final card = BookingMappers.doctorCard({
        'id': 'doc1',
        'slug': 'dr-suresh-pillai',
        'name': 'Dr. Suresh Pillai',
        'title': 'Consultant',
        'qualification': 'MBBS, MD',
        'specialisation': 'Internal Medicine',
        'experience_years': 6,
        'photo_file_id': 'f1',
        'department': {'id': 'd1', 'code': 'general_medicine', 'name': 'GM'},
        'hospital': {
          'id': 'h1',
          'name': 'Lakeshore',
          'city': 'Kochi',
          'area': 'Kadavanthra',
        },
        'consultation_fee_paise': 50000,
        'follow_up_fee_paise': 25000,
        'rating': '3.60',
        'rating_count': 5,
        'status': 'on_leave',
        'is_bookable_online': true,
        'next_available_at': null,
      });
      expect(card.status, DoctorStatus.onLeave);
      expect(card.canBook, isFalse);
      expect(card.hospital.label, 'Lakeshore, Kadavanthra');
      expect(card.experienceLabel, '6 yrs');
    });
  });

  group('availability and slots', () {
    test('availability days group sessions with their state', () {
      final availability = BookingMappers.availability({
        'doctor_id': 'doc1',
        'from': '2026-09-30',
        'to': '2026-10-29',
        'dates': [
          {
            'date': '2026-09-30',
            'sessions': [
              {
                'session_id': 's1',
                'session_code': 'morning',
                'label': 'Morning OPD',
                'state': 'closed',
                'starts_at': '2026-09-30T03:30:00+00:00',
                'ends_at': '2026-09-30T06:30:00+00:00',
              },
            ],
          },
          {'date': '2026-10-01', 'sessions': const []},
          {
            'date': '2026-10-02',
            'sessions': [
              {
                'session_id': 's2',
                'session_code': 'evening',
                'label': 'Evening OPD',
                'state': 'available',
                'starts_at': '2026-10-02T11:30:00+00:00',
                'ends_at': '2026-10-02T13:30:00+00:00',
              },
            ],
          },
          {
            'date': '2026-10-03',
            'sessions': [
              {
                'session_id': 's3',
                'session_code': 'morning',
                'label': 'Morning OPD',
                'state': 'full',
                'starts_at': '2026-10-03T03:30:00+00:00',
                'ends_at': '2026-10-03T06:30:00+00:00',
              },
            ],
          },
        ],
      });
      // A closed session (over, or not taken online) is not a full one: the
      // strip said "fully booked" for a day whose session had ended.
      expect(availability.dates[0].isFull, isFalse);
      expect(availability.dates[0].isUnavailable, isTrue);
      expect(availability.dates[1].isUnavailable, isTrue);
      expect(availability.dates[2].hasAvailability, isTrue);
      expect(availability.dates[3].isFull, isTrue);
      expect(availability.dates[3].isUnavailable, isFalse);
      expect(availability.firstAvailable?.date, '2026-10-02');
      expect(
        availability.dates[0].sessions.single.state,
        SessionAvailability.closed,
      );
    });

    test('slots stay grouped by session and only available ones select', () {
      final day = BookingMappers.daySlots({
        'doctor_id': 'doc1',
        'date': '2026-10-01',
        'timezone': 'Asia/Kolkata',
        'sessions': [
          {
            'session_id': 's1',
            'session_code': 'morning',
            'label': 'Morning OPD',
            'status': 'scheduled',
            'starts_at': '2026-10-01T03:30:00+00:00',
            'ends_at': '2026-10-01T06:30:00+00:00',
            'slots': [
              {
                'id': 'slot-a',
                'starts_at': '2026-10-01T03:30:00+00:00',
                'ends_at': '2026-10-01T03:45:00+00:00',
                'state': 'available',
              },
              {
                'id': 'slot-b',
                'starts_at': '2026-10-01T03:45:00+00:00',
                'ends_at': '2026-10-01T04:00:00+00:00',
                'state': 'booked',
              },
            ],
          },
        ],
      });
      expect(day.sessions.single.label, 'Morning OPD');
      expect(day.timezone, 'Asia/Kolkata');
      expect(day.available.map((s) => s.id), ['slot-a']);
      expect(day.allSlots[1].state, SlotState.booked);
      expect(day.sessionOf(day.allSlots.first)?.sessionId, 's1');
      expect(day.isFullyBooked, isFalse);
    });
  });

  group('fee quote', () {
    test('renders the backend lines and the coupon verdict as-is', () {
      final quote = BookingMappers.feeQuote({
        'consultation_fee_paise': 50000,
        'service_fee_paise': 0,
        'discount_paise': 0,
        'convenience_fee_paise': 2000,
        'tax_paise': 400,
        'total_paise': 52400,
        'is_follow_up': false,
        'coupon_error': 'COUPON_INVALID',
        'currency': 'INR',
        'tax_lines': const [],
        'coupon': {'valid': false, 'reason': 'COUPON_INVALID'},
        'doctor_id': 'doc1',
        'hospital_id': 'h1',
        'person_id': null,
        'service_id': null,
        'regular_consultation_fee_paise': 50000,
        'follow_up_fee_paise': null,
        'lines': [
          {
            'line': 'consultation',
            'description': 'Consultation',
            'supplier': 'hospital',
            'amount_paise': 50000,
            'tax_code': 'EXEMPT',
            'tax_rate_bp': 0,
            'tax_paise': 0,
            'tax_inclusive': false,
          },
          {
            'line': 'convenience_fee',
            'description': 'Convenience fee',
            'supplier': 'platform',
            'amount_paise': 2000,
            'tax_code': 'CONVENIENCE_FEE_GST',
            'tax_rate_bp': 1800,
            'tax_paise': 400,
            'tax_inclusive': false,
          },
        ],
        'quoted_for_date': '2026-09-30',
      });
      expect(quote.totalPaise, 52400);
      expect(quote.lines, hasLength(2));
      expect(quote.lines[1].taxLabel, 'GST 18%');
      expect(quote.hasValidCoupon, isFalse);
      expect(quote.couponError, 'COUPON_INVALID');
    });
  });

  group('booking result', () {
    test('maps the appointment and payment order of a 201', () {
      final result = BookingMappers.bookingResult({
        'appointment': _appointmentJson(),
        'payment_order': _orderJson(),
      });
      expect(result.appointment.bookingRef, 'MB-2026-000124');
      expect(result.appointment.status, AppointmentStatus.pendingPayment);
      expect(result.appointment.tokenLabel, 'T-026');
      expect(result.appointment.hospitalTimezone, 'Asia/Kolkata');
      expect(
        result.appointment.bookingDeadlineAt,
        DateTime.utc(2026, 9, 30, 10, 5),
      );
      expect(result.paymentOrder.amountPaise, 48000);
      expect(result.paymentOrder.keyId, 'rzp_test_key');
      expect(result.paymentOrder.gatewayOrderId, 'order_NXa');
      expect(result.paymentOrder.status, PaymentOrderStatus.created);
    });

    test('a missing payment_order is a format error, not a booking', () {
      expect(
        () => BookingMappers.bookingResult({'appointment': _appointmentJson()}),
        throwsA(isA<ResponseFormatException>()),
      );
    });
  });

  group('persons', () {
    test('parses the page envelope, empty on the test account', () {
      expect(
        BookingMappers.persons({
          'results': const [],
          'page': 1,
          'page_size': 25,
          'total': 0,
          'has_next': false,
        }),
        isEmpty,
      );
      final one = BookingMappers.persons({
        'results': [
          {
            'id': 'p1',
            'is_self': false,
            'first_name': 'Arjun',
            'last_name': 'Nair',
            'relation': 'child',
            'date_of_birth': '2015-03-02',
            'gender': 'male',
          },
        ],
        'page': 1,
        'page_size': 25,
        'total': 1,
        'has_next': false,
      }).single;
      expect(one.fullName, 'Arjun Nair');
      // Worded as Family Members words it: relation and gender together.
      expect(one.relationLabel, 'Son');
    });
  });
}

Map<String, Object?> _appointmentJson() => {
  'id': 'appt1',
  'booking_ref': 'MB-2026-000124',
  'status': 'pending_payment',
  'status_reason': null,
  'source': 'online',
  'hospital': {
    'id': 'h1',
    'name': 'City Care Hospital',
    'city': 'Kochi',
    'phone_e164': '+914842000000',
    'timezone': 'Asia/Kolkata',
  },
  'department': {'id': 'd1', 'code': 'cardiology', 'name': 'Cardiology'},
  'doctor': {
    'id': 'doc1',
    'name': 'Dr. Anya Menon',
    'title': 'Senior Consultant',
    'specialisation': 'Interventional Cardiology',
    'room': 'OP-12',
  },
  'person_id': 'p1',
  'session_id': 's1',
  'slot_id': 'slot-a',
  'scheduled_date': '2026-10-01',
  'scheduled_start_at': '2026-10-01T03:30:00Z',
  'scheduled_end_at': '2026-10-01T03:45:00Z',
  'token_no': 26,
  'token_label': 'T-026',
  'token_source': 'online',
  'is_follow_up': false,
  'patient_notes': null,
  'payment_status': 'pending',
  'booking_deadline_at': '2026-09-30T10:05:00Z',
  'consultation_fee_paise': 50000,
  'service_fee_paise': 0,
  'discount_paise': 5000,
  'convenience_fee_paise': 2500,
  'tax_paise': 500,
  'tax_lines': const [],
  'total_paise': 48000,
  'currency': 'INR',
  'cancelled_at': null,
  'cancelled_by': null,
  'cancellation_reason': null,
  'created_at': '2026-09-30T10:00:00Z',
  'version': 2,
};

Map<String, Object?> _orderJson() => {
  'id': 'order1',
  'appointment_id': 'appt1',
  'amount_paise': 48000,
  'currency': 'INR',
  'channel': 'online',
  'gateway': 'razorpay',
  'gateway_order_id': 'order_NXa',
  'status': 'created',
  'attempts': 1,
  'expires_at': '2026-09-30T10:05:00Z',
  'key_id': 'rzp_test_key',
  'created_at': '2026-09-30T10:00:00Z',
};
