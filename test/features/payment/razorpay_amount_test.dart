import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/utils/money.dart';
import 'package:medibook/features/booking/domain/entities/payment_order.dart';
import 'package:medibook/features/payment/domain/entities/checkout_outcome.dart';
import 'package:medibook/features/payment/infrastructure/data_sources/remote/razorpay_checkout_gateway.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Checklist UI-010 (owner, 6 Oct 2026): the amount the patient sees on the
/// Pay button is the amount Razorpay is opened with — both come from the
/// server's payment order, never from a sum the app works out.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final paise in [42400, 42450, 100000]) {
    test('Razorpay gets the order amount the button shows ($paise paise)', () {
      final razorpay = _RecordingRazorpay();
      final gateway = RazorpayCheckoutGateway(razorpay: razorpay);
      final order = PaymentOrder(
        id: 'po-1',
        appointmentId: 'appt-1',
        amountPaise: paise,
        currency: 'INR',
        gatewayOrderId: 'order_test',
        keyId: 'rzp_test_key',
        status: PaymentOrderStatus.created,
      );

      gateway.open(order);

      final options = razorpay.opened.single;
      expect(options['amount'], paise);
      expect(options['currency'], 'INR');
      expect(options['order_id'], 'order_test');
      // The button reads 'Pay <Money.inr(order.amountPaise)> with Razorpay'.
      final shown = Money.inr(paise);
      final shownPaise =
          (double.parse(shown.replaceAll(RegExp('[^0-9.]'), '')) * 100).round();
      expect(shownPaise, options['amount'], reason: shown);
    });
  }

  // UAT RUN3 (live Razorpay test mode): the bank's "Failure" came back as
  // PAYMENT_CANCELLED and the app said the patient had closed the sheet.
  group('payment error', () {
    const order = PaymentOrder(
      id: 'po-1',
      appointmentId: 'appt-1',
      amountPaise: 92400,
      currency: 'INR',
      gatewayOrderId: 'order_test',
      keyId: 'rzp_test_key',
      status: PaymentOrderStatus.created,
    );

    Future<CheckoutFailed> fail(Map<dynamic, dynamic> error) async {
      final razorpay = _RecordingRazorpay();
      final outcome = RazorpayCheckoutGateway(razorpay: razorpay).open(order);
      razorpay.handlers[Razorpay.EVENT_PAYMENT_ERROR]!(
        PaymentFailureResponse(Razorpay.PAYMENT_CANCELLED, 'x', error),
      );
      return await outcome as CheckoutFailed;
    }

    test('a declined payment is not reported as a closed sheet', () async {
      final failed = await fail({
        'reason': 'payment_failed',
        'description': 'declined by the bank',
        'metadata': {'payment_id': 'pay_1', 'order_id': 'order_test'},
      });
      expect(failed.cancelled, isFalse);
      expect(failed.message, contains('declined'));
    });

    test('closing the sheet is still a cancellation', () async {
      final failed = await fail({
        'reason': 'payment_cancelled',
        'metadata': <String, String>{},
      });
      expect(failed.cancelled, isTrue);
      expect(failed.message, contains('closed the payment sheet'));
    });
  });
}

class _RecordingRazorpay extends Razorpay {
  final List<Map<String, dynamic>> opened = [];

  @override
  void open(Map<String, dynamic> options) => opened.add(options);

  final Map<String, Function> handlers = {};

  @override
  void on(String event, Function handler, {bool rawMap = false}) =>
      handlers[event] = handler;
}
