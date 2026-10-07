/// What kind of event a notification reports (`FLUTTER_API_INTEGRATION.md`
/// §17) — exactly the six backend kinds. Drives the leading icon and the
/// filter chips.
enum NotificationKind {
  confirmation('confirmation', 'Confirmation'),
  reminder('reminder', 'Reminder'),
  cancellation('cancellation', 'Cancellation'),
  payment('payment', 'Payment'),
  queue('queue', 'Queue'),
  general('general', 'General');

  const NotificationKind(this.wire, this.label);

  /// The API value.
  final String wire;

  /// Human label for the chip and badge.
  final String label;

  static NotificationKind fromWire(String? value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    return general;
  }
}

/// One notification (§12.1). Immutable; "mark as read" produces a new record
/// through [copyWith] once the server has confirmed it.
class PatientNotification {
  const PatientNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.event,
    required this.createdAt,
    this.readAt,
    this.hospitalId,
    this.appointmentId,
    this.refundId,
    this.ticketId,
    this.personId,
    this.dsrId,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;

  /// `data.event` — always present; what happened (`appointment.confirmed`,
  /// `token.called`, …). Opaque text; routing is resolved by
  /// `NotificationTargets.of`.
  final String event;

  /// Null = unread.
  final DateTime? readAt;
  final String? hospitalId;
  final DateTime createdAt;

  // `data.*` ids, present when relevant (§12.1).
  final String? appointmentId;
  final String? refundId;
  final String? ticketId;
  final String? personId;
  final String? dsrId;

  bool get unread => readAt == null;
  bool get read => readAt != null;

  PatientNotification copyWith({DateTime? readAt, bool clearReadAt = false}) {
    return PatientNotification(
      id: id,
      kind: kind,
      title: title,
      body: body,
      event: event,
      createdAt: createdAt,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      hospitalId: hospitalId,
      appointmentId: appointmentId,
      refundId: refundId,
      ticketId: ticketId,
      personId: personId,
      dsrId: dsrId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PatientNotification && other.id == id && other.readAt == readAt;

  @override
  int get hashCode => Object.hash(id, readAt);
}

/// The list request (§12.1): `unread` and `kind` filters. Value-equal so it
/// can key a provider family.
class NotificationListQuery {
  const NotificationListQuery({this.unread, this.kinds = const {}});

  /// `unread=true` for unread only, `false` for read only, null for all.
  final bool? unread;

  /// `kind=a,b` (multi); empty for every kind.
  final Set<NotificationKind> kinds;

  bool get isFiltered => unread != null || kinds.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is NotificationListQuery &&
      other.unread == unread &&
      other.kinds.length == kinds.length &&
      other.kinds.containsAll(kinds);

  @override
  int get hashCode => Object.hash(unread, Object.hashAllUnordered(kinds));
}
