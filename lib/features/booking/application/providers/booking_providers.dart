import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../appointments/application/providers/appointments_provider.dart';
import '../../domain/entities/booked_appointment.dart';
import '../../domain/entities/booking_result.dart';
import '../../domain/entities/fee_quote.dart';
import '../../domain/entities/person_summary.dart';
import '../../domain/entities/token_card.dart';
import '../../domain/repositories/availability_repository.dart';
import '../../domain/repositories/booking_repository.dart';
import '../states/booking_submit_state.dart';
import 'discovery_providers.dart';

/// The booking repository. Callers depend on the abstract type, so a test can
/// `overrideWithValue(FakeBookingRepository())`.
final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) =>
      throw UnimplementedError('bookingRepositoryProvider is wired in app/di'),
);

/// Key for [feeQuoteProvider]. `personId` matters: the follow-up fee is
/// applied per family member (§8.3).
class FeeQuoteQuery {
  const FeeQuoteQuery({required this.doctorId, this.personId, this.couponCode});

  final String doctorId;
  final String? personId;
  final String? couponCode;

  @override
  bool operator ==(Object other) =>
      other is FeeQuoteQuery &&
      other.doctorId == doctorId &&
      other.personId == personId &&
      other.couponCode == couponCode;

  @override
  int get hashCode => Object.hash(doctorId, personId, couponCode);
}

/// `GET /patient/fee-quotes`. "Apply coupon" is a new key with `couponCode`.
/// autoDispose family — scoped to one booking.
final feeQuoteProvider = FutureProvider.autoDispose
    .family<FeeQuote, FeeQuoteQuery>((ref, query) {
      final repository = ref.watch(bookingRepositoryProvider);
      return guardedRead(
        'fee quote',
        () => repository.feeQuote(
          doctorId: query.doctorId,
          personId: query.personId,
          couponCode: query.couponCode,
        ),
      );
    });

/// The account's persons for the "Appointment for" picker (§6.1). Empty on
/// the test account — the screen must then ask for a family member.
final bookingPersonsProvider = FutureProvider.autoDispose<List<PersonSummary>>((
  ref,
) {
  final repository = ref.watch(bookingRepositoryProvider);
  return guardedRead('booking persons', repository.persons);
});

/// `GET /patient/appointments/{id}/token-card` for the success screen.
final tokenCardProvider = FutureProvider.autoDispose.family<TokenCard, String>((
  ref,
  appointmentId,
) {
  final repository = ref.watch(bookingRepositoryProvider);
  return guardedRead('token card', () => repository.tokenCard(appointmentId));
});

/// Runs `POST /patient/appointments` (§9.1).
///
/// One idempotency key per *request*: a retry of the same slot/person/coupon
/// reuses it so a lost response cannot double-book; a changed request mints
/// a new one. `409 SLOT_UNAVAILABLE` invalidates the slot cache so the flow's
/// next read is fresh. The double-tap guard is the synchronous
/// [BookingSubmitState.isSubmitting] flip before the first `await`.
class BookingSubmitController extends StateNotifier<BookingSubmitState> {
  BookingSubmitController({
    Ref? ref,
    required BookingRepository repository,
    required AvailabilityRepository availability,
    String Function()? mintKey,
    Future<void> Function(String appointmentId)? releaseUnpaid,
  }) : _ref = ref,
       _repository = repository,
       _availability = availability,
       _mintKey = mintKey ?? IdempotencyKeys.mint,
       _releaseUnpaid = releaseUnpaid,
       super(const BookingSubmitState());

  /// Null only in unit tests that construct the controller directly.
  final Ref? _ref;
  final BookingRepository _repository;
  final AvailabilityRepository _availability;
  final String Function() _mintKey;

  /// Cancels a booking that was made but not paid for, so a changed booking
  /// can replace it (`POST /patient/appointments/{id}/cancel`). Null in unit
  /// tests that do not exercise a change.
  final Future<void> Function(String appointmentId)? _releaseUnpaid;

