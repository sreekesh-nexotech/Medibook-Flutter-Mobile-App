import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/booking/presentation/components/coupon_field.dart';

/// UB-27: a refused coupon shows the server's own `coupon.message` — only
/// the server knows which rule (department, start date, online only) refused
/// it. House wording is the fallback when no sentence came.
void main() {
  group('CouponField.reasonText', () {
    test('prefers the server sentence', () {
      expect(
        CouponField.reasonText(
          'COUPON_NOT_APPLICABLE',
          "This coupon cannot be used for this doctor's department.",
        ),
        "This coupon cannot be used for this doctor's department.",
      );
    });

    test('falls back to house wording, including the newer reasons', () {
      expect(
        CouponField.reasonText('COUPON_INVALID'),
        'That coupon code is not valid.',
      );
      expect(
        CouponField.reasonText('COUPON_NOT_STARTED', '  '),
        'That coupon is not valid yet.',
      );
      expect(
        CouponField.reasonText('COUPON_NOT_APPLICABLE'),
        'That coupon cannot be used for this booking.',
      );
      expect(
        CouponField.reasonText('SOMETHING_NEW'),
        'That coupon could not be applied.',
      );
      expect(CouponField.reasonText(null, 'ignored'), isNull);
    });
  });

  testWidgets('the field shows the server sentence under the code', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 835),
        builder: (_, _) => MaterialApp(
          home: Scaffold(
            body: CouponField(
              appliedCode: null,
              discountPaise: 0,
              onApply: (_) {},
              onRemove: () {},
              rejectionCode: 'COUPON_NOT_APPLICABLE',
              rejectionMessage:
                  "This coupon cannot be used for this doctor's department.",
            ),
          ),
        ),
      ),
    );
    expect(
      find.text("This coupon cannot be used for this doctor's department."),
      findsOneWidget,
    );
    expect(find.text('That coupon could not be applied.'), findsNothing);
  });
}
