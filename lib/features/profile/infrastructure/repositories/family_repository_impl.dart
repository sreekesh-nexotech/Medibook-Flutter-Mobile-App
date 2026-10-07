import '../../../../core/network/endpoints.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/infrastructure/repositories/auth_repository_impl.dart';
import '../../domain/entities/person.dart';
import '../../domain/repositories/family_repository.dart';
import '../data_sources/remote/persons_api.dart';
import 'profile_mappers.dart';

/// [FamilyRepository] over [PersonsApi] + [CachedFetcher]. Every throw is a
/// `Failure`; every mutation invalidates the response cache.
class FamilyRepositoryImpl implements FamilyRepository {
  const FamilyRepositoryImpl({
    required PersonsApi api,
    required CachedFetcher fetcher,
  }) : _api = api,
       _fetcher = fetcher;

  final PersonsApi _api;
  final CachedFetcher _fetcher;

  @override
  Stream<CachedResult<List<Person>>> persons({bool forceRefresh = false}) =>
      _fetcher
          .fetch(
            _api.persons(),
            ProfileMappers.persons,
            forceRefresh: forceRefresh,
          )
          .handleError(_rethrowAsFailure);

  @override
  Future<Person> create(PersonDraft draft) async {
    final person = await _run(
      () async => ProfileMappers.personFromBody(await _api.create(draft)),
    );
    await _invalidate();
    return person;
  }

  @override
  Future<Person> update(
    String id,
    PersonDraft draft, {
    required int ifMatch,
  }) async {
    final person = await _run(
      () async => ProfileMappers.personFromBody(
        await _api.update(id, draft, ifMatch: ifMatch),
      ),
    );
    await _invalidate();
    return person;
  }

  @override
  Future<void> delete(String id) async {
    await _run(() => _api.delete(id));
    await _invalidate();
  }

  @override
  Future<OtpChallenge> startRelease({
    required String personId,
    required String phoneE164,
    required String idempotencyKey,
  }) => _run(
    () async => AuthMappers.challenge(
      await _api.startRelease(
        personId: personId,
        phoneE164: phoneE164,
        idempotencyKey: idempotencyKey,
      ),
    ),
  );

  @override
  Future<ReleaseResult> verifyRelease({
    required String personId,
    required String challengeId,
    required String code,
  }) async {
    final result = await _run(
      () async => ProfileMappers.releaseResult(
        await _api.verifyRelease(
          personId: personId,
          challengeId: challengeId,
          code: code,
        ),
      ),
    );
    // The person and their appointment history leave this account (§5.8).
    await _fetcher.invalidate(pathPrefix: Endpoints.persons);
    return result;
  }

  Future<void> _invalidate() =>
      _fetcher.invalidate(pathPrefix: Endpoints.persons);

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
