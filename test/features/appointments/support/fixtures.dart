import 'dart:async';

import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/api_client.dart' show Page;
import 'package:medibook/core/network/realtime/ws_client.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_detail.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_event.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_filter.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_review.dart';
import 'package:medibook/features/appointments/domain/entities/cancellation_preview.dart';
import 'package:medibook/features/appointments/domain/entities/payment.dart';
import 'package:medibook/features/appointments/domain/entities/person_summary.dart';
import 'package:medibook/features/appointments/domain/entities/queue_status.dart';
import 'package:medibook/features/appointments/domain/entities/receipt.dart';
import 'package:medibook/features/appointments/domain/entities/token_card.dart';
import 'package:medibook/features/appointments/domain/repositories/appointments_repository.dart';
import 'package:medibook/features/appointments/infrastructure/repositories/appointment_mappers.dart';

/// Wire shapes captured from the live backend on 2026-09-30 (booking
/// `01a0f15b-bcf6-7b91-a0eb-2d9a1d7ebacf`, cancelled afterwards) plus the
/// §10.8 receipt example from the contract, since the test account has no
/// paid booking.
abstract final class Fixtures {
  Fixtures._();

  static const String appointmentId = '01a0f15b-bcf6-7b91-a0eb-2d9a1d7ebacf';

  static Map<String, Object?> appointmentJson({
    String status = 'pending_payment',
    int version = 1,
  }) => {
    'id': appointmentId,
    'booking_ref': 'LKSB-2609-00182',
    'status': status,
    'status_reason': null,
    'source': 'online',
    'hospital': {
      'id': '01a0ee28-80b3-7162-9efe-032fb9e1b6af',
      'name': 'Lakeshore Multispeciality Hospital',
      'city': 'Kochi',
      'phone_e164': '+914842701000',
      'timezone': 'Asia/Kolkata',
    },
    'department': {
      'id': '01a0ee28-848a-7f52-89d9-c840d366ade4',
      'code': 'general_medicine',
      'name': 'General Medicine',
    },
    'doctor': {
      'id': '01a0ee28-8526-7eb1-bb66-0f67c9c21951',
      'name': 'Dr. Suresh Pillai',
      'title': 'Consultant',
      'specialisation': 'Internal Medicine',
      'room': 'OPD-01',
    },
    'person_id': '01a0f15b-4ac4-7241-be2e-d9cd1bce1eb8',
    'session_id': '01a0ee29-1dbe-7b31-bbeb-d47082d9f003',
    'slot_id': '01a0ee29-1dc2-7262-874f-ed7b64f66af8',
    'scheduled_date': '2026-10-02',
    'scheduled_start_at': '2026-10-02T11:30:00Z',
    'scheduled_end_at': '2026-10-02T11:45:00Z',
    'token_no': 2,
    'token_label': 'A002',
    'token_source': 'online',
    'is_follow_up': false,
    'patient_notes': 'integration shape check',
    'payment_status': 'pending',
    'booking_deadline_at': '2026-09-30T08:13:36.215023Z',
    'consultation_fee_paise': 50000,
    'service_fee_paise': 0,
    'discount_paise': 0,
    'convenience_fee_paise': 2000,
    'tax_paise': 400,
    'tax_lines': [
      {
        'code': 'EXEMPT',
        'line': 'consultation',
        'rate_bp': 0,
        'supplier': 'hospital',
        'inclusive': false,
        'tax_paise': 0,
        'base_paise': 50000,
      },
      {
        'code': 'CONVENIENCE_FEE_GST',
        'line': 'convenience_fee',
        'rate_bp': 1800,
        'supplier': 'platform',
        'inclusive': false,
        'tax_paise': 400,
        'base_paise': 2000,
      },
    ],
    'total_paise': 52400,
    'currency': 'INR',
    'cancelled_at': null,
    'cancelled_by': null,
    'cancellation_reason': null,
    'checked_in_at': null,
    'called_at': null,
    'completed_at': null,
    'created_at': '2026-09-30T08:08:36.342516Z',
    'version': version,
  };

