import '../../../../core/network/network_exceptions.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../domain/entities/ambulance_provider.dart';
import '../../domain/entities/app_config.dart';
import '../../domain/entities/faq.dart';
import '../../domain/entities/legal_document.dart';
import '../../domain/repositories/support_content_repository.dart';
import '../data_sources/remote/support_content_api.dart';
import 'support_mappers.dart';

/// [SupportContentRepository] over the three-layer cache.
///
/// Every read goes Memory → Hive → Network through [CachedFetcher]; the
/// mapper is the decode callback, so an invalid body is never cached
/// (HIVE Scenario 10). Errors surface as `Failure`s only.
class SupportContentRepositoryImpl implements SupportContentRepository {
  const SupportContentRepositoryImpl({
    required SupportContentApi api,
    required CachedFetcher fetcher,
  }) : _api = api,
       _fetcher = fetcher;

  final SupportContentApi _api;
  final CachedFetcher _fetcher;

  @override
  Stream<CachedResult<AppConfig>> appConfig({bool forceRefresh = false}) =>
      _guard(
        _fetcher.fetch(
          _api.appConfig(),
          SupportMappers.appConfig,
          forceRefresh: forceRefresh,
        ),
      );

  @override
  Stream<CachedResult<LegalDocument>> legalDocument(
    String slug, {
    bool forceRefresh = false,
  }) => _guard(
    _fetcher.fetch(
      _api.legalDocument(slug),
      SupportMappers.legalDocument,
      forceRefresh: forceRefresh,
    ),
  );

  @override
  Stream<CachedResult<List<FaqCategory>>> faqs({bool forceRefresh = false}) =>
      _guard(
        _fetcher.fetch(
          _api.faqs(),
          SupportMappers.faqs,
          forceRefresh: forceRefresh,
        ),
      );

  @override
  Stream<CachedResult<List<AmbulanceProvider>>> ambulanceProviders(
    AmbulanceFilter filter, {
    bool forceRefresh = false,
  }) => _guard(
    _fetcher.fetch(
      _api.ambulanceProviders(filter),
      SupportMappers.ambulanceProviders,
      forceRefresh: forceRefresh,
    ),
  );

  /// Re-emits [source], converting any error into a `Failure` — nothing above
  /// the repository sees a `NetworkException`.
  static Stream<CachedResult<T>> _guard<T>(Stream<CachedResult<T>> source) =>
      source.handleError(
        (Object error, StackTrace stackTrace) =>
            throw NetworkExceptions.toFailure(error, stackTrace),
      );
}
