import '../../../../app/config/constants.dart';
import '../../../../core/network/api_client.dart' show Page;
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/appointment_detail.dart';
import '../../domain/entities/appointment_event.dart';
import '../../domain/entities/appointment_filter.dart';
import '../../domain/entities/appointment_review.dart';
import '../../domain/entities/cancellation_preview.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/person_summary.dart';
import '../../domain/entities/queue_status.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/entities/token_card.dart';
import '../../domain/repositories/appointments_repository.dart';
import '../data_sources/local/calendar_local_ds.dart';
import '../data_sources/remote/appointments_api.dart';
import 'appointment_mappers.dart';

/// [AppointmentsRepository] over [AppointmentsApi] + [CachedFetcher] +
/// [CalendarLocalDataSource].
///
/// * Every cacheable GET goes through the three-layer fetcher, with the
///   mapper as its validation pipeline (HIVE spec, Scenario 10).
/// * The live queue and the cancellation preview are always re-fetched
///   (`forceRefresh`), but still pass through the fetcher so an offline
///   patient sees the last reading rather than nothing.
/// * Every mutation invalidates the response cache afterwards, so the next
///   list / detail read is fresh (§1.10: it rebuilds at 304 cost).
/// * Every throw is a `Failure` — `NetworkExceptions.toFailure` in each
///   `catch`, so nothing above this class sees a transport type.
class AppointmentsRepositoryImpl implements AppointmentsRepository {
  const AppointmentsRepositoryImpl({
    required AppointmentsApi api,
    required CachedFetcher fetcher,
    required CalendarLocalDataSource calendar,
  }) : _api = api,
       _fetcher = fetcher,
       _calendar = calendar;

  final AppointmentsApi _api;
  final CachedFetcher _fetcher;
  final CalendarLocalDataSource _calendar;

  // ---- Lists ----

  @override
  Stream<CachedResult<Page<Appointment>>> watchList(
    AppointmentListQuery query, {
    int page = 1,
    int? pageSize,
    bool forceRefresh = false,
  }) => _guardStream(
    _fetcher.fetch(
      _api.listRequest(
        query,
        page: page,
        pageSize: pageSize ?? AppConstants.defaultPageSize,
      ),
      AppointmentMappers.appointmentPage,
      forceRefresh: forceRefresh,
    ),
  );

  @override
  Future<Page<Appointment>> fetchList(
    AppointmentListQuery query, {
    int page = 1,
    int? pageSize,
    bool forceRefresh = false,
  }) => _guard(
    () => _fetcher.get(
      _api.listRequest(
        query,
        page: page,
        pageSize: pageSize ?? AppConstants.defaultPageSize,
      ),
      AppointmentMappers.appointmentPage,
      forceRefresh: forceRefresh,
    ),
  );

  // ---- Detail ----

  @override
  Stream<CachedResult<AppointmentDetail>> watchDetail(
    String id, {
    bool forceRefresh = false,
  }) => _guardStream(
    _fetcher.fetch(
      _api.detailRequest(id),
      (body) => AppointmentMappers.detail(AppointmentMappers.requireMap(body)),
      forceRefresh: forceRefresh,
    ),
  );

  @override
  Future<Page<AppointmentEvent>> events(String id) => _guard(
    () => _fetcher.get(_api.eventsRequest(id), AppointmentMappers.eventPage),
  );

  @override
  Future<TokenCard> tokenCard(String id) => _guard(
    () => _fetcher.get(
      _api.tokenCardRequest(id),
      (body) =>
          AppointmentMappers.tokenCard(AppointmentMappers.requireMap(body)),
    ),
  );

  // ---- Live queue ----

  @override
  Future<QueueStatus> queue(String id) => _guard(
    () => _fetcher.get(
      _api.queueRequest(id),
      (body) => AppointmentMappers.queue(AppointmentMappers.requireMap(body)),
      // Live data: skip the cached copy, keep the ETag, keep the last
      // reading for an offline patient.
      forceRefresh: true,
    ),
  );

  // ---- Cancellation ----

  @override
  Future<CancellationPreview> cancellationPreview(String id) => _guard(
    () => _fetcher.get(
      _api.cancellationPreviewRequest(id),
      (body) => AppointmentMappers.cancellationPreview(
        AppointmentMappers.requireMap(body),
      ),
      forceRefresh: true,
    ),
  );

  @override
  Future<CancelOutcome> cancel(
    String id, {
    required String idempotencyKey,
    String? reason,
  }) => _guard(() async {
    final json = await _api.cancel(
      id,
      idempotencyKey: idempotencyKey,
      reason: reason,
    );
    final outcome = AppointmentMappers.cancelOutcome(json);
    await invalidate();
    return outcome;
  });

  // ---- Receipt ----

  @override
  Future<Receipt> receipt(String id) => _guard(
    () => _fetcher.get(
      _api.receiptRequest(id),
      (body) => AppointmentMappers.receipt(AppointmentMappers.requireMap(body)),
    ),
  );

  @override
  Future<ReceiptPdfLink> receiptPdfLink(String id) => _guard(
    () async => AppointmentMappers.receiptPdfLink(await _api.receiptPdf(id)),
  );

  @override
  Future<String> saveCalendarFile(String id) => _guard(() async {
    final file = await _api.calendar(id);
    if (file.bytes.isEmpty) {
      throw const ResponseFormatException(message: 'calendar.ics was empty');
    }
    // The share sheet shows the file name: use the server's (the booking
    // reference), never the appointment id (§1.11).
    final named = file.fileName;
    final stem = named == null
        ? 'medibook-appointment'
        : named.replaceFirst(RegExp(r'\.ics$', caseSensitive: false), '');
    return _calendar.save(stem, file.bytes);
  });

  // ---- Money ----

  @override
  Future<Page<Payment>> payments(String appointmentId) => _guard(
    () => _fetcher.get(
      _api.paymentsRequest(appointmentId),
      AppointmentMappers.paymentPage,
    ),
  );

  @override
  Future<Page<Refund>> refunds(String appointmentId) => _guard(
    () => _fetcher.get(
      _api.refundsRequest(appointmentId),
      AppointmentMappers.refundPage,
    ),
  );

  // ---- Review ----

  @override
  Future<AppointmentReview> review(
    String id, {
    required int rating,
    String? comment,
  }) => _guard(() async {
    final json = await _api.review(id, rating: rating, comment: comment);
    final review = AppointmentMappers.review(json);
    await invalidate();
    return review;
  });

  // ---- Persons ----

  @override
  Future<List<PersonSummary>> persons() => _guard(
    () => _fetcher.get(_api.personsRequest(), AppointmentMappers.personList),
  );

  @override
  Future<void> invalidate() =>
      _fetcher.invalidate(pathPrefix: Endpoints.appointments);

  // ---- Error boundary ----

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        NetworkExceptions.toFailure(error, stackTrace),
        stackTrace,
      );
    }
  }

  Stream<T> _guardStream<T>(Stream<T> source) async* {
    try {
      yield* source;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        NetworkExceptions.toFailure(error, stackTrace),
        stackTrace,
      );
    }
  }
}
