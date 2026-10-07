import '../../../../core/storage/cache/cached_result.dart';
import '../../../auth/domain/entities/user.dart';
import '../entities/person.dart';

/// Persons — the account holder and their dependants (§6.1), and the
/// release-to-own-account flow (§5.8). Every throw is a `Failure`.
abstract interface class FamilyRepository {
  /// `GET /patient/me/persons` — "self" first, cached.
  Stream<CachedResult<List<Person>>> persons({bool forceRefresh = false});

  /// `POST /patient/me/persons` → 201. `relation: self` is refused.
  Future<Person> create(PersonDraft draft);

  /// `PATCH /patient/me/persons/{id}` with `If-Match`.
  Future<Person> update(String id, PersonDraft draft, {required int ifMatch});

  /// `DELETE /patient/me/persons/{id}` → 204. `PERSON_IS_SELF` /
  /// `PERSON_HAS_APPOINTMENTS` arrive as `ConflictFailure`.
  Future<void> delete(String id);

  /// `POST /patient/me/persons/{id}/release` — `Idempotency-Key` required.
  /// Sends a code to the dependant's own number.
  Future<OtpChallenge> startRelease({
    required String personId,
    required String phoneE164,
    required String idempotencyKey,
  });

  /// `POST /patient/me/persons/{id}/release/verify`.
  Future<ReleaseResult> verifyRelease({
    required String personId,
    required String challengeId,
    required String code,
  });
}
