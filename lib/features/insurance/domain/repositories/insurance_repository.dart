import '../../../common/pagination/domain/entities/paged.dart';
import '../entities/insurance_policy.dart';

/// The insurance-policies contract (`FLUTTER_API_INTEGRATION.md` §6.4).
///
/// Reads go through the three-layer cache and carry their freshness as a
/// [Snapshot]; mutations hit the API and invalidate the cache. Every method
/// throws a `Failure` (`core/error/failure.dart`), never a raw exception:
/// * a rejected body → `ValidationFailure` with `fieldErrors` (`valid_to`
///   before `valid_from`, `file_id` not an own `insurance` upload…);
/// * a stale `If-Match` → `ConflictFailure(apiCode: CONFLICT_VERSION)`;
/// * an unknown id → `NotFoundFailure`.
abstract interface class InsuranceRepository {
  /// Every policy on the account, `documents` omitted (the list endpoint
  /// does not send them). Cached page first, then the network page.
  Stream<Snapshot<List<InsurancePolicy>>> watchPolicies({
    String? personId,
    bool forceRefresh = false,
  });

  /// `GET /patient/me/insurance-policies/{id}` — with `documents`.
  Future<InsurancePolicy> policy(String id, {bool forceRefresh = false});

  /// `POST` → the created policy (with `documents: []`).
  Future<InsurancePolicy> create(PolicyDraft draft);

  /// `PATCH` with `If-Match: "<version>"` (required on this resource).
  Future<InsurancePolicy> update(
    String id,
    PolicyPatch patch, {
    required int version,
  });

  /// `DELETE` → 204.
  Future<void> delete(String id);

  /// `POST /{id}/documents {file_id}` — the file must be the patient's own
  /// `clean` upload with purpose `insurance`. Returns the policy with its
  /// documents.
  Future<InsurancePolicy> attachDocument(String id, String fileId);

  /// `DELETE /{id}/documents/{file_id}` → 204; the file itself is kept.
  Future<void> detachDocument(String id, String fileId);
}