  /// Book [request]. Returns the result, or null when the attempt was
  /// refused (one already in flight, or already booked) or failed — the
  /// failure is then in [BookingSubmitState.failure].
  ///
  /// [quotedTotalPaise] is the total the confirm step was showing; it is kept
  /// so the payment screen can tell the patient if the booking costs
  /// something else.
  Future<BookingResult?> book(
    BookingRequest request, {
    int? quotedTotalPaise,
  }) async {
    if (state.isSubmitting) return null;
    final existing = state.result;
    if (existing != null) {
      // Same booking: resume it (a retried payment, the screen reopened).
      if (state.request == request) return existing;
      // The patient changed the booking after it was made but before paying
      // (another person, slot, coupon or note). Resuming would charge for
      // the old one while showing the new (BL-BOOK-045): release the unpaid
      // booking first — it holds the slot — then book what is on screen.
      if (!await _release(existing)) return null;
    }

    // Same request → same key (§1.8). Anything else is a new action.
    final key = state.request == request && state.idempotencyKey != null
        ? state.idempotencyKey!
        : _mintKey();

    state = state.copyWith(
      isSubmitting: true,
      failure: () => null,
      slotUnavailable: false,
      idempotencyKey: () => key,
      request: () => request,
      quotedTotalPaise: () => quotedTotalPaise,
    );

    try {
      final result = await _repository.book(request, idempotencyKey: key);
      state = state.copyWith(isSubmitting: false, result: () => result);
      // Home's "Your Token" card peeks at the upcoming list, which is not
      // autoDispose; the new booking must reach it without a restart.
      _ref?.invalidate(upcomingAppointmentsPeekProvider);
      return result;
    } on Failure catch (failure) {
      final slotGone =
          failure.apiCode == ApiErrorCodes.slotUnavailable ||
          failure.apiCode == ApiErrorCodes.tokenRangeExhausted;
      if (slotGone) {
        // Slot data is cached server-side for up to 30 s (§1.10): drop ours
        // so the next read cannot show the same taken slot.
        try {
          await _availability.invalidateSlots();
        } catch (_) {
          // A cache drop that fails is a log line, not a booking error.
        }
      }
      state = state.copyWith(
        isSubmitting: false,
        failure: () => failure,
        slotUnavailable: slotGone,
      );
      return null;
    } catch (error, stack) {
      state = state.copyWith(
        isSubmitting: false,
        failure: () => error.asFailure(stack),
      );
      return null;
    }
  }

  /// Cancel the unpaid [booking]. False — with the failure in state — when
  /// it could not be released, so no second booking is made beside it.
  Future<bool> _release(BookingResult booking) async {
    final release = _releaseUnpaid;
    if (release == null ||
        booking.appointment.status != AppointmentStatus.pendingPayment) {
      state = state.copyWith(
        failure: () => const ConflictFailure(
          userMessage:
              'This booking is already paid for and cannot be changed here. '
              'Open it from Appointments.',
        ),
      );
      return false;
    }
    state = state.copyWith(isSubmitting: true, failure: () => null);
    try {
      await release(booking.appointment.id);
    } catch (error, stack) {
      final failure = error.asFailure(stack);
      // Already gone (expired or cancelled): nothing is held any more.
      if (failure.apiCode != ApiErrorCodes.appointmentNotActionable) {
        state = state.copyWith(
          isSubmitting: false,
          failure: () => ConflictFailure(
            userMessage:
                'We could not change your booking: '
                '${failure.userMessage}',
            cause: failure,
          ),
        );
        return false;
      }
    }
    if (!mounted) return false;
    state = const BookingSubmitState();
    return true;
  }

  /// Replace the held result (a retried payment order, a refreshed
  /// appointment) without touching the request bookkeeping.
  void updateResult(BookingResult result) =>
      state = state.copyWith(result: () => result);

  /// Forget the attempt so a new booking can start (the flow was reset).
  void reset() => state = const BookingSubmitState();

  void clearFailure() =>
      state = state.copyWith(failure: () => null, slotUnavailable: false);
}

/// The booking attempt for the current flow. `autoDispose`: it lives exactly
/// as long as the booking and payment screens that watch it.
final bookingSubmitProvider =
    StateNotifierProvider.autoDispose<
      BookingSubmitController,
      BookingSubmitState
    >(
      (ref) => BookingSubmitController(
        ref: ref,
        repository: ref.watch(bookingRepositoryProvider),
        availability: ref.watch(availabilityRepositoryProvider),
        releaseUnpaid: (id) => ref
            .read(appointmentsRepositoryProvider)
            .cancel(
              id,
              idempotencyKey: IdempotencyKeys.mint(),
              reason: 'Changed before payment',
            ),
      ),
    );
