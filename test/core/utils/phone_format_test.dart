import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/utils/phone.dart';

void main() {
  group('PhoneFormat.display', () {
    test('an Indian number is split 5 + 5 after the code', () {
      expect(PhoneFormat.display('+919808659500'), '+91 98086 59500');
    });

    test('another listed country gets a space after its code', () {
      expect(PhoneFormat.display('+971501234567'), '+971 501234567');
      expect(PhoneFormat.display('+12025550123'), '+1 2025550123');
    });

    test('anything not recognised is shown as stored', () {
      expect(PhoneFormat.display('+4930123456'), '+4930123456');
      expect(PhoneFormat.display('+91123'), '+91123');
    });
  });
}
