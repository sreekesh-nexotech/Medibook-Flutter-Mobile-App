import '../../../../core/network/endpoints.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/infrastructure/repositories/auth_repository_impl.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/profile_repository.dart';
import '../data_sources/remote/profile_api.dart';
import 'profile_mappers.dart';

/// [ProfileRepository] over [ProfileApi] + [CachedFetcher].
///
/// The `/me` shape (user + profile) is mapped by the auth feature's
/// [AuthMappers.account], which is public for exactly this reuse, so the
/// merged `User` the profile feature hands back is identical to the one the
/// session holds. Every throw is a `Failure`; every mutation invalidates the
/// response cache so the next read is fresh.
class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl({
    required ProfileApi api,
    required CachedFetcher fetcher,
  }) : _api = api,
       _fetcher = fetcher;

  final ProfileApi _api;
  final CachedFetcher _fetcher;

  // ---- §5.2 ----

  @override
  Future<User> updateProfile(
    ProfileUpdate update, {
    required int ifMatch,
  }) async {
    final user = await _run(
      () async => _account(await _api.updateProfile(update, ifMatch: ifMatch)),
    );
    // The "self" person is kept in step with the account (§5.2), so the
    // family list changes too; nothing else does.
    await _fetcher.invalidatePaths(
      paths: {Endpoints.me},
      under: {Endpoints.persons},
    );
    return user;
  }

  // ---- §5.3 ----

  @override
  Future<OtpChallenge> startPhoneChange({required String newPhoneE164}) => _run(
    () async => AuthMappers.challenge(
      await _api.startPhoneChange(newPhoneE164: newPhoneE164),
    ),
  );

  @override
  Future<OtpChallenge> confirmOldPhone({
    required String challengeId,
    required String code,
  }) => _run(
    () async => AuthMappers.challenge(
      await _api.confirmOldPhone(challengeId: challengeId, code: code),
    ),
  );

  @override
  Future<User> verifyNewPhone({
    required String challengeId,
    required String code,
  }) async {
    final user = await _run(
      () async => _userOnly(
        await _api.verifyNewPhone(challengeId: challengeId, code: code),
      ),
    );
    // The "self" person is kept in step with the account (§5.2), so the
    // family list changes too; nothing else does.
    await _fetcher.invalidatePaths(
      paths: {Endpoints.me},
      under: {Endpoints.persons},
    );
    return user;
  }

  // ---- §5.4 ----

  @override
  Future<User> setAlternatePhone({required String phoneE164}) async {
    final user = await _run(
      () async => _userOnly(await _api.setAlternatePhone(phoneE164: phoneE164)),
    );
    await _fetcher.invalidatePaths(paths: {Endpoints.me});
    return user;
  }

  @override
  Future<User> removeAlternatePhone() async {
    final user = await _run(
      () async => _userOnly(await _api.removeAlternatePhone()),
    );
    await _fetcher.invalidatePaths(paths: {Endpoints.me});
    return user;
  }

  // ---- §5.6 ----

  @override
  Future<DeletionRequest> requestDeletion({
    String? reason,
    required String idempotencyKey,
  }) async {
    final request = await _run(
      () async => ProfileMappers.deletionRequestFromBody(
        await _api.requestDeletion(
          reason: reason,
          idempotencyKey: idempotencyKey,
        ),
      ),
    );
    await _fetcher.invalidate(pathPrefix: Endpoints.deletionRequests);
    return request;
  }

  @override
  Stream<CachedResult<List<DeletionRequest>>> deletionRequests({
    bool forceRefresh = false,
  }) => _fetcher
      .fetch(
        _api.deletionRequests(),
        ProfileMappers.deletionRequests,
        forceRefresh: forceRefresh,
      )
      .handleError(_rethrowAsFailure);

  @override
  Future<DeletionRequest> withdrawDeletion(String requestNo) async {
    final request = await _run(
      () async => ProfileMappers.deletionRequestFromBody(
        await _api.withdrawDeletion(requestNo),
      ),
    );
    await _fetcher.invalidate(pathPrefix: Endpoints.deletionRequests);
    return request;
  }

  @override
  Future<User> reactivate() async {
    final user = await _run(() async => _userOnly(await _api.reactivate()));
    await _fetcher.invalidate(pathPrefix: Endpoints.me);
    return user;
  }

  // ---- §5.7 ----

  @override
  Stream<CachedResult<List<DataExportRequest>>> dataExports({
    bool forceRefresh = false,
  }) => _fetcher
      .fetch(
        _api.dataExports(),
        ProfileMappers.dataExports,
        forceRefresh: forceRefresh,
      )
      .handleError(_rethrowAsFailure);

  @override
  Future<DataExportRequest> requestDataExport({
    required String idempotencyKey,
  }) async {
    final request = await _run(
      () async => ProfileMappers.dataExportFromBody(
        await _api.requestDataExport(idempotencyKey: idempotencyKey),
      ),
    );
    await _fetcher.invalidate(pathPrefix: Endpoints.dataExports);
    return request;
  }

  /// Never cached: the link lives ten minutes and every mint is audited.
  @override
  Future<DataExportLink> dataExportLink(String id) => _run(
    () async =>
        ProfileMappers.dataExportLink(await _api.dataExportDownloadUrl(id)),
  );

  // ---- §5.9 ----

  @override
  Stream<CachedResult<List<Consent>>> consents({bool forceRefresh = false}) =>
      _fetcher
          .fetch(
            _api.consents(),
            ProfileMappers.consents,
            forceRefresh: forceRefresh,
          )
          .handleError(_rethrowAsFailure);

  @override
  Future<Consent> acceptConsent({
    required String documentSlug,
    required int documentVersion,
  }) async {
    final consent = await _run(
      () async => ProfileMappers.consentFromBody(
        await _api.acceptConsent(
          documentSlug: documentSlug,
          documentVersion: documentVersion,
        ),
      ),
    );
    await _fetcher.invalidate(pathPrefix: Endpoints.consents);
    return consent;
  }

  // ---- §4.9 ----

  @override
  Stream<CachedResult<List<AccountSession>>> sessions({
    bool forceRefresh = false,
  }) => _fetcher
      .fetch(
        _api.sessions(),
        ProfileMappers.sessions,
        forceRefresh: forceRefresh,
      )
      .handleError(_rethrowAsFailure);

  @override
  Future<void> revokeSession(String sessionId) async {
    await _run(() => _api.revokeSession(sessionId));
    await _fetcher.invalidate(pathPrefix: Endpoints.sessions);
  }

  // ---- internals ----

  /// `{user, profile}` (§5.1 shape) → merged [User].
  static User _account(Map<String, Object?> payload) =>
      AuthMappers.account(payload);

  /// A bare `User` (§5.3 step 3, §5.4, §5.6 reactivate) → [User] with no
  /// profile fields; the caller merges the profile fields it already holds.
  static User _userOnly(Map<String, Object?> payload) =>
      payload.containsKey('user')
      ? AuthMappers.account(payload)
      : AuthMappers.user(payload, method: AuthMethod.password);

  Future<T> _run<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (error, stackTrace) {
      throw NetworkExceptions.toFailure(error, stackTrace);
    }
  }

  static void _rethrowAsFailure(Object error, StackTrace stackTrace) =>
      throw NetworkExceptions.toFailure(error, stackTrace);
}
