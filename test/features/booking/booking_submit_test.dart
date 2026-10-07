import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/booking/application/providers/booking_providers.dart';
import 'package:medibook/features/booking/domain/entities/availability.dart';
import 'package:medibook/features/booking/domain/entities/booked_appointment.dart';
import 'package:medibook/features/booking/domain/entities/booking_result.dart';
import 'package:medibook/features/booking/domain/entities/fee_quote.dart';
import 'package:medibook/features/booking/domain/entities/payment_order.dart';
import 'package:medibook/features/booking/domain/entities/person_summary.dart';
import 'package:medibook/features/booking/domain/entities/slots.dart';
import 'package:medibook/features/booking/domain/entities/token_card.dart';
import 'package:medibook/features/booking/domain/repositories/availability_repository.dart';
import 'package:medibook/features/booking/domain/repositories/booking_repository.dart';

/// `BookingSubmitController` against a scripted repository: the idempotency
/// key is reused for the same request and re-minted for a new one; a
/// `SLOT_UNAVAILABLE` drops the slot cache; a double tap is refused.
void main() {
  late _FakeBookingRepository repository;
  late _FakeAvailability availability;
  late BookingSubmitController controller;
  var minted = 0;

  const request = BookingRequest(slotId: 'slot-a', personId: 'p1');

  setUp(() {
    minted = 0;
    repository = _FakeBookingRepository();
    availability = _FakeAvailability();
    controller = BookingSubmitController(
      repository: repository,
      availability: availability,
      mintKey: () => 'key-${++minted}',
    );
  });

  test('a successful booking stores the result and its key', () async {
    final result = await controller.book(request);
    expect(result?.appointment.bookingRef, 'MB-2026-000124');
    expect(controller.state.isBooked, isTrue);
    expect(controller.state.idempotencyKey, 'key-1');
    expect(repository.keys, ['key-1']);
  });

  // BL-BOOK-035: the payment screen compares this with what the booking costs.
  test('the total shown at confirmation is kept with the booking', () async {
    await controller.book(request, quotedTotalPaise: 42400);
    expect(controller.state.quotedTotalPaise, 42400);

    controller.reset();
    expect(controller.state.quotedTotalPaise, isNull);
  });

  test('a booking made before the quote loaded keeps no total', () async {
    await controller.book(request);
    expect(controller.state.quotedTotalPaise, isNull);
  });

  test('a retry of the same request reuses the key', () async {
    repository.failWith = const TimeoutFailure();
    expect(await controller.book(request), isNull);
    expect(controller.state.failure, isA<TimeoutFailure>());

    repository.failWith = null;
    await controller.book(request);
    expect(repository.keys, ['key-1', 'key-1']);
  });

  test('a different request mints a new key', () async {
    repository.failWith = const TimeoutFailure();
    await controller.book(request);
    await controller.book(
      const BookingRequest(slotId: 'slot-b', personId: 'p1'),
    );
    expect(repository.keys, ['key-1', 'key-2']);
  });

  test(
    'SLOT_UNAVAILABLE flags the slot and invalidates the slot cache',
    () async {
      repository.failWith = const ConflictFailure(
        apiCode: ApiErrorCodes.slotUnavailable,
      );
      expect(await controller.book(request), isNull);
      expect(controller.state.slotUnavailable, isTrue);
      expect(availability.invalidations, 1);
    },
  );

  test('a second tap while in flight is refused', () async {
    repository.delay = const Duration(milliseconds: 50);
    final first = controller.book(request);
    final second = await controller.book(request);
    expect(second, isNull);
    expect(await first, isNotNull);
    expect(repository.keys, hasLength(1));
  });

  test(
    'a booked flow returns the existing result rather than re-booking',
    () async {
      await controller.book(request);
      await controller.book(request);
      expect(repository.keys, hasLength(1));
    },
  );

  // BL-BOOK-045: a booking changed after it was made, before payment.
  group('a changed booking before payment', () {
    late List<String> released;
    late BookingSubmitController changing;

    setUp(() {
      released = [];
      changing = BookingSubmitController(
        repository: repository,
        availability: availability,
        mintKey: () => 'key-${++minted}',
        releaseUnpaid: (id) async => released.add(id),
      );
    });

    test('the same booking is resumed, not made again', () async {
      await changing.book(request);
      await changing.book(request);
      expect(repository.keys, ['key-1']);
      expect(released, isEmpty);
    });

    test(
      'another person releases the unpaid booking and books again',
      () async {
        await changing.book(request);
        const forTara = BookingRequest(slotId: 'slot-a', personId: 'p2');
        final result = await changing.book(forTara);

        expect(released, ['appt1'], reason: 'the old booking is cancelled');
        expect(repository.keys, ['key-1', 'key-2'], reason: 'a new booking');
        expect(result?.appointment.personId, 'p2');
        expect(changing.state.request, forTara);
      },
    );

    test(
      'when the old booking cannot be released, nothing new is booked',
      () async {
        await changing.book(request);
        final failing = BookingSubmitController(
          repository: repository,
          availability: availability,
          mintKey: () => 'key-${++minted}',
          releaseUnpaid: (_) async => throw const NetworkFailure(),
        );
        await failing.book(request);
        final keysBefore = List.of(repository.keys);
        final result = await failing.book(
          const BookingRequest(slotId: 'slot-a', personId: 'p2'),
        );
        expect(result, isNull);
        expect(repository.keys, keysBefore);
        expect(
          failing.state.failure?.userMessage,
          contains('could not change'),
        );
        expect(failing.state.result?.appointment.personId, 'p1');
      },
    );
  });
}

