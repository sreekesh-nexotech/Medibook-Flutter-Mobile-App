import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../../common/pagination/domain/entities/paged.dart';
import '../../domain/entities/insurance_policy.dart';
import '../../domain/repositories/insurance_repository.dart';
import '../data_sources/remote/insurance_api.dart';
import 'insurance_mappers.dart';

/// [InsuranceRepository] over [InsuranceApi] + [CachedFetcher].
///
/// Reads decode through [InsuranceMappers] (the validation pipeline);
/// mutations run, then invalidate the response cache; every throw is a
/// `Failure`.
class InsuranceRepositoryImpl implements InsuranceRepository {
  const InsuranceRepositoryImpl({
    required InsuranceApi api,
    required CachedFetcher fetcher,
  }) : _api = api,
       _fetcher = fetcher;

  final InsuranceApi _api;
  final CachedFetcher _fetcher;

  /// One page holds a family's policies; the cap is 100 (§1.6).
  static const int _pageSize = 100;

  @override
  Stream<Snapshot<List<InsurancePolicy>>> watchPolicies({
    String? personId,
    bool forceRefresh = false,
  }) async* {
    try {
      await for (final result in _fetcher.fetch<Page<InsurancePolicy>>(
        _api.listRequest(personId: personId, pageSize: _pageSize),
        (json) => Page.parse(json, InsuranceMappers.fromJson),
        forceRefresh: forceRefresh,
      )) {
        yield Snapshot<List<InsurancePolicy>>(
          value: result.value.results,
          cachedAt: result.cachedAt,
          fromCache: result.source != CacheSource.network,
          isStale: result.isStale,
          revalidating: result.revalidating,
        );
      }
    } catch (error, stackTrace) {
      throw NetworkExceptions.toFailure(error, stackTrace);
    }
  }

  @override
  Future<InsurancePolicy> policy(String id, {bool forceRefresh = false}) =>
      _run(
        () => _fetcher.get<InsurancePolicy>(
          _api.detailRequest(id),
          (json) => InsuranceMappers.fromJson(_asMap(json)),
          forceRefresh: forceRefresh,
        ),
      );

  @override
  Future<InsurancePolicy> create(PolicyDraft draft) => _mutate(() async {
    final json = await _api.create(InsuranceMappers.draftToJson(draft));
    return InsuranceMappers.fromJson(json);
  });

  @override
  Future<InsurancePolicy> update(
    String id,
    PolicyPatch patch, {
    required int version,
  }) => _mutate(() async {
    final json = await _api.patch(
      id,
      InsuranceMappers.patchToJson(patch),
      version: version,
    );
    return InsuranceMappers.fromJson(json);
  });

  @override
  Future<void> delete(String id) => _mutate(() => _api.delete(id));

  @override
  Future<InsurancePolicy> attachDocument(String id, String fileId) =>
      _mutate(() async {
        final json = await _api.attachDocument(id, fileId);
        return InsuranceMappers.fromJson(json);
      });

  @override
  Future<void> detachDocument(String id, String fileId) =>
      _mutate(() => _api.detachDocument(id, fileId));

  static Map<String, Object?> _asMap(Object? json) {
    if (json is Map) return json.cast<String, Object?>();
    throw ResponseFormatException(
      message: 'expected a policy object, got ${json.runtimeType}',
    );
  }

  Future<T> _run<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (error, stackTrace) {
      throw NetworkExceptions.toFailure(error, stackTrace);
    }
  }

  Future<T> _mutate<T>(Future<T> Function() request) async {
    final result = await _run(request);
    await _fetcher.invalidate(pathPrefix: '/patient/me/insurance-policies');
    return result;
  }
}
