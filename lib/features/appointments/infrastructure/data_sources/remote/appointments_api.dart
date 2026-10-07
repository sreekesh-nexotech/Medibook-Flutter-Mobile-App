import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';
import '../../../domain/entities/appointment_filter.dart';
import '../../../domain/repositories/appointments_repository.dart';

/// The appointments endpoints (`FLUTTER_API_INTEGRATION.md` §10, §6.1), as a
/// typed remote data source.
///
/// Reads are exposed as [ApiRequest] builders so the repository can run them
/// through `CachedFetcher` (the three-layer cache); mutations and the two
/// non-cacheable reads (a ten-minute signed URL, a file download) go through
/// [ApiClient] directly. This layer owns *which endpoint and which payload
/// shape* and nothing else — no caching decisions, no entity mapping, no
/// `try`/`catch`: errors propagate as `NetworkException`s for the repository
/// to map.
abstract interface class AppointmentsApi {
  /// `GET /patient/appointments` with only the parameters §10.1 lists.
  ApiRequest listRequest(
    AppointmentListQuery query, {
    required int page,
    required int pageSize,
  });

  ApiRequest detailRequest(String id);

  ApiRequest eventsRequest(String id);

  ApiRequest tokenCardRequest(String id);

  ApiRequest queueRequest(String id);

  ApiRequest cancellationPreviewRequest(String id);

  ApiRequest receiptRequest(String id);

  ApiRequest paymentsRequest(String appointmentId);

  ApiRequest refundsRequest(String appointmentId);

  ApiRequest personsRequest();

  /// `POST /patient/appointments/{id}/cancel` (Idempotency-Key required).
  Future<Map<String, Object?>> cancel(
    String id, {
    required String idempotencyKey,
    String? reason,
  });

  /// `GET /patient/appointments/{id}/receipt.pdf` → `{url, receipt_no}`.
  Future<Map<String, Object?>> receiptPdf(String id);

  /// `GET /patient/appointments/{id}/calendar.ics` → the raw bytes and the
  /// file name the server gave it (`Content-Disposition`, the booking
  /// reference — never the appointment id, §1.11), when it sent one.
  Future<({List<int> bytes, String? fileName})> calendar(String id);

  /// `POST /patient/appointments/{id}/review` → 201 review.
  Future<Map<String, Object?>> review(
    String id, {
    required int rating,
    String? comment,
  });
}

/// [AppointmentsApi] over the [ApiClient] interface — every path from
/// [Endpoints], no URL literals, no inline JSON keys outside this file.
class HttpAppointmentsApi implements AppointmentsApi {
  const HttpAppointmentsApi(this._client);

  final ApiClient _client;

  /// The largest page the API allows (§1.6) — for the persons join.
  static const int maxPageSize = appointmentsMaxPageSize;

  @override
  ApiRequest listRequest(
    AppointmentListQuery query, {
    required int page,
    required int pageSize,
  }) {
    final filter = query.filter;
    final statuses = query.statuses;
    final q = query.q?.trim();
    return ApiRequest(
      path: Endpoints.appointments,
      query: {
        ...Endpoints.page(page, size: pageSize),
        // Only what §10.1 lists; nulls are dropped by the client and an
        // unknown parameter would be a 400.
        'bucket': query.bucket,
        'status': statuses.isEmpty
            ? null
            : statuses.map((s) => s.wire).join(','),
        'doctor_id': filter.doctorId,
        'hospital_id': filter.hospitalId,
        'person_id': filter.personId,
        'date_from': filter.from == null ? null : _date(filter.from!),
        'date_to': filter.to == null ? null : _date(filter.to!),
        'q': q == null || q.isEmpty ? null : q,
        'sort': query.sort,
      },
    );
  }

  @override
  ApiRequest detailRequest(String id) =>
      ApiRequest(path: Endpoints.appointment(id));

  @override
  ApiRequest eventsRequest(String id) => ApiRequest(
    path: Endpoints.appointmentEvents(id),
    query: {
      ...Endpoints.page(1, size: maxPageSize),
      'sort': 'occurred_at',
    },
  );

  @override
  ApiRequest tokenCardRequest(String id) =>
      ApiRequest(path: Endpoints.appointmentTokenCard(id));

  @override
  ApiRequest queueRequest(String id) =>
      ApiRequest(path: Endpoints.appointmentQueue(id));

  @override
  ApiRequest cancellationPreviewRequest(String id) =>
      ApiRequest(path: Endpoints.appointmentCancellationPreview(id));

  @override
  ApiRequest receiptRequest(String id) =>
      ApiRequest(path: Endpoints.appointmentReceipt(id));

  @override
  ApiRequest paymentsRequest(String appointmentId) => ApiRequest(
    path: Endpoints.payments,
    query: {
      'appointment_id': appointmentId,
      'sort': '-created_at',
      ...Endpoints.page(1, size: maxPageSize),
    },
  );

  @override
  ApiRequest refundsRequest(String appointmentId) => ApiRequest(
    path: Endpoints.refunds,
    query: {
      'appointment_id': appointmentId,
      'sort': '-requested_at',
      ...Endpoints.page(1, size: maxPageSize),
    },
  );

  @override
  ApiRequest personsRequest() => ApiRequest(
    path: Endpoints.persons,
    query: Endpoints.page(1, size: maxPageSize),
  );

  @override
  Future<Map<String, Object?>> cancel(
    String id, {
    required String idempotencyKey,
    String? reason,
  }) async {
    final response = await _client.post(
      Endpoints.appointmentCancel(id),
      // The idempotency match is on raw body bytes (§1.8), so the body is
      // built the same way every time: a reason key only when there is one.
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      idempotencyKey: idempotencyKey,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> receiptPdf(String id) async {
    final response = await _client.get(Endpoints.appointmentReceiptPdf(id));
    return response.requireMap;
  }

  @override
  Future<({List<int> bytes, String? fileName})> calendar(String id) async {
    final response = await _client.send(
      ApiRequest(
        path: Endpoints.appointmentCalendar(id),
        responseType: ApiResponseType.bytes,
      ),
    );
    return (
      bytes: response.asBytes,
      fileName: attachmentFileName(response.headers['content-disposition']),
    );
  }

  /// `attachment; filename="LKSB-2609-00165.ics"` → `LKSB-2609-00165.ics`.
  static String? attachmentFileName(String? contentDisposition) {
    if (contentDisposition == null) return null;
    final match = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    final name = match?.group(1)?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  @override
  Future<Map<String, Object?>> review(
    String id, {
    required int rating,
    String? comment,
  }) async {
    final response = await _client.post(
      Endpoints.appointmentReview(id),
      body: {
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );
    return response.requireMap;
  }

  /// `YYYY-MM-DD` — the wire date format (§1.11).
  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
