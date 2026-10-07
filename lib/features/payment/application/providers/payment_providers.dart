import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../booking/domain/entities/booking_result.dart';
import '../../../booking/domain/entities/payment_order.dart';
import '../../domain/entities/checkout_outcome.dart';
import '../../domain/repositories/checkout_gateway.dart';
import '../../domain/repositories/payment_repository.dart';
import '../states/payment_flow_state.dart';
import '../../../../core/utils/server_clock.dart';

/// The payment repository — abstract type, so tests override it.
final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) =>
      throw UnimplementedError('paymentRepositoryProvider is wired in app/di'),
);

/// The gateway SDK. autoDispose: the SDK holds platform listeners that must
/// be released when the payment screens go away.
final checkoutGatewayProvider = Provider.autoDispose<CheckoutGateway>(
  (ref) =>
      throw UnimplementedError('checkoutGatewayProvider is wired in app/di'),
);

/// The booking to resume from an appointment ("Retry payment", §9.4) —
/// `GET /patient/appointments/{id}` and its `payment_order`. autoDispose:
/// one visit to the payment screen. Errors are `Failure`s from the repository.
final resumedBookingProvider = FutureProvider.autoDispose
    .family<BookingResult, ({String appointmentId, String? orderId})>((
      ref,
      key,
    ) {
      final repository = ref.watch(paymentRepositoryProvider);
      return guardedRead(
        'resumed booking',
        () => repository.booking(key.appointmentId, orderId: key.orderId),
      );
    });

/// Who the gateway sheet is prefilled for.
typedef CheckoutContact = ({String? name, String? phone, String? email});

/// Drives one booking's payment (§9.2–§9.6): open the SDK, verify, retry,
/// poll, and expire. No navigation and no `BuildContext` — the screen reads
/// [PaymentFlowState.phase] and decides where to go.
class PaymentFlowController extends StateNotifier<PaymentFlowState> {
  PaymentFlowController({
    required PaymentRepository repository,
    required CheckoutGateway gateway,
    String Function()? mintKey,
    DateTime Function()? now,
  }) : _repository = repository,
       _gateway = gateway,
       _mintKey = mintKey ?? IdempotencyKeys.mint,
       // The server's clock: the deadline is the server's (BL-CORE-007).
       _now = now ?? ServerClock.now,
       super(const PaymentFlowState());

  final PaymentRepository _repository;
  final CheckoutGateway _gateway;
  final String Function() _mintKey;
  final DateTime Function() _now;

  /// Load the booking's order and appointment. Idempotent for the same
  /// order, so the screen can call it on every entry.
  void start(BookingResult booking) {
    if (state.order?.id == booking.paymentOrder.id) return;
    state = PaymentFlowState(
      order: booking.paymentOrder,
      appointment: booking.appointment,
      phase: booking.paymentOrder.isPaid
          ? PaymentPhase.paid
          : PaymentPhase.idle,
    );
  }

  bool get _deadlinePassed {
    final deadline = state.deadline;
    return deadline != null && !_now().toUtc().isBefore(deadline);
  }

  /// Open the gateway for the current order, then verify. Returns the phase
  /// the flow ended in. Refused (returns the current phase unchanged) while
  /// an attempt is running or the booking is settled.
  Future<PaymentPhase> pay({CheckoutContact? contact}) async {
    final order = state.order;
    if (order == null || state.phase.isBusy || state.phase.isFinal) {
      return state.phase;
    }
    if (_deadlinePassed) {
      state = state.copyWith(phase: PaymentPhase.expired);
      return state.phase;
    }
    // The staging backend returns an empty `key_id` when no gateway key is
    // configured (integration gaps). The SDK would reject that with an
    // opaque INVALID_OPTIONS; say what is actually wrong instead.
    if (order.keyId.isEmpty || order.gatewayOrderId.isEmpty) {
      state = state.copyWith(
        phase: PaymentPhase.failed,
        failureMessage: () =>
            'Online payment is not set up for this hospital yet, so this '
            'booking cannot be paid in the app. Nothing has been charged.',
      );
      return state.phase;
    }

    state = state.copyWith(
      phase: PaymentPhase.checkout,
      failure: () => null,
      failureMessage: () => null,
      wasCancelled: false,
    );

    final CheckoutOutcome outcome;
    try {
      outcome = await _gateway.open(
        order,
        contactName: contact?.name,
        contactPhone: contact?.phone,
        contactEmail: contact?.email,
        description: state.appointment?.bookingRef,
      );
    } catch (error, stack) {
      AppLogger.error(
        'Checkout gateway threw',
        name: 'payment',
        error: error,
        stackTrace: stack,
      );
      state = state.copyWith(
        phase: PaymentPhase.failed,
        failureMessage: () =>
            'The payment sheet could not be opened. Please try again.',
      );
      return state.phase;
    }

    switch (outcome) {
      case CheckoutSucceeded(:final paymentId, :final signature):
        return verify(paymentId: paymentId, signature: signature);
      case CheckoutFailed(:final message, :final cancelled):
        state = state.copyWith(
          phase: PaymentPhase.failed,
          failureMessage: () => message,
          wasCancelled: cancelled,
        );
        return state.phase;
      case CheckoutExternalWallet():
        // The wallet app reports to the backend, not to us: read the order.
        return refreshOrder();
    }
  }

