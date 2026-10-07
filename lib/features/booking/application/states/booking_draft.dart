import '../../domain/entities/doctor.dart';
import '../../domain/entities/person_summary.dart';
import '../../domain/entities/slots.dart';

/// Where a booking flow was entered from — the back button at step 1 returns
/// here.
enum BookingOrigin { home, appointments }

/// The in-flight booking draft: the step and every pick the four steps make.
/// Immutable; updated only through [copyWith].
///
/// What the draft holds is exactly what `POST /patient/appointments` needs —
/// a `slot_id`, a `person_id`, an optional coupon and notes — plus the
/// display facts (doctor, hospital, department, session label) so the
/// summary can render without another fetch. Nothing here is minted locally:
/// the booking reference, the token and the fee snapshot come back from the
/// backend at booking time (§9.1).
class BookingDraft {
  const BookingDraft({
    this.step = 1,
    this.hospitalId,
    this.hospitalName,
    this.hospitalTimezone,
    this.departmentCode,
    this.departmentName,
    this.doctor,
    this.date,
    this.slot,
    this.sessionLabel,
    this.person,
    this.couponCode,
    this.patientNotes,
    this.origin = BookingOrigin.home,
  });

  /// 1 = department, 2 = doctor (and hospital), 3 = patient / time, 4 =
  /// summary.
  final int step;

  /// The facility the funnel is scoped to. Null until a hospital is picked —
  /// doctors are always listed per hospital (§7.7), so step 2 picks one when
  /// the flow was entered department-first.
  final String? hospitalId;
  final String? hospitalName;

  /// The hospital's zone, for slot labels. Null → `Asia/Kolkata`.
  final String? hospitalTimezone;

  final String? departmentCode;
  final String? departmentName;

  /// The chosen doctor, carried whole so the summary needs no refetch.
  final DoctorCard? doctor;

  /// The chosen hospital-local day, `YYYY-MM-DD`.
  final String? date;

  /// The chosen slot; only an available slot can land here.
  final Slot? slot;

  /// The session the slot belongs to ("Morning OPD").
  final String? sessionLabel;

  /// Who the appointment is for. Null until picked; never invented.
  final PersonSummary? person;

  /// The coupon the patient typed. Whether it is *valid* is the fee quote's
  /// verdict — the booking only sends it when the quote accepted it.
  final String? couponCode;

  final String? patientNotes;
  final BookingOrigin origin;

  String? get doctorId => doctor?.id;
  String? get slotId => slot?.id;
  String? get personId => person?.id;

  bool get isFirstStep => step == 1;

  /// Continue is enabled once the current step's required pick exists.
  bool get canContinue => switch (step) {
    1 => departmentCode != null,
    2 => doctor != null,
    3 => slot != null && person != null,
    _ => isBookable,
  };

  /// Everything `POST /patient/appointments` needs is present.
  bool get isBookable => slot != null && person != null && doctor != null;

  BookingDraft copyWith({
    int? step,
    String? Function()? hospitalId,
    String? Function()? hospitalName,
    String? Function()? hospitalTimezone,
    String? Function()? departmentCode,
    String? Function()? departmentName,
    DoctorCard? Function()? doctor,
    String? Function()? date,
    Slot? Function()? slot,
    String? Function()? sessionLabel,
    PersonSummary? Function()? person,
    String? Function()? couponCode,
    String? Function()? patientNotes,
    BookingOrigin? origin,
  }) => BookingDraft(
    step: step ?? this.step,
    hospitalId: hospitalId != null ? hospitalId() : this.hospitalId,
    hospitalName: hospitalName != null ? hospitalName() : this.hospitalName,
    hospitalTimezone: hospitalTimezone != null
        ? hospitalTimezone()
        : this.hospitalTimezone,
    departmentCode: departmentCode != null
        ? departmentCode()
        : this.departmentCode,
    departmentName: departmentName != null
        ? departmentName()
        : this.departmentName,
    doctor: doctor != null ? doctor() : this.doctor,
    date: date != null ? date() : this.date,
    slot: slot != null ? slot() : this.slot,
    sessionLabel: sessionLabel != null ? sessionLabel() : this.sessionLabel,
    person: person != null ? person() : this.person,
    couponCode: couponCode != null ? couponCode() : this.couponCode,
    patientNotes: patientNotes != null ? patientNotes() : this.patientNotes,
    origin: origin ?? this.origin,
  );
}
