import '../../../../core/error/failure.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/booking_result.dart';
import '../../domain/entities/fee_quote.dart';
import '../../domain/entities/person_summary.dart';
import '../../domain/entities/token_card.dart';
import '../../domain/repositories/booking_repository.dart';
import '../data_sources/remote/booking_api.dart';
import 'booking_mappers.dart';

/// [BookingRepository] over [BookingApi].
///
/// None of these reads are cached: a fee quote must be current, the persons
/// list belongs to the profile feature's cache, and a booking is a mutation.
/// Every throw is a [Failure] via `NetworkExceptions.toFailure`.
class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl({required BookingApi api}) : _api = api;

  final BookingApi _api;

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (error, stack) {
      final failure = NetworkExceptions.toFailure(error, stack);
      AppLogger.warning(
        'Booking call failed: ${failure.code}/${failure.apiCode}',
        name: 'booking',
        error: failure.cause,
      );
      Error.throwWithStackTrace(failure, stack);
    }
  }

  @override
  Future<FeeQuote> feeQuote({
    required String doctorId,
    String? personId,
    String? couponCode,
  }) => _run(() async {
    final trimmed = couponCode?.trim();
    final json = await _api.feeQuote(
      doctorId: doctorId,
      personId: personId,
      couponCode: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
    return BookingMappers.feeQuote(json);
  });

  @override
  Future<List<PersonSummary>> persons() => _run(() async {
    final persons = BookingMappers.persons(await _api.persons());
    // "self" first, as the endpoint promises; kept explicit so a re-sorted
    // page never puts a dependant ahead of the account holder.
    persons.sort((a, b) => (a.isSelf ? 0 : 1) - (b.isSelf ? 0 : 1));
    return persons;
  });

  @override
  Future<BookingResult> book(
    BookingRequest request, {
    required String idempotencyKey,
  }) => _run(() async {
    final json = await _api.book(request, idempotencyKey: idempotencyKey);
    return BookingMappers.bookingResult(json);
  });

  @override
  Future<TokenCard> tokenCard(String appointmentId) => _run(
    () async => BookingMappers.tokenCard(await _api.tokenCard(appointmentId)),
  );
}