  /// `POST …/verify` (§9.3). Reuses the verify key for the same order so a
  /// lost response is replayed, never double-recorded.
  Future<PaymentPhase> verify({
    required String paymentId,
    required String signature,
  }) async {
    final order = state.order;
    if (order == null) return state.phase;
    final key = state.verifyKey ?? _mintKey();
    state = state.copyWith(
      phase: PaymentPhase.verifying,
      verifyKey: () => key,
      failure: () => null,
    );
    try {
      final result = await _repository.verify(
        orderId: order.id,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
        idempotencyKey: key,
      );
      state = state.copyWith(
        order: () => result.order,
        appointment: () => result.appointment,
        payment: () => result.payment,
        phase: result.isPaid
            ? (result.needsHospitalApproval
                  ? PaymentPhase.pendingApproval
                  : PaymentPhase.paid)
            : result.isLatePayment
            ? PaymentPhase.latePayment
            : PaymentPhase.failed,
        failureMessage: () => result.isPaid || result.isLatePayment
            ? null
            : 'The payment was not confirmed. No money has left your '
                  'account.',
      );
    } on Failure catch (failure) {
      final signatureInvalid =
          failure.apiCode == ApiErrorCodes.paymentSignatureInvalid;
      state = state.copyWith(
        phase: PaymentPhase.failed,
        failure: () => failure,
        failureMessage: () => signatureInvalid
            ? 'The payment could not be verified. If money left your '
                  'account it will be refunded automatically.'
            : failure.userMessage,
      );
    } catch (error, stack) {
      state = state.copyWith(
        phase: PaymentPhase.failed,
        failure: () => error.asFailure(stack),
        failureMessage: () =>
            'Something went wrong while confirming the '
            'payment. Please try again.',
      );
    }
    return state.phase;
  }

  /// `POST …/retry` (§9.4): a **new** order for the same booking, then
  /// checkout again. The deadline is not extended.
  Future<PaymentPhase> retry({CheckoutContact? contact}) async {
    final order = state.order;
    if (order == null || state.phase.isBusy || state.phase.isFinal) {
      return state.phase;
    }
    if (_deadlinePassed) {
      state = state.copyWith(phase: PaymentPhase.expired);
      return state.phase;
    }
    final key = state.retryKey ?? _mintKey();
    state = state.copyWith(
      phase: PaymentPhase.retrying,
      retryKey: () => key,
      failure: () => null,
      failureMessage: () => null,
      wasCancelled: false,
    );
    try {
      final fresh = await _repository.retry(
        orderId: order.id,
        idempotencyKey: key,
      );
      state = state.copyWith(
        order: () => fresh,
        phase: PaymentPhase.idle,
        // A new order is a new payment: fresh verify key, spent retry key.
        verifyKey: () => null,
        retryKey: () => null,
      );
      return pay(contact: contact);
    } on Failure catch (failure) {
      if (failure.apiCode == ApiErrorCodes.paymentAlreadyCaptured) {
        return refreshOrder();
      }
      if (failure.apiCode == ApiErrorCodes.appointmentNotActionable) {
        state = state.copyWith(
          phase: PaymentPhase.expired,
          failure: () => failure,
        );
        return state.phase;
      }
      state = state.copyWith(
        phase: PaymentPhase.failed,
        failure: () => failure,
        failureMessage: () => failure.userMessage,
      );
      return state.phase;
    } catch (error, stack) {
      state = state.copyWith(
        phase: PaymentPhase.failed,
        failure: () => error.asFailure(stack),
        failureMessage: () =>
            'A new payment could not be started. Please '
            'try again.',
      );
      return state.phase;
    }
  }

  /// `GET …/orders/{id}` (§9.5): after the app comes back from checkout with
  /// no result, or after an external-wallet hand-off.
  Future<PaymentPhase> refreshOrder() async {
    final order = state.order;
    if (order == null) return state.phase;
    if (state.phase.isSettled) return state.phase;
    final before = state.phase;
    state = state.copyWith(phase: PaymentPhase.polling, failure: () => null);
    try {
      final fresh = await _repository.order(order.id);
      final PaymentPhase next;
      if (fresh.isPaid) {
        next = state.appointment?.isPendingApproval == true
            ? PaymentPhase.pendingApproval
            : PaymentPhase.paid;
      } else if (fresh.status == PaymentOrderStatus.expired ||
          fresh.status == PaymentOrderStatus.cancelled ||
          _deadlinePassed) {
        next = PaymentPhase.expired;
      } else if (fresh.status == PaymentOrderStatus.failed) {
        next = PaymentPhase.failed;
      } else {
        // Still payable: return to wherever the poll started, but never to
        // a busy phase — a poll started mid-step lands on idle.
        next = before.isBusy ? PaymentPhase.idle : before;
      }
      state = state.copyWith(
        order: () => fresh,
        phase: next,
        failureMessage: () => next == PaymentPhase.failed
            ? 'The last payment attempt did not go through. Nothing has '
                  'been charged.'
            : state.failureMessage,
      );
    } on Failure catch (failure) {
      state = state.copyWith(
        phase: before.isBusy ? PaymentPhase.idle : before,
        failure: () => failure,
      );
    } catch (error, stack) {
      state = state.copyWith(
        phase: before.isBusy ? PaymentPhase.idle : before,
        failure: () => error.asFailure(stack),
      );
    }
    return state.phase;
  }

  /// The countdown reached `booking_deadline_at` (§9.6).
  void expire() {
    if (state.phase.isSettled) return;
    state = state.copyWith(phase: PaymentPhase.expired);
  }

  void clearFailure() => state = state.copyWith(
    failure: () => null,
    failureMessage: () => null,
    wasCancelled: false,
  );
}

/// The payment flow for the booking on screen. autoDispose: it lives with
/// the payment and result screens that watch it, and the SDK listeners go
/// with it.
final paymentFlowProvider =
    StateNotifierProvider.autoDispose<PaymentFlowController, PaymentFlowState>(
      (ref) => PaymentFlowController(
        repository: ref.watch(paymentRepositoryProvider),
        gateway: ref.watch(checkoutGatewayProvider),
      ),
    );
