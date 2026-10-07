import '../../../../core/utils/money.dart';

/// The eight backend appointment statuses (`FLUTTER_API_INTEGRATION.md` §17).
///
/// Spelled exactly as the wire value; the presentation layer folds them onto
/// the design's pills (`status_pill.dart`). Nothing in the app *infers* a
/// status any more — the hospital owns every transition.
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

  /// The API value.
  final String wire;

  /// True for the statuses the backend puts in `bucket=upcoming`.
  bool get isUpcoming => switch (this) {
    pendingPayment ||
    pendingApproval ||
    scheduled ||
    checkedIn ||
    inConsultation => true,
    completed || cancelled || noShow => false,
  };

  /// True once the patient is physically in the day's queue — the states in
  /// which the live-queue screen is worth opening.
  bool get isInQueue => this == checkedIn || this == inConsultation;

  /// True for a booking that is still ahead and is past the payment step —
  /// paid, or awaiting the hospital's confirmation. An unpaid hold is not a
  /// place in any queue, and a finished or cancelled visit is over.
  bool get isBookedAhead => switch (this) {
    pendingApproval || scheduled || checkedIn || inConsultation => true,
    pendingPayment || completed || cancelled || noShow => false,
  };

  /// The states in which the token card is worth showing at the desk.
  bool get hasTokenCard => isBookedAhead;

  /// The states in which the appointment offers its live queue. Hidden for an
  /// unpaid booking (owner decision, BL-APPT-032).
  bool get offersLiveQueue => isBookedAhead;

  static AppointmentStatus? fromWire(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}

/// `payment_status` on an appointment (§17).
enum AppointmentPaymentStatus {
  unpaid('unpaid'),
  pending('pending'),
  paid('paid'),
  refunded('refunded'),
  failed('failed');

  const AppointmentPaymentStatus(this.wire);

  final String wire;

  static AppointmentPaymentStatus? fromWire(String? value) {
    for (final status in values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}

/// Where the booking came from (§17).
enum AppointmentSource {
  online('online'),
  walkIn('walk_in');

  const AppointmentSource(this.wire);

  final String wire;

  static AppointmentSource fromWire(String? value) =>
      value == walkIn.wire ? walkIn : online;
}

/// Who cancelled (§17). Null on the entity when nobody has.
enum CancelledBy {
  patient('patient'),
  hospital('hospital'),
  system('system');

  const CancelledBy(this.wire);

  final String wire;

  static CancelledBy? fromWire(String? value) {
    for (final who in values) {
      if (who.wire == value) return who;
    }
    return null;
  }
}

/// The hospital summary embedded in an appointment (§10).
class HospitalSummary {
  const HospitalSummary({
    required this.id,
    required this.name,
    this.city,
    this.phoneE164,
    this.timezone,
  });

  final String id;
  final String name;
  final String? city;
  final String? phoneE164;

  /// IANA zone every instant on the appointment is displayed in (§1.11).
  /// Null on a payload from a server that predates the field.
  final String? timezone;
}

/// The department summary embedded in an appointment (§10).
class DepartmentSummary {
  const DepartmentSummary({required this.id, required this.name, this.code});

  final String id;
  final String name;
  final String? code;
}

/// The doctor summary embedded in an appointment (§10). No photo — the
/// embedded object carries none; the doctor detail endpoint does.
class DoctorSummary {
  const DoctorSummary({
    required this.id,
    required this.name,
    this.title,
    this.specialisation,
    this.room,
  });

  final String id;
  final String name;
  final String? title;
  final String? specialisation;
  final String? room;
}

/// One `tax_lines[]` entry — the same object as on a fee quote (§8.3).
class TaxLine {
  const TaxLine({
    required this.code,
    required this.line,
    required this.supplier,
    required this.rateBp,
    required this.tax,
    required this.base,
    this.inclusive = false,
  });

  final String code;
  final String line;
  final String supplier;

  /// Basis points: `1800` = 18 %.
  final int rateBp;
  final Money tax;
  final Money base;
  final bool inclusive;
}

/// A booked appointment — the backend's `Appointment` object (§10).
///
/// A domain entity: immutable, no JSON, no Flutter. Every money field is
/// [Money] in paise exactly as the fee snapshot was taken at booking (§8.3:
/// never recompute fees in the app). Instants are UTC; display in the
/// hospital's zone.
class Appointment {
  const Appointment({
    required this.id,
    required this.bookingRef,
    required this.status,
    required this.hospital,
    required this.department,
    required this.doctor,
    required this.personId,
    required this.scheduledDate,
    required this.scheduledStartAt,
    required this.scheduledEndAt,
    required this.paymentStatus,
    required this.consultationFee,
    required this.serviceFee,
    required this.discount,
    required this.convenienceFee,
    required this.tax,
    required this.total,
    required this.createdAt,
    required this.version,
    this.statusReason,
    this.source = AppointmentSource.online,
    this.sessionId,
    this.slotId,
    this.tokenNo,
    this.tokenLabel,
    this.tokenSource,
    this.isFollowUp = false,
    this.patientNotes,
    this.bookingDeadlineAt,
    this.taxLines = const <TaxLine>[],
    this.currency = 'INR',
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    this.checkedInAt,
    this.calledAt,
    this.completedAt,
  });

  final String id;

  /// Show this, never [id] (§1.11).
  final String bookingRef;

  final AppointmentStatus status;
  final String? statusReason;
  final AppointmentSource source;

  final HospitalSummary hospital;
  final DepartmentSummary department;
  final DoctorSummary doctor;

  /// Which family member — join with the persons list for the name.
  final String personId;

  final String? sessionId;
  final String? slotId;

  /// Hospital-local `YYYY-MM-DD`.
  final String scheduledDate;

  /// UTC instants.
  final DateTime scheduledStartAt;
  final DateTime scheduledEndAt;

  final int? tokenNo;

  /// Show this; opaque text (`T-026`, `A002`).
  final String? tokenLabel;
  final String? tokenSource;
  final bool isFollowUp;
  final String? patientNotes;

  final AppointmentPaymentStatus paymentStatus;

  /// Pay-by instant for a `pending_payment` booking, or null.
  final DateTime? bookingDeadlineAt;

  // ---- Fee snapshot (paise) ----
  final Money consultationFee;
  final Money serviceFee;
  final Money discount;
  final Money convenienceFee;
  final Money tax;
  final List<TaxLine> taxLines;
  final Money total;
  final String currency;

  final DateTime? cancelledAt;
  final CancelledBy? cancelledBy;
  final String? cancellationReason;
  final DateTime? checkedInAt;
  final DateTime? calledAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  /// Row version for `If-Match` (§1.9).
  final int version;

  bool get hasToken => tokenLabel != null && tokenLabel!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is Appointment && other.id == id && other.version == version;

  @override
  int get hashCode => Object.hash(id, version);

  @override
  String toString() => 'Appointment($bookingRef, ${status.wire})';
}
