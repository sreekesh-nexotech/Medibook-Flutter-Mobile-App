import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_detail.dart';

/// Why the patient cannot cancel an upcoming appointment, as one sentence the
/// detail screen shows next to the disabled Cancel button — or null when they
/// can (or the visit is no longer upcoming, where Cancel is not offered).
///
/// The server decides (`actions.can_cancel` / `cancel_blocked_reason`,
/// §10.2). Its reason code for a desk booking is the generic
/// `APPOINTMENT_NOT_ACTIONABLE`, so the appointment's own `source` says which
/// case it is: a walk-in was sold at the hospital desk and only the desk can
/// cancel it (UB-12) — the same sentence the server gives on a refused
/// `POST …/cancel` (`meta.reason: desk_booking`).
abstract final class CancelBlockedReason {
  CancelBlockedReason._();

  static const String deskBooking =
      'This booking was made at the hospital desk; please ask the hospital '
      'to cancel it.';

  static String? of(Appointment appointment, AppointmentActions actions) {
    if (actions.canCancel || !appointment.status.isUpcoming) return null;
    if (appointment.source == AppointmentSource.walkIn) return deskBooking;
    return switch (actions.cancelBlockedReason) {
      'TOKEN_ALREADY_CALLED' =>
        'Your token has already been called, so only the hospital can '
            'cancel this appointment now.',
      'TOKEN_CANCEL_WINDOW_CLOSED' =>
        'The cancellation window for this token has closed.',
      _ => 'This appointment can no longer be cancelled.',
    };
  }
}
