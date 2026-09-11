import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../network/api_client.dart';

/// Fixed keys inside the non-cache boxes.
///
/// Coding Standards §3.1 puts box names in `boxes.dart`; this is the companion
/// for the *keys within* those boxes, so a typo cannot silently create a second
/// setting that nothing reads.
abstract final class HiveKeys {
  HiveKeys._();

  // ---- `auth` box (non-secret session metadata only) ----

  /// Id of the signed-in user. Tokens live in `SecureStore`, never here.
  static const String userId = 'user_id';
  static const String userDisplayName = 'user_display_name';
  static const String userPhone = 'user_phone';

  /// Epoch millis of the last successful sign-in.
  static const String lastLoginAt = 'last_login_at';

  /// Failed sign-in attempt counter and lockout expiry (CM-05). Persisted so
  /// force-quitting the app does not reset a lockout.
  static const String failedLoginAttempts = 'failed_login_attempts';
  static const String lockedUntil = 'locked_until';

  /// Whether onboarding has been completed on this device.
  static const String onboardingComplete = 'onboarding_complete';

  // ---- `settings` box ----

  static const String locale = 'locale';
  static const String themeMode = 'theme_mode';
  static const String pushEnabled = 'push_enabled';
  static const String emailRemindersEnabled = 'email_reminders_enabled';
  static const String smsRemindersEnabled = 'sms_reminders_enabled';

  /// Last chosen city/area (CM-10 location-first discovery).
  static const String selectedCity = 'selected_city';
  static const String selectedArea = 'selected_area';

  /// Set once the user has accepted the current terms version.
  static const String acceptedTermsVersion = 'accepted_terms_version';

  // ---- `cache_meta` box ----

  /// Epoch millis of the last LRU/size sweep.
  static const String lastEvictionSweepAt = 'last_eviction_sweep_at';

  /// Consecutive Hive write failures (CacheConfig.writeFailureLimit).
  static const String consecutiveWriteFailures = 'consecutive_write_failures';

  /// Metadata sub-key for one cache entry.
  static String metaFor(String cacheKey) => 'meta:$cacheKey';

  /// Corruption-strike sub-key for one cache entry (Scenario 9).
  static String corruptionFor(String cacheKey) => 'corrupt:$cacheKey';
}

/// Builds the L2 cache key for a request.
///
/// `docs-flutter/HIVE implementation.md` fixes the strategy:
///
/// ```text
/// cacheKey = SHA256(
///   endpoint + HTTP_method + sorted_query_params +
///   request_body_hash + auth_token_hash
/// )
/// ```
///
/// Two properties matter and both are load-bearing:
/// * **Order-independence.** Query parameters are sorted before hashing, so
///   `?city=Kochi&page=1` and `?page=1&city=Kochi` share one entry instead of
///   thrashing two.
/// * **Tenant isolation.** The auth token is hashed into the key, so one
///   patient's cached records can never be served to another account on a
///   shared device. The token is *hashed*, never stored — the key is not
///   reversible into a credential.
///
/// The hash function is injectable ([hash]) so tests can pin a deterministic
/// digest. The default is real SHA-256 from `package:crypto`, which is a
/// direct dependency of this project precisely so this builder does not have
/// to fall back to anything weaker.
class CacheKeyBuilder {
  const CacheKeyBuilder({this.hash = sha256Hex, this.prefix = 'v1'});

  /// The digest function. Defaults to [sha256Hex] (real SHA-256).
  final String Function(String input) hash;

  /// Bumped when the cached payload *shape* changes, so a new app version
  /// cannot decode an old version's entries. Cheaper and safer than a
  /// migration for cache data.
  final String prefix;

  /// Key for an [ApiRequest].
  ///
  /// Pass the raw [authToken]; it is hashed here and never retained.
  String forRequest(ApiRequest request, {String? authToken}) => build(
    endpoint: request.path,
    method: request.method.value,
    query: request.normalisedQuery,
    body: request.body,
    authToken: authToken,
  );

  /// Key for the five components of the documented strategy.
  String build({
    required String endpoint,
    String method = 'GET',
    Map<String, String> query = const <String, String>{},
    Object? body,
    String? authToken,
  }) {
    final sortedQuery = sortQuery(query);
    final bodyHash = body == null ? '' : hash(_canonicalJson(body));
    final tokenHash = authToken == null || authToken.isEmpty
        ? 'anon'
        : hash(authToken);

    final material = [
      endpoint,
      method.toUpperCase(),
      sortedQuery,
      bodyHash,
      tokenHash,
    ].join('|');

    return '$prefix:${hash(material)}';
  }

  /// Key for one page of a paginated endpoint. The cache spec (Scenario 10)
  /// requires each page to be cached independently.
  String forPage(
    String endpoint, {
    required int page,
    Map<String, String> query = const <String, String>{},
    String? authToken,
  }) => build(
    endpoint: endpoint,
    query: {...query, 'page': '$page'},
    authToken: authToken,
  );

  /// Query parameters flattened in a canonical, order-independent form.
  static String sortQuery(Map<String, String> query) {
    if (query.isEmpty) return '';
    final keys = query.keys.toList()..sort();
    return keys.map((k) => '$k=${query[k]}').join('&');
  }

  /// Stable JSON for hashing: map keys sorted at every level, so two
  /// semantically identical bodies hash the same regardless of insertion order.
  static String _canonicalJson(Object? value) {
    Object? canonical(Object? node) {
      if (node is Map) {
        final keys = node.keys.map((k) => k.toString()).toList()..sort();
        return {for (final k in keys) k: canonical(node[k])};
      }
      if (node is Iterable) return node.map(canonical).toList();
      return node;
    }

    return jsonEncode(canonical(value));
  }

  /// SHA-256 of [input] as lowercase hex — the documented default.
  static String sha256Hex(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  /// A non-cryptographic 64-bit FNV-1a digest.
  ///
  /// **Not** the default and not a security primitive: it exists only as an
  /// explicit escape hatch for a build that cannot link `package:crypto`
  /// (e.g. a size-constrained web target). Cache keys are collision-sensitive
  /// — a collision serves one patient's data for another's request — so this
  /// must never be selected on a build that handles real accounts. Documented
  /// here rather than left implicit.
  static String fnv1a64Hex(String input) {
    const offsetBasis = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    var hash = offsetBasis;
    for (final byte in utf8.encode(input)) {
      hash ^= byte;
      hash = (hash * prime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}

/// The process-wide key builder. Injectable for tests; there is no reason for
/// production code to construct its own.
const CacheKeyBuilder cacheKeys = CacheKeyBuilder();
