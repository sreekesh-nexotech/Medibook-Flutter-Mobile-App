import '../entities/booking_result.dart';
import '../entities/fee_quote.dart';
import '../entities/person_summary.dart';
import '../entities/token_card.dart';

/// The token-required half of booking (§8.3, §9.1, §10.4, §6.1).
///
/// **Error contract:** every method throws a `Failure`
/// (`core/error/failure.dart`). In particular [book] throws a
/// `ConflictFailure` whose `apiCode` is one of `SLOT_UNAVAILABLE`,
/// `TOKEN_RANGE_EXHAUSTED`, `COUPON_*`, `IDEMPOTENCY_CONFLICT`; a
/// `NotFoundFailure` for an unknown person; a `ServerFailure` with
/// `PROVIDER_UNAVAILABLE` when the gateway is down. Nothing is booked in any
/// of those cases.
abstract interface class BookingRepository {
  /// `GET /patient/fee-quotes` (§8.3). "Apply coupon" is this same call with
  /// [couponCode]; a bad coupon comes back inside the quote, not as an error.
  Future<FeeQuote> feeQuote({
    required String doctorId,
    String? personId,
    String? couponCode,
  });

  /// `GET /patient/me/persons` (§6.1), "self" first. Empty when the account
  /// has no persons yet — the flow must then ask the user to add one.
  Future<List<PersonSummary>> persons();

  /// `POST /patient/appointments` (§9.1). [idempotencyKey] is minted once per
  /// user action and reused on a retry of that same action (§1.8).
  Future<BookingResult> book(
    BookingRequest request, {
    required String idempotencyKey,
  });

  /// `GET /patient/appointments/{id}/token-card` (§10.4).
  Future<TokenCard> tokenCard(String appointmentId);
}
