import '../../../../../../core/network/api_client.dart';
import '../../../../../../core/network/endpoints.dart';

/// The `/shared/files` endpoints (`FLUTTER_API_INTEGRATION.md` §11.1, §11.4)
/// as a typed remote data source.
///
/// HTTP only: a path from [Endpoints], a body, the decoded JSON back. No
/// retries, no polling, no mapping — the service does those. Errors
/// propagate as `NetworkException`s for the service to map to `Failure`.
abstract interface class FilesApi {
  /// `POST /shared/files/uploads` → 201 upload ticket.
  Future<Map<String, Object?>> createUpload({
    required String purpose,
    required String mime,
    required int sizeBytes,
    String? sha256,
    String? originalName,
  });

  /// `POST /shared/files/{id}/complete` (no body) → 200 `File`.
  Future<Map<String, Object?>> complete(String fileId);

  /// `GET /shared/files/{id}` → 200 `File`.
  Future<Map<String, Object?>> file(String fileId);

  /// `GET /shared/files/{id}/url` → `{url, expires_at}`.
  Future<Map<String, Object?>> url(String fileId);

  /// `DELETE /shared/files/{id}` → 204.
  Future<void> delete(String fileId, {int? version});
}

class HttpFilesApi implements FilesApi {
  const HttpFilesApi(this._client);

  final ApiClient _client;

  @override
  Future<Map<String, Object?>> createUpload({
    required String purpose,
    required String mime,
    required int sizeBytes,
    String? sha256,
    String? originalName,
  }) async {
    final response = await _client.post(
      Endpoints.fileUploads,
      body: {
        'purpose': purpose,
        'mime': mime,
        'size_bytes': sizeBytes,
        // Unknown body fields are rejected (§11.1), so optionals are only
        // sent when present.
        'sha256': ?sha256,
        'original_name': ?originalName,
      },
    );
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> complete(String fileId) async {
    final response = await _client.post(Endpoints.fileComplete(fileId));
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> file(String fileId) async {
    final response = await _client.get(Endpoints.file(fileId));
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> url(String fileId) async {
    final response = await _client.get(Endpoints.fileUrl(fileId));
    return response.requireMap;
  }

  @override
  Future<void> delete(String fileId, {int? version}) =>
      _client.delete(Endpoints.file(fileId), ifMatch: version);
}
