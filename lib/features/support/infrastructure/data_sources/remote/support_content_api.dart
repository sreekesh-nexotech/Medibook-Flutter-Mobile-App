import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';
import '../../../domain/entities/ambulance_provider.dart';

/// The public content endpoints (§3, §14), as *request descriptions*.
///
/// These are all cacheable GETs, and the cache layer (`CachedFetcher`) is the
/// one that performs them — so this data source's job is to know **which path
/// and which query**, and nothing else. No caching decisions, no mapping, no
/// `try`/`catch`: the repository drives the fetcher with these requests and
/// maps the decoded JSON.
abstract interface class SupportContentApi {
  /// `GET /shared/app-config` — public.
  ApiRequest appConfig();

  /// `GET /patient/legal/{slug}` — public.
  ApiRequest legalDocument(String slug);

  /// `GET /patient/faqs` — public, no query parameters accepted.
  ApiRequest faqs();

  /// `GET /patient/ambulance/providers` — public; only `city`, `area` and
  /// `hospital_id` are sent, and only when set (§1.7).
  ApiRequest ambulanceProviders(AmbulanceFilter filter);
}

class HttpSupportContentApi implements SupportContentApi {
  const HttpSupportContentApi();

  @override
  ApiRequest appConfig() =>
      const ApiRequest(path: Endpoints.appConfig, requiresAuth: false);

  @override
  ApiRequest legalDocument(String slug) =>
      ApiRequest(path: Endpoints.legalDocument(slug), requiresAuth: false);

  @override
  ApiRequest faqs() =>
      const ApiRequest(path: Endpoints.faqs, requiresAuth: false);

  @override
  ApiRequest ambulanceProviders(AmbulanceFilter filter) => ApiRequest(
    path: Endpoints.ambulanceProviders,
    requiresAuth: false,
    query: {
      'city': _nonEmpty(filter.city),
      'area': _nonEmpty(filter.area),
      'hospital_id': _nonEmpty(filter.hospitalId),
    },
  );

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
