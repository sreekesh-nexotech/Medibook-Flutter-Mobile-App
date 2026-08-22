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
class Appointment {
  const Appointment({
    required this.id,
    required this.doctorId,
    required this.patient,
    required this.date,
    required this.time,
    required this.token,
    required this.status,
    required this.bucket,
  });

  final String id;
  final String doctorId;
  final String patient;

  /// Display date ("Today", "12 Aug 2026").
  final String date;

  /// Display time ("10:30 AM").
  final String time;

  /// Token label ("A-25").
  final String token;

  final AppointmentStatus status;
  final AppointmentBucket bucket;

  Appointment copyWith({
    String? date,
    String? time,
    AppointmentStatus? status,
    AppointmentBucket? bucket,
  }) {
    return Appointment(
      id: id,
      doctorId: doctorId,
      patient: patient,
      date: date ?? this.date,
      time: time ?? this.time,
      token: token,
      status: status ?? this.status,
      bucket: bucket ?? this.bucket,
    );
  }
}
