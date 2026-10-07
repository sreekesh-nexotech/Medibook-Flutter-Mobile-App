import '../entities/stored_file.dart';

/// Where a picked file comes from.
enum PickSource { files, gallery, camera }

/// The shared upload contract (`FLUTTER_API_INTEGRATION.md` §11.1), used by
/// records, insurance and support.
///
/// **Error contract:** every method throws a `Failure` from
/// `core/error/failure.dart`:
/// * a disallowed type / an oversize file → `ValidationFailure` with
///   `apiCode` `FILE_TYPE_NOT_ALLOWED` / `FILE_TOO_LARGE`, raised **before**
///   any request (the client-side check) or by the server;
/// * storage / network problems → `NetworkFailure`, `TimeoutFailure`,
///   `ServerFailure` (`PROVIDER_UNAVAILABLE` when storage is down);
/// * `DELETE` of a referenced file → `ConflictFailure(apiCode: FILE_IN_USE)`.
///
/// Scan verdicts are **not** errors: [upload] returns a typed
/// [UploadOutcome] so the UI can say "rejected" or "still scanning" in words.
abstract interface class FileUploadService {
  /// Open the platform picker for [purpose] and return the chosen file, or
  /// null when the user cancelled. The picker is pre-filtered to the
  /// allowlist where the platform supports it; [upload] re-checks anyway.
  Future<PickedFile?> pick(
    FileUploadPurpose purpose, {
    PickSource source = PickSource.files,
  });

  /// The three steps of §11.1 plus the scan poll:
  /// validate → `POST /shared/files/uploads` → PUT bytes to storage with
  /// exactly the returned headers → `POST …/complete` → poll
  /// `GET /shared/files/{id}` with a bounded backoff.
  ///
  /// [onProgress] is called on the caller's zone as the phases advance.
  Future<UploadOutcome> upload(
    PickedFile file, {
    required FileUploadPurpose purpose,
    void Function(UploadProgress progress)? onProgress,
  });

  /// Re-poll a file whose scan had not finished ([UploadScanTimedOut]).
  Future<UploadOutcome> awaitScan(String fileId);

  /// `GET /shared/files/{id}` — the current server state.
  Future<StoredFile> file(String fileId);

  /// `DELETE /shared/files/{id}` → 204, or `FILE_IN_USE` while a document or
  /// policy still references it.
  Future<void> delete(String fileId, {int? version});
}
