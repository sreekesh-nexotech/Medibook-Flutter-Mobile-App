import '../../utils/date_utils.dart';

/// Lifecycle status of an appointment. Drives the status pill styling
/// (see `core/widgets/status_style.dart`).
enum AppointmentStatus {
  confirmed('Confirmed'),
  completed('Completed'),
  cancelled('Cancelled');

  const AppointmentStatus(this.label);

  /// Human label shown in the pill.
  final String label;
}

/// Which tab an appointment belongs to on the Appointments screen.
enum AppointmentBucket { upcoming, past }

/// A booked appointment. Shown on Home ("Your Token"), the Appointments list,
/// the detail screen and reschedule flow.
///
/// Presentation view-model — immutable value object with a [copyWith] for the
/// controller to produce new state (reschedule / cancel). No business logic.
///
/// ## Dates are dates now (audit §3.8.3)
///
/// The appointment used to store the *word* "Today" and the *string* "10:30 AM",
/// so nothing could sort a list, ask "is this in the next hour?", or group by
/// day. It now stores one real [scheduledAt] instant, and the two display
/// strings are getters:
///
/// ```dart
/// appt.scheduledAt          // DateTime — sortable, comparable
/// appt.date                 // 'Today' / '12 Aug 2026'   (unchanged API)
/// appt.time                 // '10:30 AM'                (unchanged API)
/// ```
///
/// The unnamed constructor still accepts the old `date:`/`time:` strings and
/// parses them, and [copyWith] still accepts them too, so every screen and
/// controller written against the old shape compiles untouched. New code should
/// use [Appointment.at] and `copyWith(scheduledAt: …)`.
class Appointment {
  /// The typed constructor — prefer this in new code.
  const Appointment.at({
    required this.id,
    required this.doctorId,
    required this.patient,
    required this.scheduledAt,
    required this.token,
    required this.status,
    required this.bucket,
    this.bookingRef,
    this.hospitalId,
    this.patientId,
    this.paymentId,
  });

  /// Legacy shape, kept so existing call sites keep compiling.
  ///
  /// [date] accepts "Today" / "Tomorrow" / "12 Aug 2026" and [time] accepts
  /// "10:30 AM"; both are parsed into [scheduledAt] by
  /// [AppDates.fromLabels], which falls back to *now* for a label it cannot
  /// read rather than throwing inside a controller.
  factory Appointment({
    required String id,
    required String doctorId,
    required String patient,
    required String date,
    required String time,
    required String token,
    required AppointmentStatus status,
    required AppointmentBucket bucket,
    String? bookingRef,
    String? hospitalId,
    String? patientId,
    String? paymentId,
  }) {
    return Appointment.at(
      id: id,
      doctorId: doctorId,
      patient: patient,
      scheduledAt: AppDates.fromLabels(day: date, time: time),
      token: token,
      status: status,
      bucket: bucket,
      bookingRef: bookingRef,
      hospitalId: hospitalId,
      patientId: patientId,
      paymentId: paymentId,
    );
  }

  final String id;
  final String doctorId;

  /// Patient display name (kept for the screens that render it directly).
  final String patient;

  /// The dependant this appointment is for, when it is not the account holder
  /// (CM-16). Null means "self".
  final String? patientId;

  /// The real date **and** time of the appointment.
  final DateTime scheduledAt;

  /// Token label ("A-25").
  final String token;

  final AppointmentStatus status;
  final AppointmentBucket bucket;

  /// Human booking reference shown on the confirmation and receipt
  /// ("MB-2026-000124") — CM-14. Null for appointments created before
  /// references existed.
  final String? bookingRef;

  /// Facility id (see [Hospitals]); null → take it from the doctor.
  final String? hospitalId;

  /// The payment that settled this appointment (CM-17), if any.
  final String? paymentId;

  /// Display date ("Today", "12 Aug 2026"). Unchanged public API.
  String get date => AppDates.relativeDay(scheduledAt);

  /// Display time ("10:30 AM"). Unchanged public API.
  String get time => AppDates.timeLabel(scheduledAt);

  /// "Today · 10:30 AM" — the one-line summary.
  String get dateTimeLabel => AppDates.dayAndTime(scheduledAt);

  /// Midnight on the appointment's day — the grouping key for a sectioned list.
  DateTime get day => AppDates.startOfDay(scheduledAt);

  bool get isToday => AppDates.isToday(scheduledAt);

  bool get isPast => AppDates.isPast(scheduledAt);

  /// Whether the appointment can still be rescheduled or cancelled — only a
  /// confirmed, future appointment can.
  bool get isActionable =>
      status == AppointmentStatus.confirmed && !isPast;

  /// Additive typed `copyWith`, plus the legacy string parameters.
  ///
  /// Precedence: [scheduledAt] wins if given; otherwise [date] and/or [time]
  /// are parsed and merged onto the current instant, so
  /// `copyWith(time: '4:30 PM')` moves the clock without moving the day.
  Appointment copyWith({
    DateTime? scheduledAt,
    String? date,
    String? time,
    AppointmentStatus? status,
    AppointmentBucket? bucket,
    String? token,
    String? bookingRef,
    String? hospitalId,
    String? patientId,
    String? paymentId,
  }) {
    final resolvedAt = scheduledAt ??
        (date == null && time == null
            ? this.scheduledAt
            : AppDates.fromLabels(
                day: date,
                time: time,
                fallback: this.scheduledAt,
              ));

    return Appointment.at(
      id: id,
      doctorId: doctorId,
      patient: patient,
      scheduledAt: resolvedAt,
      token: token ?? this.token,
      status: status ?? this.status,
      bucket: bucket ?? this.bucket,
      bookingRef: bookingRef ?? this.bookingRef,
      hospitalId: hospitalId ?? this.hospitalId,
      patientId: patientId ?? this.patientId,
      paymentId: paymentId ?? this.paymentId,
    );
  }
}
