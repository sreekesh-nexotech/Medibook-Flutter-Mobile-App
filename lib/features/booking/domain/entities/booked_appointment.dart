import '../../../../core/utils/server_clock.dart';

/// Appointment `status` (§17).
enum AppointmentStatus {
  pendingPayment('pending_payment'),
  pendingApproval('pending_approval'),
  scheduled('scheduled'),
  checkedIn('checked_in'),
  inConsultation('in_consultation'),
  completed('completed'),
  cancelled('cancelled'),
  noShow('no_show');

  const AppointmentStatus(this.wire);

  final String wire;

  static AppointmentStatus fromWire(String? value) => values.firstWhere(
    (v) => v.wire == value,
    orElse: () => AppointmentStatus.pendingPayment,
  );
}

/// Appointment `payment_status` (§17).
enum AppointmentPaymentStatus {
  unpaid('unpaid'),
  pending('pending'),
  paid('paid'),
  refunded('refunded'),
  failed('failed');

  const AppointmentPaymentStatus(this.wire);

  final String wire;

  static AppointmentPaymentStatus fromWire(String? value) => values.firstWhere(
    (v) => v.wire == value,
    orElse: () => AppointmentPaymentStatus.pending,
  );
}

/// The parts of the `Appointment` object (§10) the booking and payment flow
/// render. Every identifier the patient sees — [bookingRef], [tokenLabel] —
/// is minted by the backend here; the app never generates one.
class BookedAppointment {
  const BookedAppointment({
    required this.id,
    required this.bookingRef,
    required this.status,
    required this.paymentStatus,
    required this.hospitalId,
    required this.hospitalName,
    required this.departmentName,
    required this.doctorId,
    required this.doctorName,
    required this.personId,
    required this.scheduledDate,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    required this.consultationFeePaise,
    required this.serviceFeePaise,
    required this.discountPaise,
    required this.convenienceFeePaise,
    required this.taxPaise,
    required this.totalPaise,
    required this.currency,
    required this.version,
    this.tokenLabel,
    this.tokenNo,
    this.slotId,
    this.sessionId,
    this.bookingDeadlineAt,
    this.hospitalCity,
    this.hospitalPhoneE164,
    this.hospitalTimezone,
    this.doctorTitle,
    this.doctorSpecialisation,
    this.doctorRoom,
    this.isFollowUp = false,
    this.patientNotes,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    this.createdAt,
  });

  final String id;
  final String bookingRef;
  final AppointmentStatus status;
  final AppointmentPaymentStatus paymentStatus;
  final String hospitalId;
  final String hospitalName;
  final String? hospitalCity;
  final String? hospitalPhoneE164;

  /// The hospital's IANA zone (`hospital.timezone`, §10) — the zone the
  /// scheduled instants are displayed in.
  final String? hospitalTimezone;
  final String departmentName;
  final String doctorId;
  final String doctorName;
  final String? doctorTitle;
  final String? doctorSpecialisation;
  final String? doctorRoom;
  final String personId;
  final String? sessionId;
  final String? slotId;

  /// Hospital-local `YYYY-MM-DD`.
  final String scheduledDate;

  /// UTC instants.
  final DateTime scheduledStartAt;
  final DateTime scheduledEndAt;
  final int? tokenNo;
  final String? tokenLabel;
  final bool isFollowUp;
  final String? patientNotes;

  /// When the unpaid booking is cancelled (UTC). Drives the countdown.
  final DateTime? bookingDeadlineAt;

  // Fee snapshot taken at booking — display as-is.
  final int consultationFeePaise;
  final int serviceFeePaise;
  final int discountPaise;
  final int convenienceFeePaise;
  final int taxPaise;
  final int totalPaise;
  final String currency;
  final DateTime? cancelledAt;

  /// `patient` | `hospital` | `system` | null.
  final String? cancelledBy;
  final String? cancellationReason;
  final DateTime? createdAt;
  final int version;

  bool get isCancelled => status == AppointmentStatus.cancelled;

  bool get isPendingApproval => status == AppointmentStatus.pendingApproval;

  bool get isPaid => paymentStatus == AppointmentPaymentStatus.paid;

  /// True when the 5-minute payment window has passed.
  bool deadlinePassed({DateTime? now}) {
    final deadline = bookingDeadlineAt;
    if (deadline == null) return false;
    // On the server's clock, which set the deadline (BL-CORE-007).
    return !(now ?? ServerClock.now().toUtc()).isBefore(deadline);
  }
}
