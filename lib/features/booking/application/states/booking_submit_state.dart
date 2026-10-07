import '../../../../core/error/failure.dart';
import '../../domain/entities/booking_result.dart';

/// The state of the `POST /patient/appointments` call (§9.1).
///
/// [idempotencyKey] is minted once per attempt and reused on a retry of the
/// same request (§1.8); a *different* request (another slot, another person)
/// gets a fresh key. [slotUnavailable] is set on `409 SLOT_UNAVAILABLE` so
/// the flow reloads the slots rather than retrying blindly.
class BookingSubmitState {
  const BookingSubmitState({
    this.isSubmitting = false,
    this.result,
    this.failure,
    this.idempotencyKey,
    this.request,
    this.quotedTotalPaise,
    this.slotUnavailable = false,
  });

  final bool isSubmitting;

  /// The created appointment and its payment order, once booked.
  final BookingResult? result;

  /// Why the last attempt failed, or null.
  final Failure? failure;

  /// The key the current attempt is using.
  final String? idempotencyKey;

  /// The request the key belongs to.
  final BookingRequest? request;

  /// The total the confirm step was showing when the patient tapped Pay, or
  /// null when no quote had loaded. The payment screen compares it with what
  /// the booking actually costs.
  final int? quotedTotalPaise;

  /// True when the slot was taken between showing it and booking it.
  final bool slotUnavailable;

  bool get isBooked => result != null;

  BookingSubmitState copyWith({
    bool? isSubmitting,
    BookingResult? Function()? result,
    Failure? Function()? failure,
    String? Function()? idempotencyKey,
    BookingRequest? Function()? request,
    int? Function()? quotedTotalPaise,
    bool? slotUnavailable,
  }) => BookingSubmitState(
    isSubmitting: isSubmitting ?? this.isSubmitting,
    result: result != null ? result() : this.result,
    failure: failure != null ? failure() : this.failure,
    idempotencyKey: idempotencyKey != null
        ? idempotencyKey()
        : this.idempotencyKey,
    request: request != null ? request() : this.request,
    quotedTotalPaise: quotedTotalPaise != null
        ? quotedTotalPaise()
        : this.quotedTotalPaise,
    slotUnavailable: slotUnavailable ?? this.slotUnavailable,
  );
}
