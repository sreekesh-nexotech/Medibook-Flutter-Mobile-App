/// A postal address block as the token card and the receipt carry it.
class AddressSnapshot {
  const AddressSnapshot({
    this.line1,
    this.line2,
    this.line3,
    this.city,
    this.state,
    this.pincode,
    this.phoneE164,
  });

  final String? line1;
  final String? line2;
  final String? line3;
  final String? city;
  final String? state;
  final String? pincode;
  final String? phoneE164;

  /// "NH 66, Kochi, Kerala 682024" — the non-empty parts joined.
  String get oneLine => [
    line1,
    line2,
    line3,
    city,
    [state, pincode].where((p) => p != null && p.isNotEmpty).join(' '),
  ].where((p) => p != null && p.isNotEmpty).join(', ');
}

/// The doctor's session (queue unit) on a token card (§10.4).
class SessionSummary {
  const SessionSummary({
    required this.sessionCode,
    required this.label,
    this.startsAt,
    this.endsAt,
  });

  final String sessionCode;
  final String label;
  final DateTime? startsAt;
  final DateTime? endsAt;
}

/// Everything the token / success screen shows (§10.4), already in
/// hospital-local time.
class TokenCard {
  const TokenCard({
    required this.bookingRef,
    required this.qrPayload,
    required this.status,
    required this.patientName,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.doctorName,
    required this.departmentName,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.tokenLabel,
    this.tokenNo,
    this.doctorTitle,
    this.doctorRoom,
    this.startsAt,
    this.endsAt,
    this.session,
  });

  final String bookingRef;
  final String? tokenLabel;
  final int? tokenNo;

  /// Encode this string as the QR.
  final String qrPayload;
  final String status;
  final String patientName;
  final String hospitalName;
  final AddressSnapshot hospitalAddress;
  final String doctorName;
  final String? doctorTitle;
  final String? doctorRoom;
  final String departmentName;

  /// Hospital-local `YYYY-MM-DD` and `HH:MM`.
  final String date;
  final String startTime;
  final String endTime;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final SessionSummary? session;
}
