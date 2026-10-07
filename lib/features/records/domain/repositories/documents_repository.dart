import '../../../common/attachments/domain/entities/stored_file.dart';
import '../../../common/pagination/domain/entities/paged.dart';
import '../entities/medical_document.dart';

/// The documents contract (`FLUTTER_API_INTEGRATION.md` §11.2, §11.3).
///
/// Reads go through the three-layer cache and surface their freshness as a
/// [Snapshot]; mutations hit the API and invalidate the cache. Every method
/// throws a `Failure` (`core/error/failure.dart`), never a raw exception:
/// * a rejected body → `ValidationFailure` with `fieldErrors` (`file_id`
///   when the file is not the user's, wrong purpose or not yet `clean`;
///   `person_id`; `appointment_id`);
/// * a stale `If-Match` → `ConflictFailure(apiCode: CONFLICT_VERSION)`;
/// * a download URL for a file that is not `clean` → `NotFoundFailure`.
abstract interface class DocumentsRepository {
  /// The library, first page of [query]: yields the cached page first (if
  /// any), then the network page. [forceRefresh] skips the cached copy.
  Stream<Snapshot<Paged<MedicalDocument>>> watchDocuments(
    DocumentQuery query, {
    bool forceRefresh = false,
  });

  /// One page, freshest available — for "load more".
  Future<Paged<MedicalDocument>> fetchDocuments(DocumentQuery query);

  /// `GET /patient/documents/{id}`.
  Future<MedicalDocument> document(String id, {bool forceRefresh = false});

  /// `POST /patient/documents` → the created document.
  Future<MedicalDocument> create(DocumentDraft draft);

  /// `PATCH /patient/documents/{id}`; [version] is sent as `If-Match` when
  /// given (optional on this resource, §1.9).
  Future<MedicalDocument> update(
    String id,
    DocumentPatch patch, {
    int? version,
  });

  /// `DELETE /patient/documents/{id}` → 204.
  Future<void> delete(String id, {int? version});

  /// `GET /patient/documents/{id}/download-url` — valid ten minutes, never
  /// cached (§11.3).
  Future<SignedFileUrl> downloadUrl(String id);
}
