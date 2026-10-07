import '../../../../core/storage/cache/cached_result.dart';
import '../../../auth/domain/entities/user.dart';
import '../entities/account.dart';

/// The account itself (§4.9 sessions, §5.2 profile, §5.3 phone change,
/// §5.4 alternate phone, §5.6 deletion, §5.7 data export, §5.9 consents).
///
/// `GET /patient/me`, `POST /me/password`, logout and logout-all live in the
/// auth feature's `AuthRepository`; this contract covers the rest. Every
/// throw is a `Failure`.
abstract interface class ProfileRepository {
  // ---- §5.2 ----

  /// `PATCH /patient/me` with `If-Match: "<ifMatch>"` (the `user.version`).
  /// Returns the merged user (user + profile). Stale → `ConflictFailure`
  /// with `CONFLICT_VERSION`; under 18 → `ConflictFailure` `UNDER_AGE`.
  Future<User> updateProfile(ProfileUpdate update, {required int ifMatch});

  // ---- §5.3 — three calls, all with the device fingerprint ----

  /// Sends a code to the **current** number.
  Future<OtpChallenge> startPhoneChange({required String newPhoneE164});

  /// Confirms the old number's code; sends a code to the **new** number.
  Future<OtpChallenge> confirmOldPhone({
    required String challengeId,
    required String code,
  });

  /// Confirms the new number's code. Returns the user with the new phone.
  Future<User> verifyNewPhone({
    required String challengeId,
    required String code,
  });

  // ---- §5.4 ----

  Future<User> setAlternatePhone({required String phoneE164});
  Future<User> removeAlternatePhone();

  // ---- §5.6 ----

  /// `POST /patient/me/deletion-requests` — `Idempotency-Key` required; the
  /// same key must be reused on a retry of the same action (§1.8).
  Future<DeletionRequest> requestDeletion({
    String? reason,
    required String idempotencyKey,
  });

  Stream<CachedResult<List<DeletionRequest>>> deletionRequests({
    bool forceRefresh = false,
  });

  /// `DELETE /patient/me/deletion-requests/{request_no}` → withdrawn.
  Future<DeletionRequest> withdrawDeletion(String requestNo);

  /// `POST /patient/me/reactivate` → the user, `status` back to `active`.
  Future<User> reactivate();

  // ---- §5.7 ----

  /// `GET /patient/me/data-exports`, newest first.
  Stream<CachedResult<List<DataExportRequest>>> dataExports({
    bool forceRefresh = false,
  });

  /// `POST /patient/me/data-exports` — `Idempotency-Key` required; the same
  /// key must be reused on a retry of the same action (§1.8). One open
  /// export at a time: `ConflictFailure` `STATE_CONFLICT` otherwise.
  Future<DataExportRequest> requestDataExport({required String idempotencyKey});

  /// `GET /shared/data-exports/{id}/download-url` for a `completed` request.
  /// `NotFoundFailure` when the file is not ready or its seven days are up.
  Future<DataExportLink> dataExportLink(String id);

  // ---- §5.9 ----

  Stream<CachedResult<List<Consent>>> consents({bool forceRefresh = false});

  /// Only the current published version is accepted (`400` otherwise).
  Future<Consent> acceptConsent({
    required String documentSlug,
    required int documentVersion,
  });

  // ---- §4.9 ----

  Stream<CachedResult<List<AccountSession>>> sessions({
    bool forceRefresh = false,
  });

  /// `DELETE /patient/auth/sessions/{id}` → 204; `404` if not live.
  Future<void> revokeSession(String sessionId);
}
