/// Availability session `state` (§17).
enum SessionAvailability {
  available('available'),
  full('full'),
  closed('closed');

  const SessionAvailability(this.wire);

  final String wire;

  static SessionAvailability fromWire(String? value) => values.firstWhere(
    (v) => v.wire == value,
    orElse: () => SessionAvailability.closed,
  );
}

/// One session on one day of `GET /patient/doctors/{id}/availability` (§8.1).
class AvailabilitySession {
  const AvailabilitySession({
    required this.sessionId,
    required this.sessionCode,
    required this.label,
    required this.state,
    required this.startsAt,
    required this.endsAt,
  });

  final String sessionId;
  final String sessionCode;
  final String label;
  final SessionAvailability state;

  /// UTC instants — display in the hospital's zone.
  final DateTime startsAt;
  final DateTime endsAt;

  bool get isAvailable => state == SessionAvailability.available;
}

/// One day of the availability range. An empty [sessions] list means the
/// doctor does not sit that day.
class AvailabilityDay {
  const AvailabilityDay({required this.date, required this.sessions});

  /// Hospital-local `YYYY-MM-DD` — the value `GET …/slots?date=` takes.
  final String date;
  final List<AvailabilitySession> sessions;

  /// Nothing can be booked and nothing is full: no session, or every one
  /// `closed` (it has ended, or is not taken online). Such a day used to
  /// read "fully booked".
  bool get isUnavailable =>
      sessions.every((s) => s.state == SessionAvailability.closed);

  bool get hasAvailability => sessions.any((s) => s.isAvailable);

  /// The server says `full`: no open session, at least one fully booked.
  bool get isFull =>
      !hasAvailability &&
      sessions.any((s) => s.state == SessionAvailability.full);
}

/// `GET /patient/doctors/{id}/availability` (§8.1).
class DoctorAvailability {
  const DoctorAvailability({
    required this.doctorId,
    required this.from,
    required this.to,
    required this.dates,
  });

  final String doctorId;
  final String from;
  final String to;
  final List<AvailabilityDay> dates;

  /// The first day with an open session, or null.
  AvailabilityDay? get firstAvailable {
    for (final day in dates) {
      if (day.hasAvailability) return day;
    }
    return null;
  }

  AvailabilityDay? forDate(String date) {
    for (final day in dates) {
      if (day.date == date) return day;
    }
    return null;
  }
}