  static Map<String, Object?> detailJson() => {
    ...appointmentJson(),
    'receipt': null,
    'refunds': <Object?>[],
    'actions': {
      'can_cancel': true,
      'cancel_blocked_reason': null,
      'can_retry_payment': true,
      'can_review': false,
    },
    'reviewed': false,
    'payment_order': {
      'id': '01a0f15b-bd1b-7a22-bdb7-76678a633477',
      'appointment_id': appointmentId,
      'amount_paise': 52400,
      'currency': 'INR',
      'channel': 'online',
      'gateway': 'razorpay',
      'gateway_order_id': 'order_fakee00f1a22d66c40',
      'status': 'created',
      'attempts': 1,
      'expires_at': '2026-09-30T08:13:36.215023Z',
      'key_id': '',
      'created_at': '2026-09-30T08:08:36.379633Z',
    },
  };

  static Map<String, Object?> cancelledDetailJson() => {
    ...detailJson(),
    ...appointmentJson(status: 'cancelled', version: 2),
    'cancelled_at': '2026-09-30T08:09:06.975602Z',
    'cancelled_by': 'patient',
    'cancellation_reason': 'integration shape check',
    'actions': {
      'can_cancel': false,
      'cancel_blocked_reason': 'APPOINTMENT_NOT_ACTIONABLE',
      'can_retry_payment': false,
      'can_review': false,
    },
  };

  static Map<String, Object?> queueJson() => {
    'session_state': 'scheduled',
    'queue_state': 'available',
    'current_token': null,
    'current_token_no': null,
    'last_called_token': null,
    'your_token': 'A002',
    'your_token_no': 2,
    'tokens_ahead': 0,
    'estimated_wait_minutes': 0,
    'updated_at': '2026-09-29T17:14:27.135034+00:00',
  };

  static Map<String, Object?> previewJson({bool allowed = true}) => {
    'allowed': allowed,
    'reason': allowed ? null : 'APPOINTMENT_NOT_ACTIONABLE',
    'cutoff_at': '2026-10-02T07:30:00+00:00',
    'before_cutoff': true,
    'refund_bp': 10000,
    'refund_paise': 45000,
    'non_refundable_paise': 3000,
    'includes_convenience_fee': false,
  };

  static Map<String, Object?> cancelOutcomeJson() => {
    'appointment': cancelledDetailJson(),
    'refunds': <Object?>[],
  };

  static Map<String, Object?> eventsPageJson() => {
    'results': [
      {
        'id': '01a0f15b-bd0f-7c20-8539-bd6c78dd0590',
        'event_type': 'created',
        'actor_kind': 'patient',
        'from_status': null,
        'to_status': 'pending_payment',
        'occurred_at': '2026-09-30T08:08:36.215023+00:00',
      },
      {
        'id': '01a0f15c-34a4-71f2-9096-e92b9acfd7dd',
        'event_type': 'cancelled',
        'actor_kind': 'patient',
        'from_status': 'pending_payment',
        'to_status': 'cancelled',
        'occurred_at': '2026-09-30T08:09:06.975602+00:00',
      },
    ],
    'page': 1,
    'page_size': 25,
    'total': 2,
    'has_next': false,
  };

  static Map<String, Object?> tokenCardJson() => {
    'booking_ref': 'LKSB-2609-00182',
    'token_label': 'A002',
    'token_no': 2,
    'qr_payload': 'LKSB-2609-00182',
    'status': 'pending_payment',
    'patient_name': 'Test Dependant',
    'hospital': {
      'name': 'Lakeshore Multispeciality Hospital',
      'address_line1': 'NH 66 Bypass, Maradu',
      'address_line2': 'Near Vyttila Hub',
      'address_line3': null,
      'city': 'Kochi',
      'state': 'Kerala',
      'pincode': '682040',
      'phone_e164': '+914842701000',
    },
    'doctor': {
      'name': 'Dr. Suresh Pillai',
      'title': 'Consultant',
      'room': 'OPD-01',
    },
    'department': {'name': 'General Medicine'},
    'date': '2026-10-02',
    'start_time': '17:00',
    'end_time': '17:15',
    'starts_at': '2026-10-02T11:30:00+00:00',
    'ends_at': '2026-10-02T11:45:00+00:00',
    'session': {
      'session_code': 'evening',
      'label': 'Evening OPD',
      'starts_at': '2026-10-02T11:30:00+00:00',
      'ends_at': '2026-10-02T13:30:00+00:00',
    },
  };

