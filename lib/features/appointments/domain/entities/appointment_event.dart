/// One row of the appointment's history timeline (§10.3).
class AppointmentEvent {
  const AppointmentEvent({
    required this.id,
    required this.eventType,
    required this.actorKind,
    required this.occurredAt,
    this.fromStatus,
    this.toStatus,
  });

  final String id;

  /// `created | approval_requested | approved | checked_in | called | started
  /// | completed | cancelled | no_show | payment_updated | refund_updated |
  /// note_added | reminder_sent | token_reassigned`.
  final String eventType;

  /// `patient | staff | system`.
  final String actorKind;
  final String? fromStatus;
  final String? toStatus;
  final DateTime occurredAt;
}
