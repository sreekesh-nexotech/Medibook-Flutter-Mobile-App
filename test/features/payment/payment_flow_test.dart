import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/booking/domain/entities/booked_appointment.dart';
import 'package:medibook/features/booking/domain/entities/booking_result.dart';
import 'package:medibook/features/booking/domain/entities/payment_order.dart';
import 'package:medibook/features/payment/application/providers/payment_providers.dart';
import 'package:medibook/features/payment/application/states/payment_flow_state.dart';
import 'package:medibook/features/payment/domain/entities/checkout_outcome.dart';
import 'package:medibook/features/payment/domain/entities/payment_record.dart';
import 'package:medibook/features/payment/domain/entities/payment_verification.dart';
import 'package:medibook/features/payment/domain/repositories/checkout_gateway.dart';
import 'package:medibook/features/payment/domain/repositories/payment_repository.dart';

/// `PaymentFlowController` against a scripted gateway and repository —
/// every §9.3–§9.6 outcome, with no SDK and no network.
void main() {
  late _FakeGateway gateway;
  late _FakeRepository repository;
  late PaymentFlowController controller;
  final now = DateTime.utc(2026, 9, 30, 10, 1);

  setUp(() {
    gateway = _FakeGateway();
    repository = _FakeRepository();
    var minted = 0;
    controller = PaymentFlowController(
      repository: repository,
      gateway: gateway,
      mintKey: () => 'key-${++minted}',
      now: () => now,
    );
    controller.start(_booking());
  });

  test('start loads the order and the deadline', () {
    expect(controller.state.phase, PaymentPhase.idle);
    expect(controller.state.amountPaise, 48000);
    expect(controller.state.deadline, DateTime.utc(2026, 9, 30, 10, 5));
  });

  test('checkout success → verify → paid', () async {
    gateway.outcome = const CheckoutSucceeded(
      paymentId: 'pay_1',
      signature: 'sig',
    );
    final phase = await controller.pay();
    expect(phase, PaymentPhase.paid);
    expect(gateway.openedWith?.gatewayOrderId, 'order_NXa');
    expect(repository.verified, [('order1', 'pay_1', 'sig', 'key-1')]);
    expect(controller.state.payment?.methodLabel, 'UPI');
  });

  test('paid with pending_approval says the hospital will confirm', () async {
    gateway.outcome = const CheckoutSucceeded(paymentId: 'p', signature: 's');
    repository.appointmentStatus = AppointmentStatus.pendingApproval;
    expect(await controller.pay(), PaymentPhase.pendingApproval);
  });

  test('a late payment is cancelled and refunded', () async {
    gateway.outcome = const CheckoutSucceeded(paymentId: 'p', signature: 's');
    repository.orderStatus = PaymentOrderStatus.failed;
    repository.appointmentStatus = AppointmentStatus.cancelled;
    expect(await controller.pay(), PaymentPhase.latePayment);
  });

  test('PAYMENT_SIGNATURE_INVALID is a failed payment', () async {
    gateway.outcome = const CheckoutSucceeded(paymentId: 'p', signature: 'bad');
    repository.verifyFailure = const ValidationFailure(
      apiCode: ApiErrorCodes.paymentSignatureInvalid,
    );
    expect(await controller.pay(), PaymentPhase.failed);
    expect(controller.state.failureMessage, contains('could not be verified'));
  });

  test('a closed sheet is a cancelled attempt, not a decline', () async {
    gateway.outcome = const CheckoutFailed(message: 'closed', cancelled: true);
    expect(await controller.pay(), PaymentPhase.failed);
    expect(controller.state.wasCancelled, isTrue);
  });

  test(
    'retry mints a new order, resets the verify key and pays again',
    () async {
      gateway.outcome = const CheckoutFailed(message: 'declined');
      await controller.pay();
      expect(controller.state.phase, PaymentPhase.failed);

      gateway.outcome = const CheckoutSucceeded(
        paymentId: 'p2',
        signature: 's2',
      );
      final phase = await controller.retry();
      expect(phase, PaymentPhase.paid);
      expect(repository.retried, ['key-1']);
      expect(controller.state.order?.id, 'order2');
      // The verify of the new order used a fresh key.
      expect(repository.verified.single.$4, 'key-2');
    },
  );

  test(
    'retry after PAYMENT_ALREADY_CAPTURED polls and lands on paid',
    () async {
      gateway.outcome = const CheckoutFailed(message: 'declined');
      await controller.pay();
      repository.retryFailure = const ConflictFailure(
        apiCode: ApiErrorCodes.paymentAlreadyCaptured,
      );
      repository.polledStatus = PaymentOrderStatus.paid;
      expect(await controller.retry(), PaymentPhase.paid);
    },
  );

  test('retry after APPOINTMENT_NOT_ACTIONABLE is expired', () async {
    gateway.outcome = const CheckoutFailed(message: 'declined');
    await controller.pay();
    repository.retryFailure = const ConflictFailure(
      apiCode: ApiErrorCodes.appointmentNotActionable,
    );
    expect(await controller.retry(), PaymentPhase.expired);
  });

  test('paying after the deadline is refused as expired', () async {
    controller = PaymentFlowController(
      repository: repository,
      gateway: gateway,
      now: () => DateTime.utc(2026, 9, 30, 10, 6),
    )..start(_booking());
    expect(await controller.pay(), PaymentPhase.expired);
    expect(gateway.openedWith, isNull);
  });

  test('an order without a gateway key fails before the SDK opens', () async {
    controller =
        PaymentFlowController(
          repository: repository,
          gateway: gateway,
          now: () => now,
        )..start(
          BookingResult(
            appointment: _appointment(AppointmentStatus.pendingPayment),
            paymentOrder: const PaymentOrder(
              id: 'order1',
              appointmentId: 'appt1',
              amountPaise: 48000,
              currency: 'INR',
              gatewayOrderId: 'order_fake',
              keyId: '',
              status: PaymentOrderStatus.created,
            ),
          ),
        );
    expect(await controller.pay(), PaymentPhase.failed);
    expect(gateway.openedWith, isNull);
    expect(controller.state.failureMessage, contains('not set up'));
  });

  test('an external wallet hand-off polls the order', () async {
    gateway.outcome = const CheckoutExternalWallet(walletName: 'paytm');
    repository.polledStatus = PaymentOrderStatus.paid;
    expect(await controller.pay(), PaymentPhase.paid);
  });

  test('a second pay while the sheet is open is refused', () async {
    gateway.hold = true;
    final first = controller.pay();
    expect(await controller.pay(), PaymentPhase.checkout);
    gateway.release(const CheckoutSucceeded(paymentId: 'p', signature: 's'));
    expect(await first, PaymentPhase.paid);
    expect(gateway.opens, 1);
  });
}

