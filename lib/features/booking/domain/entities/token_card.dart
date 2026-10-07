/// `GET /patient/appointments/{id}/token-card` (§10.4): everything the token /
/// success screen shows, already in hospital-local time.
class TokenCard {
  const TokenCard({
    required this.bookingRef,
    required this.status,
    required this.patientName,
    required this.hospitalName,
    required this.doctorName,
    required this.departmentName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.startsAt,
    required this.endsAt,
    required this.qrPayload,
    this.tokenLabel,
    this.tokenNo,
    this.hospitalAddressLine1,
    this.hospitalCity,
    this.hospitalPhoneE164,
    this.doctorTitle,
    this.doctorRoom,
    this.sessionLabel,
  });

  final String bookingRef;
  final String? tokenLabel;
  final int? tokenNo;

  /// Encode this string as the QR.
  final String qrPayload;
  final String status;
  final String patientName;
  final String hospitalName;
  final String? hospitalAddressLine1;
  final String? hospitalCity;
  final String? hospitalPhoneE164;
  final String doctorName;
  final String? doctorTitle;
  final String? doctorRoom;
  final String departmentName;

  /// Hospital-local `YYYY-MM-DD`.
  final String date;

  /// Hospital-local `HH:MM`.
  final String startTime;
  final String endTime;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? sessionLabel;

  /// "09:00 – 09:15".
  String get timeRangeLabel => '$startTime – $endTime';
}
