import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';

/// The `/patient/me/insurance-policies` endpoints (§6.4) as a typed remote
/// data source. GETs are [ApiRequest]s for `CachedFetcher`; mutations run
/// over [ApiClient]. Paths and parameter names only — no mapping.
abstract interface class InsuranceApi {
  /// `GET /patient/me/insurance-policies?sort=valid_to[&person_id=]`.
  ApiRequest listRequest({String? personId, required int pageSize});

  /// `GET /patient/me/insurance-policies/{id}`.
  ApiRequest detailRequest(String id);

  Future<Map<String, Object?>> create(Map<String, Object?> body);

  Future<Map<String, Object?>> patch(
    String id,
    Map<String, Object?> body, {
    required int version,
  });

  Future<void> delete(String id);

  /// `POST /{id}/documents {file_id}` → 201 policy with documents.
  Future<Map<String, Object?>> attachDocument(String id, String fileId);

  /// `DELETE /{id}/documents/{file_id}` → 204.
  Future<void> detachDocument(String id, String fileId);
}

class HttpInsuranceApi implements InsuranceApi {
  const HttpInsuranceApi(this._client);

  final ApiClient _client;

  @override
  ApiRequest listRequest({String? personId, required int pageSize}) =>
      ApiRequest(
        path: Endpoints.insurancePolicies,
        query: {
          'person_id': personId,
          // Soonest-expiring first: the one that needs attention on top.
          'sort': 'valid_to',
          ...Endpoints.page(1, size: pageSize),
        },
      );

  @override
  ApiRequest detailRequest(String id) =>
      ApiRequest(path: Endpoints.insurancePolicy(id));

  @override
  Future<Map<String, Object?>> create(Map<String, Object?> body) async {
    final response = await _client.post(
      Endpoints.insurancePolicies,
      body: body,
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> patch(
    String id,
    Map<String, Object?> body, {
    required int version,
  }) async {
    final response = await _client.patch(
      Endpoints.insurancePolicy(id),
      body: body,
      ifMatch: version,
    );
    return response.requireMap;
  }

  @override
  Future<void> delete(String id) =>
      _client.delete(Endpoints.insurancePolicy(id));

  @override
  Future<Map<String, Object?>> attachDocument(String id, String fileId) async {
    final response = await _client.post(
      Endpoints.insurancePolicyDocuments(id),
      body: {'file_id': fileId},
    );
    return response.requireMap;
  }

  @override
  Future<void> detachDocument(String id, String fileId) =>
      _client.delete(Endpoints.insurancePolicyDocument(id, fileId));
}
