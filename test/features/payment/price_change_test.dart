import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/payment/domain/entities/price_change.dart';

/// BL-BOOK-035 (owner decision): a booking that costs something other than
/// the total shown at confirmation must be pointed out before the patient
/// pays.
void main() {
  test('the same total is not a change', () {
    expect(PriceChange.between(quotedPaise: 42400, duePaise: 42400), isNull);
  });

  test('no quote in this session means nothing to compare', () {
    expect(PriceChange.between(quotedPaise: null, duePaise: 42400), isNull);
  });

  test('a higher total is a change, flagged as an increase', () {
    final change = PriceChange.between(quotedPaise: 42400, duePaise: 52400);
    expect(change, isNotNull);
    expect(change!.quotedPaise, 42400);
    expect(change.duePaise, 52400);
    expect(change.isIncrease, isTrue);
  });

  test('a lower total is still a change the patient is told about', () {
    final change = PriceChange.between(quotedPaise: 52400, duePaise: 42400);
    expect(change, isNotNull);
    expect(change!.isIncrease, isFalse);
  });
}
