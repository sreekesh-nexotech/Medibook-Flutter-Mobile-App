import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../../core/utils/logger.dart';
import '../../../../booking/domain/entities/payment_order.dart';
import '../../../domain/entities/checkout_outcome.dart';
import '../../../domain/repositories/checkout_gateway.dart';

/// [CheckoutGateway] over the `razorpay_flutter` SDK (§9.2).
///
/// The SDK is event-driven; this turns one `open` into one `Future` so the
/// controller can `await` it. The four inputs come straight from the
/// [PaymentOrder] — nothing here computes an amount or lists a method.
class RazorpayCheckoutGateway implements CheckoutGateway {
  RazorpayCheckoutGateway({Razorpay? razorpay, this.merchantName = 'Medibook'})
    : _razorpay = razorpay ?? Razorpay() {
    _razorpay
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  final Razorpay _razorpay;
  final String merchantName;
  Completer<CheckoutOutcome>? _pending;

  @override
  Future<CheckoutOutcome> open(
    PaymentOrder order, {
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    String? description,
  }) {
    final running = _pending;
    if (running != null && !running.isCompleted) return running.future;

    final completer = Completer<CheckoutOutcome>();
    _pending = completer;
    try {
      _razorpay.open({
        'key': order.keyId,
        'order_id': order.gatewayOrderId,
        'amount': order.amountPaise,
        'currency': order.currency,
        'name': merchantName,
        'description': ?description,
        'prefill': {
          'name': ?contactName,
          'contact': ?contactPhone,
          'email': ?contactEmail,
        },
        'retry': {'enabled': false},
        'timeout': _checkoutTimeout.inSeconds,
      });
    } catch (error, stack) {
      AppLogger.error(
        'Razorpay open() threw',
        name: 'payment',
        error: error,
        stackTrace: stack,
      );
      _complete(
        const CheckoutFailed(
          message: 'The payment sheet could not be opened. Please try again.',
        ),
      );
    }
    return completer.future;
  }

  /// The SDK's own sheet timeout; the booking deadline is enforced by the
  /// backend regardless.
  static const Duration _checkoutTimeout = Duration(minutes: 5);

  void _onSuccess(PaymentSuccessResponse response) {
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (paymentId == null || signature == null) {
      _complete(
        const CheckoutFailed(
          message:
              'The payment could not be confirmed. If money left your '
              'account it will be refunded.',
        ),
      );
      return;
    }
    _complete(
      CheckoutSucceeded(
        paymentId: paymentId,
        signature: signature,
        orderId: response.orderId,
      ),
    );
  }

  void _onError(PaymentFailureResponse response) {
    final code = response.code;
    final cancelled = code == Razorpay.PAYMENT_CANCELLED;
    AppLogger.info(
      'Razorpay checkout ended: code=$code cancelled=$cancelled',
      name: 'payment',
    );
    _complete(
      CheckoutFailed(
        code: code,
        cancelled: cancelled,
        message: cancelled
            ? 'You closed the payment sheet before paying. Nothing has been '
                  'charged.'
            : switch (code) {
                Razorpay.NETWORK_ERROR =>
                  'The payment could not reach the bank. Check your '
                      'connection and try again.',
                Razorpay.TLS_ERROR =>
                  'A secure connection to the payment gateway could not be '
                      'made.',
                Razorpay.INVALID_OPTIONS || Razorpay.INCOMPATIBLE_PLUGIN =>
                  'The payment could not be started. Please try again in a '
                      'moment.',
                _ =>
                  'The bank declined this payment. No money has left your '
                      'account.',
              },
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) =>
      _complete(CheckoutExternalWallet(walletName: response.walletName));

  void _complete(CheckoutOutcome outcome) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    pending.complete(outcome);
  }

  @override
  void dispose() {
    _razorpay.clear();
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.complete(
        const CheckoutFailed(
          message: 'The payment sheet was closed.',
          cancelled: true,
        ),
      );
    }
    _pending = null;
  }
}
