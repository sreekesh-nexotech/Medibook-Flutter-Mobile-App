import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/appointments/presentation/components/status_pill.dart';

/// Appointments audit (6 Oct 2026): the server's cancellation reason is
/// shown in words, without repeating what the status line already says.
void main() {
  test('codes the status line already explains add nothing', () {
    expect(AppointmentStatusStyle.reasonText('patient_request'), isNull);
    expect(AppointmentStatusStyle.reasonText('payment_timeout'), isNull);
    expect(AppointmentStatusStyle.reasonText(null), isNull);
    expect(AppointmentStatusStyle.reasonText('  '), isNull);
  });

  test('other codes are spelt out', () {
    expect(
      AppointmentStatusStyle.reasonText('doctor_unavailable'),
      'Doctor unavailable',
    );
  });

  test('what the patient typed is shown as typed', () {
    expect(
      AppointmentStatusStyle.reasonText('Feeling better'),
      'Feeling better',
    );
    expect(
      AppointmentStatusStyle.reasonText('Test notification.'),
      'Test notification',
    );
  });
}
