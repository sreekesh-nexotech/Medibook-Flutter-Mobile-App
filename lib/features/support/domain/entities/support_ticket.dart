/// Support tickets (`FLUTTER_API_INTEGRATION.md` §13).
///
/// Plain immutable entities. Enum values carry their wire spelling; the
/// display labels live here too so the two cannot drift apart.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.ticketNo,
    required this.category,
    required this.subject,
    required this.description,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.closedAt,
    this.version = 1,
    this.messages = const <TicketMessage>[],
  });

  /// API handle — never shown. Show [ticketNo].
  final String id;

  /// `TKT-2026-000045` — the number the user quotes.
  final String ticketNo;

  final TicketCategory category;
  final String subject;
  final String description;
  final TicketPriority priority;
  final TicketStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final int version;

  /// Present on the detail call only; empty on the list.
  final List<TicketMessage> messages;

  /// A reply on a `closed` ticket is `409 STATE_CONFLICT`.
  bool get canReply => status != TicketStatus.closed;

  SupportTicket copyWith({
    TicketStatus? status,
    DateTime? updatedAt,
    List<TicketMessage>? messages,
    int? version,
  }) => SupportTicket(
    id: id,
    ticketNo: ticketNo,
    category: category,
    subject: subject,
    description: description,
    priority: priority,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    resolvedAt: resolvedAt,
    closedAt: closedAt,
    version: version ?? this.version,
    messages: messages ?? this.messages,
  );

  @override
  bool operator ==(Object other) =>
      other is SupportTicket &&
      other.id == id &&
      other.status == status &&
      other.updatedAt == updatedAt &&
      other.version == version &&
      other.messages.length == messages.length;

  @override
  int get hashCode =>
      Object.hash(id, status, updatedAt, version, messages.length);

  @override
  String toString() => 'SupportTicket($ticketNo)';
}

/// One message on a ticket thread.
class TicketMessage {
  const TicketMessage({
    required this.id,
    required this.authorKind,
    required this.authorName,
    required this.body,
    required this.occurredAt,
    this.attachmentFileIds = const <String>[],
  });

  final String id;

  /// `requester` (the patient) or `platform_staff`.
  final String authorKind;
  final String authorName;
  final String body;
  final DateTime occurredAt;
  final List<String> attachmentFileIds;

  bool get isMine => authorKind == 'requester';

  @override
  bool operator ==(Object other) => other is TicketMessage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Ticket `category` (§17).
enum TicketCategory {
  billing('billing', 'Billing or payment'),
  technical('technical', 'App or technical problem'),
  onboarding('onboarding', 'Sign-up and account'),
  featureRequest('feature_request', 'Suggest a feature'),
  complaint('complaint', 'Complaint'),
  other('other', 'Something else');

  const TicketCategory(this.wire, this.label);

  final String wire;
  final String label;

  static TicketCategory fromWire(String? value) => values.firstWhere(
    (c) => c.wire == value,
    orElse: () => TicketCategory.other,
  );
}

/// Ticket `priority` (§17). Optional on create; `normal` when omitted.
enum TicketPriority {
  low('low', 'Low'),
  normal('normal', 'Normal'),
  high('high', 'High'),
  urgent('urgent', 'Urgent');

  const TicketPriority(this.wire, this.label);

  final String wire;
  final String label;

  static TicketPriority fromWire(String? value) => values.firstWhere(
    (p) => p.wire == value,
    orElse: () => TicketPriority.normal,
  );
}

/// Ticket `status` (§17).
enum TicketStatus {
  open('open', 'Open'),
  inProgress('in_progress', 'In progress'),
  waitingOnRequester('waiting_on_requester', 'Waiting on you'),
  resolved('resolved', 'Resolved'),
  closed('closed', 'Closed');

  const TicketStatus(this.wire, this.label);

  final String wire;
  final String label;

  bool get isOpen =>
      this != TicketStatus.resolved && this != TicketStatus.closed;

  static TicketStatus fromWire(String? value) => values.firstWhere(
    (s) => s.wire == value,
    orElse: () => TicketStatus.open,
  );
}

/// What `POST /patient/support/tickets` takes.
class NewTicket {
  const NewTicket({
    required this.category,
    required this.subject,
    required this.description,
    this.priority,
    this.attachmentFileIds = const <String>[],
  });

  final TicketCategory category;
  final String subject;
  final String description;
  final TicketPriority? priority;

  /// ≤ 5 clean files with purpose `ticket_attachment`, uploaded by the
  /// request form's Attach control before it submits.
  final List<String> attachmentFileIds;
}
