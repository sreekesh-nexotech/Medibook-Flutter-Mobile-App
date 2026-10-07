import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';

/// The `/patient/documents` endpoints (§11.2, §11.3) as a typed remote data
/// source.
///
/// GETs are handed back as [ApiRequest]s because they are served through
/// `CachedFetcher`, which performs the call itself; mutations are performed
/// here over [ApiClient]. No mapping, no caching, no retries — the
/// repository owns those. Query values arrive already stringified so this
/// class spells only paths and parameter names.
abstract interface class DocumentsApi {
  /// `GET /patient/documents?…` with only the parameters §11.2 lists.
  ApiRequest listRequest({
    String? docType,
    String? personId,
    String? dateFrom,
    String? dateTo,
    String? appointmentId,
    String? q,
    required String sort,
    required int page,
    required int pageSize,
  });

  /// `GET /patient/documents/{id}`.
  ApiRequest detailRequest(String id);

  /// `POST /patient/documents` → 201.
  Future<Map<String, Object?>> create(Map<String, Object?> body);

  /// `PATCH /patient/documents/{id}` (+ optional `If-Match`) → 200.
  Future<Map<String, Object?>> patch(
    String id,
    Map<String, Object?> body, {
    int? version,
  });

  /// `DELETE /patient/documents/{id}` → 204.
  Future<void> delete(String id, {int? version});

  /// `GET /patient/documents/{id}/download-url` → `{url, expires_at}`.
  Future<Map<String, Object?>> downloadUrl(String id);
}

class HttpDocumentsApi implements DocumentsApi {
  const HttpDocumentsApi(this._client);

  final ApiClient _client;

  @override
  ApiRequest listRequest({
    String? docType,
    String? personId,
    String? dateFrom,
    String? dateTo,
    String? appointmentId,
    String? q,
    required String sort,
    required int page,
    required int pageSize,
  }) => ApiRequest(
    path: Endpoints.documents,
    // Nulls are dropped by the client, so an unused filter is never sent
    // (an unknown or empty parameter is a 400, §1.7).
    query: {
      'doc_type': docType,
      'person_id': personId,
      'date_from': dateFrom,
      'date_to': dateTo,
      'appointment_id': appointmentId,
      'q': q,
      'sort': sort,
      ...Endpoints.page(page, size: pageSize),
    },
  );

  @override
  ApiRequest detailRequest(String id) =>
      ApiRequest(path: Endpoints.document(id));

  @override
  Future<Map<String, Object?>> create(Map<String, Object?> body) async {
    final response = await _client.post(Endpoints.documents, body: body);
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> patch(
    String id,
    Map<String, Object?> body, {
    int? version,
  }) async {
    final response = await _client.patch(
      Endpoints.document(id),
      body: body,
      ifMatch: version,
    );
    return response.requireMap;
  }

  @override
  Future<void> delete(String id, {int? version}) =>
      _client.delete(Endpoints.document(id), ifMatch: version);

  @override
  Future<Map<String, Object?>> downloadUrl(String id) async {
    final response = await _client.get(Endpoints.documentDownloadUrl(id));
    return response.requireMap;
  }
}
