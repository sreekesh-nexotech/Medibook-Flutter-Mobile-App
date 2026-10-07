import '../../domain/entities/notification.dart';

/// Where tapping a notification takes the user — the §12.1 table, as a
/// sealed value the screen maps onto routes. Pure; testable without a
/// router.
sealed class NotificationTarget {
  const NotificationTarget();
}

class AppointmentDetailTarget extends NotificationTarget {
  const AppointmentDetailTarget(this.appointmentId);

  final String appointmentId;
}

class LiveQueueTarget extends NotificationTarget {
  const LiveQueueTarget(this.appointmentId);

  final String appointmentId;
}

class ReceiptTarget extends NotificationTarget {
  const ReceiptTarget(this.appointmentId);

  final String appointmentId;
}

class FamilyMembersTarget extends NotificationTarget {
  const FamilyMembersTarget({this.personId});

  final String? personId;
}

class AccountTarget extends NotificationTarget {
  const AccountTarget();
}

class DataExportTarget extends NotificationTarget {
  const DataExportTarget({this.dsrId});

  final String? dsrId;
}

class SupportTicketTarget extends NotificationTarget {
  const SupportTicketTarget({this.ticketId});

  final String? ticketId;
}

/// Nothing to open (an unknown event, or a known one whose id is missing).
class NoTarget extends NotificationTarget {
  const NoTarget();
}

/// `data.event` → [NotificationTarget] (§12.1).
abstract final class NotificationTargets {
  NotificationTargets._();

  static NotificationTarget of(PatientNotification notification) {
    final appointmentId = notification.appointmentId;
    return switch (notification.event) {
      'appointment.confirmed' ||
      'appointment.approved' ||
      'appointment.reminder' ||
      'appointment.cancelled' ||
      'appointment.rejected' ||
      'appointment.no_show' ||
      'refund.processed' =>
        appointmentId == null
            ? const NoTarget()
            : AppointmentDetailTarget(appointmentId),
      'token.called' =>
        appointmentId == null
            ? const NoTarget()
            : LiveQueueTarget(appointmentId),
      'payment.captured' =>
        appointmentId == null ? const NoTarget() : ReceiptTarget(appointmentId),
      'patient.auto_linked' => FamilyMembersTarget(
        personId: notification.personId,
      ),
      'account.deletion_requested' ||
      'user.phone_changed' => const AccountTarget(),
      'dsr.export_ready' => DataExportTarget(dsrId: notification.dsrId),
      'support.ticket_updated' => SupportTicketTarget(
        ticketId: notification.ticketId,
      ),
      _ =>
        // An unknown event about an appointment still opens the
        // appointment; anything else has nowhere sensible to go.
        appointmentId == null
            ? const NoTarget()
            : AppointmentDetailTarget(appointmentId),
    };
  }
}
