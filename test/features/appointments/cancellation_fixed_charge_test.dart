import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/utils/money.dart';
import 'package:medibook/features/appointments/domain/entities/cancellation_preview.dart';
import 'package:medibook/features/appointments/infrastructure/repositories/appointment_mappers.dart';
import 'package:medibook/features/appointments/presentation/components/cancellation_notice.dart';
import 'package:medibook/features/booking/infrastructure/repositories/booking_mappers.dart';

/// Q10 (client workbook, 19 Oct 2026, "keep both options"): a hospital may
/// keep a fixed cancellation charge instead of refunding a percentage; Q11: a
/// hospital cancellation refunds the doctor's fee, not the convenience fee.
void main() {
  test('the preview maps the fixed charge and never shows a percentage', () {
    final preview = AppointmentMappers.cancellationPreview(const {
      'allowed': true,
      'before_cutoff': true,
      'charge_mode': 'fixed',
      'refund_bp': 10000,
      'cancellation_charge_paise': 5000,
      'refund_paise': 35050,
      'non_refundable_paise': 7400,
      'includes_convenience_fee': false,
    });
    expect(preview.isFixedCharge, isTrue);
    expect(preview.cancellationCharge, Money.paise(5000));
    final text = CancellationNotice.consequence(preview);
    expect(text, contains('${Money.paise(35050).format()} goes back'));
    expect(text, contains('${Money.paise(5000).format()} cancellation charge'));
    expect(text, contains('the convenience fee'));
    expect(text, isNot(contains('%')));
  });

  test('a charge that covers everything says so', () {
    const preview = CancellationPreview(
      allowed: true,
      refundBp: 10000,
      refund: Money.zero,
      nonRefundable: Money.paise(42400),
      chargeMode: 'fixed',
      cancellationCharge: Money.paise(50000),
    );
    expect(
      CancellationNotice.consequence(preview),
      contains('cancellation charge covers what was paid'),
    );
  });

  test('the hospital policy carries the fixed charges and the Q11 flag', () {
    final policy = BookingMappers.cancellationPolicy(const {
      'cutoff_hours': 4,
      'refund_before_cutoff_bp': 10000,
      'refund_after_cutoff_bp': 0,
      'refund_includes_convenience_fee': false,
      'cancellation_charge_mode': 'fixed',
      'cancellation_charge_before_cutoff_paise': 5000,
      'cancellation_charge_after_cutoff_paise': 20000,
      'hospital_cancellation_refund_bp': 10000,
      'hospital_cancellation_refunds_convenience_fee': false,
    });
    expect(policy.chargeMode, 'fixed');
    expect(policy.chargeBeforeCutoffPaise, 5000);
    expect(policy.chargeAfterCutoffPaise, 20000);
    expect(policy.hospitalCancellationRefundsConvenienceFee, isFalse);
  });

  test('an older server without the new fields keeps the old meaning', () {
    final policy = BookingMappers.cancellationPolicy(const {'cutoff_hours': 4});
    expect(policy.chargeMode, 'percentage');
    expect(policy.hospitalCancellationRefundsConvenienceFee, isTrue);
  });
}
