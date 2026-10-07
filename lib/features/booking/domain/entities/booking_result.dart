import 'booked_appointment.dart';
import 'payment_order.dart';

/// What `POST /patient/appointments` returns (§9.1): the pending appointment
/// and the order to pay it with. One 5-minute timer runs from this moment.
class BookingResult {
  const BookingResult({required this.appointment, required this.paymentOrder});

  final BookedAppointment appointment;
  final PaymentOrder paymentOrder;

  BookingResult copyWith({
    BookedAppointment? appointment,
    PaymentOrder? paymentOrder,
  }) => BookingResult(
    appointment: appointment ?? this.appointment,
    paymentOrder: paymentOrder ?? this.paymentOrder,
  );
}

/// The request body of `POST /patient/appointments` (§9.1).
class BookingRequest {
  const BookingRequest({
    required this.slotId,
    required this.personId,
    this.couponCode,
    this.patientNotes,
  });

  final String slotId;
  final String personId;

  /// ≤ 64 characters, only sent when the quote said the coupon is valid.
  final String? couponCode;

  /// ≤ 2000 characters.
  final String? patientNotes;

  @override
  bool operator ==(Object other) =>
      other is BookingRequest &&
      other.slotId == slotId &&
      other.personId == personId &&
      other.couponCode == couponCode &&
      other.patientNotes == patientNotes;

  @override
  int get hashCode => Object.hash(slotId, personId, couponCode, patientNotes);
}
