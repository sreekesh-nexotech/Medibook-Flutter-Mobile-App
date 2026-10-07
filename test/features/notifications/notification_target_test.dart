import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/notifications/application/usecases/notification_target.dart';
import 'package:medibook/features/notifications/domain/entities/notification.dart';

import 'support/fixtures.dart';

/// `data.event` → screen, per the §12.1 table.
void main() {
  PatientNotification of(String event, {Map<String, Object?>? data}) =>
      NotificationFixtures.notification(event: event);

  test('appointment events open the appointment detail', () {
    for (final event in [
      'appointment.confirmed',
      'appointment.approved',
      'appointment.reminder',
      'appointment.cancelled',
      'appointment.rejected',
      'appointment.no_show',
      'refund.processed',
    ]) {
      final target = NotificationTargets.of(of(event));
      expect(target, isA<AppointmentDetailTarget>(), reason: event);
      expect(
        (target as AppointmentDetailTarget).appointmentId,
        NotificationFixtures.appointmentId,
      );
    }
  });

  test('token.called opens the live queue for that appointment', () {
    final target = NotificationTargets.of(of('token.called'));
    expect(target, isA<LiveQueueTarget>());
    expect(
      (target as LiveQueueTarget).appointmentId,
      NotificationFixtures.appointmentId,
    );
  });

  test('payment.captured opens the receipt', () {
    expect(
      NotificationTargets.of(of('payment.captured')),
      isA<ReceiptTarget>(),
    );
  });

  test('account, family, export and support events', () {
    expect(
      NotificationTargets.of(of('account.deletion_requested')),
      isA<AccountTarget>(),
    );
    expect(
      NotificationTargets.of(of('user.phone_changed')),
      isA<AccountTarget>(),
    );
    expect(
      NotificationTargets.of(of('patient.auto_linked')),
      isA<FamilyMembersTarget>(),
    );
    expect(
      NotificationTargets.of(of('dsr.export_ready')),
      isA<DataExportTarget>(),
    );
    expect(
      NotificationTargets.of(of('support.ticket_updated')),
      isA<SupportTicketTarget>(),
    );
  });

  test('an unknown event with no appointment goes nowhere', () {
    final n = PatientNotification(
      id: 'x',
      kind: NotificationKind.general,
      title: 't',
      body: 'b',
      event: 'something.new',
      createdAt: DateTime.now().toUtc(),
    );
    expect(NotificationTargets.of(n), isA<NoTarget>());
  });
}