  /// §10.8 example (no paid booking exists on the test account).
  static Map<String, Object?> receiptJson() => {
    'id': 'rc-1',
    'receipt_no': 'RC/26-27/000311',
    'fy_code': '26-27',
    'issued_at': '2026-09-30T10:02:11+00:00',
    'issued_by_name': null,
    'counter_code': null,
    'subtotal_paise': 47500,
    'tax_paise': 500,
    'total_paise': 48000,
    'lines': [
      {
        'supplier': 'hospital',
        'line': 'consultation',
        'description': 'Consultation',
        'qty': 1,
        'unit_paise': 50000,
        'amount_paise': 50000,
        'tax_code': 'EXEMPT',
        'tax_rate_bp': 0,
        'tax_paise': 0,
        'tax_inclusive': false,
        'appointment_id': appointmentId,
        'booking_ref': 'MB-2026-000124',
      },
      {
        'supplier': 'hospital',
        'line': 'discount',
        'description': 'Discount',
        'qty': 1,
        'unit_paise': -5000,
        'amount_paise': -5000,
        'tax_code': null,
        'tax_rate_bp': 0,
        'tax_paise': 0,
        'tax_inclusive': false,
        'appointment_id': appointmentId,
        'booking_ref': 'MB-2026-000124',
      },
      {
        'supplier': 'platform',
        'line': 'convenience_fee',
        'description': 'Convenience fee',
        'qty': 1,
        'unit_paise': 2500,
        'amount_paise': 2500,
        'tax_code': 'CONVENIENCE_FEE_GST',
        'tax_rate_bp': 1800,
        'tax_paise': 500,
        'tax_inclusive': false,
        'appointment_id': appointmentId,
        'booking_ref': 'MB-2026-000124',
      },
    ],
    'payment_lines': [
      {'method': 'upi', 'amount_paise': 48000, 'reference': 'pay_NXb'},
    ],
    'hospital': {
      'id': 'h-1',
      'name': 'City Care Hospital',
      'legal_name': 'City Care Hospital Pvt Ltd',
      'gstin': '32ABCDE1234F1Z5',
      'address_line1': 'NH 66',
      'address_line2': null,
      'address_line3': null,
      'city': 'Kochi',
      'state': 'Kerala',
      'pincode': '682024',
      'phone_e164': '+914842000000',
      'logo_file_id': 'f-1',
      'stamp_file_id': null,
    },
    'platform': {
      'legal_name': 'Medibook Health Services Pvt Ltd',
      'gstin': '27AABCM9407L1ZK',
      'address_line1': 'Bandra Kurla Complex',
      'address_line2': null,
      'address_line3': null,
      'city': 'Mumbai',
      'state': 'Maharashtra',
      'pincode': '400051',
    },
    'pdf_available': true,
  };

  static Map<String, Object?> pageJson(
    List<Map<String, Object?>> rows, {
    int page = 1,
    int total = -1,
    bool hasNext = false,
  }) => {
    'results': rows,
    'page': page,
    'page_size': 20,
    'total': total < 0 ? rows.length : total,
    'has_next': hasNext,
  };

  static Appointment appointment({String status = 'pending_payment'}) =>
      AppointmentMappers.appointment(appointmentJson(status: status));

  static AppointmentDetail detail() => AppointmentMappers.detail(detailJson());
}

/// An in-memory [AppointmentsRepository] whose answers a test scripts.
class FakeAppointmentsRepository implements AppointmentsRepository {
  final List<Page<Appointment>> pages = [];

  /// When set, `watchList` first emits this as a cached (hive) copy with
  /// `revalidating: true`, then the scripted page from the network.
  Page<Appointment>? cachedFirstPage;
  bool cachedIsStale = false;

  Failure? listFailure;
  Failure? loadMoreFailure;
  int listCalls = 0;
  int fetchCalls = 0;
  final List<int> fetchedPages = [];

  AppointmentDetail? detailValue;
  QueueStatus queueValue = AppointmentMappers.queue(Fixtures.queueJson());
  Failure? queueFailure;
  int queueCalls = 0;

  CancellationPreview previewValue = AppointmentMappers.cancellationPreview(
    Fixtures.previewJson(),
  );
  Failure? cancelFailure;
  final List<String> cancelKeys = [];
  final List<String?> cancelReasons = [];
  int invalidations = 0;

  @override
  Stream<CachedResult<Page<Appointment>>> watchList(
    AppointmentListQuery query, {
    int page = 1,
    int? pageSize,
    bool forceRefresh = false,
  }) async* {
    listCalls++;
    final cached = cachedFirstPage;
    if (cached != null && !forceRefresh) {
      yield CachedResult(
        value: cached,
        source: CacheSource.hive,
        cachedAt: DateTime.now().subtract(const Duration(hours: 30)),
        isStale: cachedIsStale,
        revalidating: true,
      );
    }
    final failure = listFailure;
    if (failure != null) throw failure;
    yield CachedResult(
      value: pages.isEmpty ? const Page.empty() : pages.first,
      source: CacheSource.network,
      cachedAt: DateTime.now(),
    );
  }

