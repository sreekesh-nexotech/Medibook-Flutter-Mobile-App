/// Slot `state` (§17). Only [available] can be booked.
enum SlotState {
  available('available'),
  held('held'),
  booked('booked'),
  blocked('blocked'),
  past('past');

  const SlotState(this.wire);

  final String wire;

  static SlotState fromWire(String? value) => values.firstWhere(
    (v) => v.wire == value,
    orElse: () => SlotState.blocked,
  );

  bool get isSelectable => this == SlotState.available;
}

/// Session `status` (§17).
enum SessionStatus {
  scheduled('scheduled'),
  open('open'),
  paused('paused'),
  closed('closed'),
  cancelled('cancelled');

  const SessionStatus(this.wire);

  final String wire;

  static SessionStatus fromWire(String? value) => values.firstWhere(
    (v) => v.wire == value,
    orElse: () => SessionStatus.scheduled,
  );
}

/// One consultation slot (§8.2). The [id] is the `slot_id` a booking sends.
class Slot {
  const Slot({
    required this.id,
    required this.sessionId,
    required this.startsAt,
    required this.endsAt,
    required this.state,
  });

  final String id;
  final String sessionId;

  /// UTC instants — display in the hospital's zone.
  final DateTime startsAt;
  final DateTime endsAt;
  final SlotState state;

  bool get isSelectable => state.isSelectable;

  @override
  bool operator ==(Object other) => other is Slot && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A session — the queue unit — with its slots. Slots are grouped by session,
/// not by fixed morning / afternoon buckets; render [label].
class SlotSession {
  const SlotSession({
    required this.sessionId,
    required this.sessionCode,
    required this.label,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.slots,
  });

  final String sessionId;
  final String sessionCode;
  final String label;
  final SessionStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<Slot> slots;

  List<Slot> get available => [
    for (final slot in slots)
      if (slot.isSelectable) slot,
  ];

  bool get hasAvailability => slots.any((s) => s.isSelectable);
}

/// `GET /patient/doctors/{id}/slots?date=` (§8.2).
class DaySlots {
  const DaySlots({
    required this.doctorId,
    required this.date,
    required this.sessions,
    this.timezone,
  });

  final String doctorId;

  /// Hospital-local `YYYY-MM-DD`.
  final String date;

  /// The hospital's IANA zone — every `starts_at` / `ends_at` in the grid is
  /// UTC and is rendered in this (§1.11). Null from a server that predates
  /// the field; callers then fall back to the hospital detail's zone.
  final String? timezone;
  final List<SlotSession> sessions;

  /// Every slot across every session, in session order.
  List<Slot> get allSlots => [for (final s in sessions) ...s.slots];

  List<Slot> get available => [
    for (final slot in allSlots)
      if (slot.isSelectable) slot,
  ];

  bool get isUnavailable => allSlots.isEmpty;

  bool get hasAvailability => available.isNotEmpty;

  bool get isFullyBooked => allSlots.isNotEmpty && available.isEmpty;

  /// The session a slot belongs to, or null.
  SlotSession? sessionOf(Slot slot) {
    for (final session in sessions) {
      if (session.sessionId == slot.sessionId) return session;
    }
    return null;
  }
}
