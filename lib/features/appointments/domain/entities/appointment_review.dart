/// `POST /patient/appointments/{id}/review` → 201 (§10.12).
class AppointmentReview {
  const AppointmentReview({
    required this.id,
    required this.appointmentId,
    required this.doctorId,
    required this.rating,
    required this.moderationStatus,
    this.comment,
    this.isPublished = false,
    this.createdAt,
  });

  final String id;
  final String appointmentId;
  final String doctorId;
  final int rating;
  final String? comment;

  /// `pending | approved | rejected`.
  final String moderationStatus;
  final bool isPublished;
  final DateTime? createdAt;
}
