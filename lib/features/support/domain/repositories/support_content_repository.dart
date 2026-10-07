import '../../../../core/storage/cache/cached_result.dart';
import '../entities/ambulance_provider.dart';
import '../entities/app_config.dart';
import '../entities/faq.dart';
import '../entities/legal_document.dart';

/// Public, cacheable content (§3 and §14): app config, legal documents, the
/// FAQ and the ambulance directory.
///
/// Every read returns the fetcher's cached-first-then-network stream so a
/// screen can render the HIVE affordances. Every throw is a `Failure`.
abstract interface class SupportContentRepository {
  /// `GET /shared/app-config`.
  Stream<CachedResult<AppConfig>> appConfig({bool forceRefresh = false});

  /// `GET /patient/legal/{slug}`. A `404` surfaces as `NotFoundFailure`.
  Stream<CachedResult<LegalDocument>> legalDocument(
    String slug, {
    bool forceRefresh = false,
  });

  /// `GET /patient/faqs` — categories in server order.
  Stream<CachedResult<List<FaqCategory>>> faqs({bool forceRefresh = false});

  /// `GET /patient/ambulance/providers` with the given filters.
  Stream<CachedResult<List<AmbulanceProvider>>> ambulanceProviders(
    AmbulanceFilter filter, {
    bool forceRefresh = false,
  });
}