  @override
  Future<Page<Appointment>> fetchList(
    AppointmentListQuery query, {
    int page = 1,
    int? pageSize,
    bool forceRefresh = false,
  }) async {
    fetchCalls++;
    fetchedPages.add(page);
    final failure = loadMoreFailure;
    if (failure != null) throw failure;
    if (page - 1 >= pages.length) return const Page.empty();
    return pages[page - 1];
  }

  @override
  Stream<CachedResult<AppointmentDetail>> watchDetail(
    String id, {
    bool forceRefresh = false,
  }) async* {
    final value = detailValue;
    if (value == null) throw const NotFoundFailure();
    yield CachedResult(
      value: value,
      source: CacheSource.network,
      cachedAt: DateTime.now(),
    );
  }

  @override
  Future<Page<AppointmentEvent>> events(String id) async =>
      AppointmentMappers.eventPage(Fixtures.eventsPageJson());

  @override
  Future<TokenCard> tokenCard(String id) async =>
      AppointmentMappers.tokenCard(Fixtures.tokenCardJson());

  @override
  Future<QueueStatus> queue(String id) async {
    queueCalls++;
    final failure = queueFailure;
    if (failure != null) throw failure;
    return queueValue;
  }

  @override
  Future<CancellationPreview> cancellationPreview(String id) async =>
      previewValue;

  @override
  Future<CancelOutcome> cancel(
    String id, {
    required String idempotencyKey,
    String? reason,
  }) async {
    cancelKeys.add(idempotencyKey);
    cancelReasons.add(reason);
    final failure = cancelFailure;
    if (failure != null) throw failure;
    invalidations++;
    return AppointmentMappers.cancelOutcome(Fixtures.cancelOutcomeJson());
  }

  @override
  Future<Receipt> receipt(String id) async =>
      AppointmentMappers.receipt(Fixtures.receiptJson());

  @override
  Future<ReceiptPdfLink> receiptPdfLink(String id) async =>
      const ReceiptPdfLink(url: 'https://example.test/r.pdf', receiptNo: 'RC');

  @override
  Future<String> saveCalendarFile(String id) async => '/tmp/medibook-$id.ics';

  @override
  Future<Page<Payment>> payments(String appointmentId) async =>
      const Page.empty();

  @override
  Future<Page<Refund>> refunds(String appointmentId) async =>
      const Page.empty();

  @override
  Future<AppointmentReview> review(
    String id, {
    required int rating,
    String? comment,
  }) async {
    invalidations++;
    return AppointmentReview(
      id: 'rv-1',
      appointmentId: id,
      doctorId: 'd-1',
      rating: rating,
      comment: comment,
      moderationStatus: 'pending',
    );
  }

  @override
  Future<List<PersonSummary>> persons() async => const [
    PersonSummary(
      id: '01a0f15b-4ac4-7241-be2e-d9cd1bce1eb8',
      name: 'Test Dependant',
      relation: 'other',
    ),
  ];

  @override
  Future<void> invalidate() async => invalidations++;
}

/// A [WsClient] a test drives by hand: no socket, scripted frames and
/// close reasons.
class FakeWsClient extends WsClient {
  FakeWsClient(String path)
    : path = path,
      super(url: 'wss://test$path', accessToken: () async => 'token');

  final String path;
  final StreamController<WsFrame> _frames = StreamController.broadcast();
  final StreamController<WsCloseReason> _closed = StreamController.broadcast();
  int connectCalls = 0;
  bool refuseConnect = false;

  /// Refuse the upgrade the way the live server refuses a bad token.
  bool refuseHandshake = false;
  bool disposed = false;

  @override
  Stream<WsFrame> get frames => _frames.stream;

  @override
  Stream<WsCloseReason> get closed => _closed.stream;

  @override
  Future<void> connect() async {
    connectCalls++;
    if (refuseHandshake) {
      throw const WsHandshakeRefused('HTTP status code: 403');
    }
    if (refuseConnect) throw StateError('refused');
  }

  void emit(String type, Map<String, Object?> data) =>
      _frames.add(WsFrame(type: type, data: data, timestamp: DateTime.now()));

  void close(WsCloseReason reason) => _closed.add(reason);

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await _frames.close();
    await _closed.close();
  }
}
