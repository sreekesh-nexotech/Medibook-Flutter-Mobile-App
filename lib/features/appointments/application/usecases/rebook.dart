import '../../domain/entities/appointment.dart';

/// What booking needs to start again with the same doctor: the department
/// key the booking route takes (its code, else its id) and the doctor id.
class RebookRequest {
  const RebookRequest({
    required this.departmentKey,
    required this.doctorId,
    required this.doctorName,
  });

  /// The booking for [appointment]'s doctor and department — what "Book
  /// again" and "Rebook" both open.
  factory RebookRequest.of(Appointment appointment) => RebookRequest(
    departmentKey: appointment.department.code ?? appointment.department.id,
    doctorId: appointment.doctor.id,
    doctorName: appointment.doctor.name,
  );

  final String departmentKey;
  final String doctorId;
  final String doctorName;
}