BookingResult _booking() => BookingResult(
  appointment: _appointment(AppointmentStatus.pendingPayment),
  paymentOrder: const PaymentOrder(
    id: 'order1',
    appointmentId: 'appt1',
    amountPaise: 48000,
    currency: 'INR',
    gatewayOrderId: 'order_NXa',
    keyId: 'rzp_test',
    status: PaymentOrderStatus.created,
    expiresAt: null,
  ),
);

BookedAppointment _appointment(AppointmentStatus status) => BookedAppointment(
  id: 'appt1',
  bookingRef: 'MB-2026-000124',
  status: status,
  paymentStatus: status == AppointmentStatus.cancelled
      ? AppointmentPaymentStatus.refunded
      : AppointmentPaymentStatus.paid,
  hospitalId: 'h1',
  hospitalName: 'H',
  departmentName: 'Cardiology',
  doctorId: 'doc1',
  doctorName: 'Dr. Test',
  personId: 'p1',
  scheduledDate: '2026-10-01',
  scheduledStartAt: DateTime.utc(2026, 10, 1, 3, 30),
  scheduledEndAt: DateTime.utc(2026, 10, 1, 3, 45),
  consultationFeePaise: 50000,
  serviceFeePaise: 0,
  discountPaise: 5000,
  convenienceFeePaise: 2500,
  taxPaise: 500,
  totalPaise: 48000,
  currency: 'INR',
  version: 2,
  bookingDeadlineAt: DateTime.utc(2026, 9, 30, 10, 5),
);

class _FakeGateway implements CheckoutGateway {
  CheckoutOutcome outcome = const CheckoutFailed(message: 'unset');
  PaymentOrder? openedWith;
  int opens = 0;
  bool hold = false;
  Completer<CheckoutOutcome>? _held;

  void release(CheckoutOutcome result) => _held?.complete(result);

  @override
  Future<CheckoutOutcome> open(
    PaymentOrder order, {
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    String? description,
  }) {
    opens++;
    openedWith = order;
    if (!hold) return Future.value(outcome);
    _held = Completer<CheckoutOutcome>();
    return _held!.future;
  }

  @override
  void dispose() {}
}

class _FakeRepository implements PaymentRepository {
  @override
  Future<BookingResult> booking(String appointmentId, {String? orderId}) =>
      throw UnimplementedError();

  PaymentOrderStatus orderStatus = PaymentOrderStatus.paid;
  AppointmentStatus appointmentStatus = AppointmentStatus.scheduled;
  PaymentOrderStatus polledStatus = PaymentOrderStatus.created;
  Failure? verifyFailure;
  Failure? retryFailure;
  final List<(String, String, String, String)> verified = [];
  final List<String> retried = [];

  @override
  Future<PaymentVerification> verify({
    required String orderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String idempotencyKey,
  }) async {
    verified.add((
      orderId,
      razorpayPaymentId,
      razorpaySignature,
      idempotencyKey,
    ));
    final failure = verifyFailure;
    if (failure != null) throw failure;
    return PaymentVerification(
      status: orderStatus,
      order: _order(orderId, orderStatus),
      appointment: _appointment(appointmentStatus),
      payment: orderStatus.isPaid
          ? PaymentRecord(
              id: 'pay1',
              orderId: orderId,
              appointmentId: 'appt1',
              amountPaise: 48000,
              method: 'upi',
              status: 'captured',
            )
          : null,
    );
  }

  @override
  Future<PaymentOrder> retry({
    required String orderId,
    required String idempotencyKey,
  }) async {
    retried.add(idempotencyKey);
    final failure = retryFailure;
    if (failure != null) throw failure;
    return _order('order2', PaymentOrderStatus.created, attempts: 2);
  }

  @override
  Future<PaymentOrder> order(String orderId) async =>
      _order(orderId, polledStatus);

  static PaymentOrder _order(
    String id,
    PaymentOrderStatus status, {
    int attempts = 1,
  }) => PaymentOrder(
    id: id,
    appointmentId: 'appt1',
    amountPaise: 48000,
    currency: 'INR',
    gatewayOrderId: 'order_$id',
    keyId: 'rzp_test',
    status: status,
    attempts: attempts,
  );
}
