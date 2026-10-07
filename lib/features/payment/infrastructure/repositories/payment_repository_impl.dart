import '../../../../core/error/failure.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../booking/domain/entities/booking_result.dart';
import '../../../booking/domain/entities/payment_order.dart';
import '../../../booking/infrastructure/repositories/booking_mappers.dart';
import '../../domain/entities/payment_record.dart';
import '../../domain/entities/payment_verification.dart';
import '../../domain/repositories/payment_repository.dart';
import '../data_sources/remote/payment_api.dart';

/// [PaymentRepository] over [PaymentApi]. Every throw is a `Failure`.
class PaymentRepositoryImpl implements PaymentRepository {
  const PaymentRepositoryImpl({required PaymentApi api}) : _api = api;

  final PaymentApi _api;

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (error, stack) {
      final failure = NetworkExceptions.toFailure(error, stack);
      AppLogger.warning(
        'Payment call failed: ${failure.code}/${failure.apiCode}',
        name: 'payment',
        error: failure.cause,
      );
      Error.throwWithStackTrace(failure, stack);
    }
  }

  @override
  Future<PaymentVerification> verify({
    required String orderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required String idempotencyKey,
  }) => _run(() async {
    final json = await _api.verify(
      orderId: orderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
      idempotencyKey: idempotencyKey,
    );
    return PaymentMappers.verification(json);
  });

  @override
  Future<PaymentOrder> retry({
    required String orderId,
    required String idempotencyKey,
  }) => _run(() async {
    final json = await _api.retry(
      orderId: orderId,
      idempotencyKey: idempotencyKey,
    );
    return BookingMappers.paymentOrder(json);
  });

  @override
  Future<PaymentOrder> order(String orderId) =>
      _run(() async => BookingMappers.paymentOrder(await _api.order(orderId)));

  @override
  Future<BookingResult> booking(String appointmentId, {String? orderId}) =>
      _run(() async {
        final json = await _api.appointment(appointmentId);
        final appointment = BookingMappers.appointment(json);
        final embedded = json['payment_order'];
        final PaymentOrder order;
        if (embedded is Map) {
          order = BookingMappers.paymentOrder(embedded.cast<String, Object?>());
        } else if (orderId != null) {
          order = BookingMappers.paymentOrder(await _api.order(orderId));
        } else {
          throw NotFoundFailure(
            resource: 'payment_order',
            debugMessage: 'appointment $appointmentId has no payment order',
          );
        }
        return BookingResult(appointment: appointment, paymentOrder: order);
      });
}

/// JSON → payment entities (§9.3, §10.11).
abstract final class PaymentMappers {
  PaymentMappers._();

  static PaymentVerification verification(Map<String, Object?> json) {
    final order = BookingMappers.paymentOrder(
      BookingMappers.obj(json['order'], 'verify.order'),
    );
    final payment = json['payment'];
    return PaymentVerification(
      status: PaymentOrderStatus.fromWire(
        BookingMappers.optStr(json, 'status') ?? order.status.wire,
      ),
      order: order,
      payment: payment is Map
          ? paymentRecord(payment.cast<String, Object?>())
          : null,
      appointment: BookingMappers.appointment(
        BookingMappers.obj(json['appointment'], 'verify.appointment'),
      ),
    );
  }

  static PaymentRecord paymentRecord(Map<String, Object?> json) =>
      PaymentRecord(
        id: BookingMappers.str(json, 'id'),
        orderId: BookingMappers.optStr(json, 'order_id') ?? '',
        appointmentId: BookingMappers.optStr(json, 'appointment_id') ?? '',
        amountPaise: BookingMappers.optInt(json, 'amount_paise') ?? 0,
        method: BookingMappers.optStr(json, 'method'),
        gateway: BookingMappers.optStr(json, 'gateway'),
        status: BookingMappers.optStr(json, 'status') ?? '',
        capturedAt: BookingMappers.optDateTime(json, 'captured_at'),
        failureCode: BookingMappers.optStr(json, 'failure_code'),
        failureReason: BookingMappers.optStr(json, 'failure_reason'),
        createdAt: BookingMappers.optDateTime(json, 'created_at'),
      );
}
