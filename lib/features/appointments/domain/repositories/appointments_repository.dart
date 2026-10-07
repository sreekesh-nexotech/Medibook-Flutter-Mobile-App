import '../../../../core/network/models/page.dart';
import '../../../../core/storage/cache/cached_result.dart';
import '../entities/appointment.dart';
import '../entities/appointment_detail.dart';
import '../entities/appointment_event.dart';
import '../entities/appointment_filter.dart';
import '../entities/appointment_review.dart';
import '../entities/cancellation_preview.dart';
import '../entities/payment.dart';
import '../entities/person_summary.dart';
import '../entities/queue_status.dart';
import '../entities/receipt.dart';
import '../entities/token_card.dart';

/// What `POST /patient/appointments/{id}/cancel` returns (§10.7).
class CancelOutcome {
  const CancelOutcome({required this.appointment, this.refunds = const []});

  final Appointment appointment;

  /// Empty when nothing was paid or the refund is 0 %.
  final List<Refund> refunds;
}

/// The largest page the API allows (§1.6).
const int appointmentsMaxPageSize = 100;

/// The appointments contract (`FLUTTER_API_INTEGRATION.md` §10, plus the
/// persons join of §6.1 for display names).
///
/// **Error contract:** every method throws a `Failure` from
/// `core/error/failure.dart` — never a raw exception, never a `dio` type.
/// `NotFoundFailure` for an unknown or foreign id (and for a receipt that has
/// not been issued yet); `ConflictFailure` with `apiCode` for
/// `APPOINTMENT_NOT_ACTIONABLE` / `TOKEN_ALREADY_CALLED` /
/// `TOKEN_CANCEL_WINDOW_CLOSED` / `STATE_CONFLICT`; `NetworkFailure` /
/// `TimeoutFailure` when offline.
///
/// Cacheable reads yield a [CachedResult] stream (cached copy first, then
/// the network answer) so the screen can render the HIVE-spec freshness
/// affordances; live reads and mutations are plain futures.
abstract interface class AppointmentsRepository {
  // ---- Lists (§10.1) ----

  /// One page of the list for [query]. Page numbers start at 1.
  Stream<CachedResult<Page<Appointment>>> watchList(
    AppointmentListQuery query, {
    int page = 1,
    int? pageSize,
    bool forceRefresh = false,
  });

  /// One-shot form of [watchList] — the freshest page available.
  Future<Page<Appointment>> fetchList(
    AppointmentListQuery query, {
    int page = 1,
    int? pageSize,
    bool forceRefresh = false,
  });

  // ---- Detail (§10.2–10.4) ----

  Stream<CachedResult<AppointmentDetail>> watchDetail(
    String id, {
    bool forceRefresh = false,
  });

  Future<Page<AppointmentEvent>> events(String id);

  Future<TokenCard> tokenCard(String id);

  // ---- Live queue (§10.5) — always the network, cache kept for offline ----

  Future<QueueStatus> queue(String id);

  // ---- Cancellation (§10.6–10.7) ----

  Future<CancellationPreview> cancellationPreview(String id);

  /// Cancel with the caller's `Idempotency-Key` (mint one per attempt with
  /// `IdempotencyKeys.mint()` and reuse it on a retry of the same attempt).
  Future<CancelOutcome> cancel(
    String id, {
    required String idempotencyKey,
    String? reason,
  });

  // ---- Receipt (§10.8–10.10) ----

  Future<Receipt> receipt(String id);

  /// A ten-minute signed URL, or `NotFoundFailure` while the PDF is still
  /// being generated / `ServerFailure(NOT_IMPLEMENTED_YET)`.
  Future<ReceiptPdfLink> receiptPdfLink(String id);

  /// Downloads `calendar.ics` and saves it; returns the absolute file path.
  Future<String> saveCalendarFile(String id);

  // ---- Money (§10.11) ----

  Future<Page<Payment>> payments(String appointmentId);

  Future<Page<Refund>> refunds(String appointmentId);

  // ---- Review (§10.12) ----

  Future<AppointmentReview> review(
    String id, {
    required int rating,
    String? comment,
  });

  // ---- Persons join (§6.1) ----

  /// The account's family members, for "For Aarav (Son)" and the patient
  /// filter. Cached like any other read.
  Future<List<PersonSummary>> persons();

  /// Forget every cached appointment read — after a mutation made elsewhere
  /// (a booking paid for, a cancellation) so the next read is fresh.
  Future<void> invalidate();
}