class _FakeBookingRepository implements BookingRepository {
  Failure? failWith;
  Duration delay = Duration.zero;
  final List<String> keys = [];

  @override
  Future<BookingResult> book(
    BookingRequest request, {
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final failure = failWith;
    if (failure != null) throw failure;
    return BookingResult(
      appointment: BookedAppointment(
        id: 'appt1',
        bookingRef: 'MB-2026-000124',
        status: AppointmentStatus.pendingPayment,
        paymentStatus: AppointmentPaymentStatus.pending,
        hospitalId: 'h1',
        hospitalName: 'H',
        departmentName: 'Cardiology',
        doctorId: 'doc1',
        doctorName: 'Dr. Test',
        personId: request.personId,
        scheduledDate: '2026-10-01',
        scheduledStartAt: DateTime.utc(2026, 10, 1, 3, 30),
        scheduledEndAt: DateTime.utc(2026, 10, 1, 3, 45),
        consultationFeePaise: 50000,
        serviceFeePaise: 0,
        discountPaise: 0,
        convenienceFeePaise: 2000,
        taxPaise: 400,
        totalPaise: 52400,
        currency: 'INR',
        version: 1,
        tokenLabel: 'T-026',
        bookingDeadlineAt: DateTime.utc(2026, 9, 30, 10, 5),
      ),
      paymentOrder: const PaymentOrder(
        id: 'order1',
        appointmentId: 'appt1',
        amountPaise: 52400,
        currency: 'INR',
        gatewayOrderId: 'order_x',
        keyId: 'rzp_test',
        status: PaymentOrderStatus.created,
      ),
    );
  }

  @override
  Future<FeeQuote> feeQuote({
    required String doctorId,
    String? personId,
    String? couponCode,
  }) => throw UnimplementedError();

  @override
  Future<List<PersonSummary>> persons() async => const [];

  @override
  Future<TokenCard> tokenCard(String appointmentId) =>
      throw UnimplementedError();
}

class _FakeAvailability implements AvailabilityRepository {
  int invalidations = 0;

  @override
  Future<void> invalidateSlots() async => invalidations++;

  @override
  Stream<CachedResult<DoctorAvailability>> availability(
    String doctorId, {
    String? from,
    String? to,
    bool forceRefresh = false,
  }) => const Stream.empty();

  @override
  Stream<CachedResult<DaySlots>> slots(
    String doctorId, {
    required String date,
    bool forceRefresh = false,
  }) => const Stream.empty();
}
