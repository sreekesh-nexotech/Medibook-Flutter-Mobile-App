/// Hive box-name registry.
///
/// Coding Standards §3.1: box names are clear and feature-based — never
/// `box1`/`myBox` — and they live in exactly one place so a rename cannot leave
/// an orphaned box on a user's device. `app/bootstrap/hive_init.dart` opens
/// every box named here and nothing else.
///
/// Hive itself is **not** a dependency of this presentation-layer build (see
/// `pubspec.yaml`); this registry, `HiveKeys` and `hive_init.dart` are the
/// contract the data layer will implement against, written now so box naming,
/// typeIds and the cache-key strategy are settled before any code writes to
/// disk.
abstract final class HiveBoxes {
  HiveBoxes._();

  // ---- Session / identity ----

  /// Non-secret session metadata: user id, display name, last-used locale.
  ///
  /// **Never** tokens, passwords or PHI — those go to
  /// `core/storage/secure_store.dart` (Coding Standards §9).
  static const String auth = 'auth';

  /// User preferences: theme, notification toggles, chosen city/area.
  static const String settings = 'settings';

  // ---- Feature caches (all L2, all evictable) ----

  /// The generic HTTP response cache — one entry per cache key, holding a
  /// `CacheEntry` (see `docs-flutter/HIVE implementation.md`).
  static const String httpCache = 'http_cache';

  /// Per-entry metadata (access count, last access, size) kept beside
  /// [httpCache] so the LRU monitor can sort without decoding payloads.
  static const String cacheMeta = 'cache_meta';

  static const String doctorsCache = 'doctors_cache';
  static const String hospitalsCache = 'hospitals_cache';
  static const String appointmentsCache = 'appointments_cache';
  static const String documentsCache = 'documents_cache';
  static const String notificationsCache = 'notifications_cache';
  static const String insuranceCache = 'insurance_cache';
  static const String contentCache = 'content_cache';

  /// Writes made offline, replayed when connectivity returns.
  static const String outbox = 'outbox';

  /// Every box the app opens, in open order.
  static const List<String> all = [
    auth,
    settings,
    httpCache,
    cacheMeta,
    doctorsCache,
    hospitalsCache,
    appointmentsCache,
    documentsCache,
    notificationsCache,
    insuranceCache,
    contentCache,
    outbox,
  ];

  /// Boxes that hold only cached server data and are therefore safe to drop
  /// wholesale — on sign-out, on a "clear cache" action, or after a corruption
  /// event (HIVE spec, Scenario 9).
  static const List<String> evictable = [
    httpCache,
    cacheMeta,
    doctorsCache,
    hospitalsCache,
    appointmentsCache,
    documentsCache,
    notificationsCache,
    insuranceCache,
    contentCache,
  ];

  /// Boxes cleared when the user signs out (CM-53: "logout clears session").
  ///
  /// [settings] deliberately survives, so a returning user keeps their theme
  /// and city; everything patient-specific does not.
  static const List<String> clearedOnLogout = [
    auth,
    outbox,
    ...evictable,
  ];
}

/// Hive `typeId` registry.
///
/// Coding Standards §3.2: every cached model declares `@HiveType` with a
/// **unique** typeId. Reusing an id silently decodes one model's bytes as
/// another, so the numbers are allocated here, centrally, and are never
/// recycled — a retired model's id stays retired.
abstract final class HiveTypeIds {
  HiveTypeIds._();

  static const int cacheEntry = 1;
  static const int cacheMetadata = 2;
  static const int user = 3;
  static const int doctor = 4;
  static const int hospital = 5;
  static const int department = 6;
  static const int appointment = 7;
  static const int appointmentStatus = 8;
  static const int patient = 9;
  static const int slot = 10;
  static const int slotStatus = 11;
  static const int paymentRecord = 12;
  static const int paymentMethod = 13;
  static const int paymentStatus = 14;
  static const int feeBreakdown = 15;
  static const int medicalDocument = 16;
  static const int documentType = 17;
  static const int insurancePolicy = 18;
  static const int notification = 19;
  static const int notificationKind = 20;
  static const int queueStatus = 21;
  static const int address = 22;
  static const int emergencyContact = 23;
  static const int outboxOperation = 24;

  /// Next free id. Bump this when allocating; never reuse a number above.
  static const int nextAvailable = 25;
}

/// Cache sizing and freshness limits, verbatim from
/// `docs-flutter/HIVE implementation.md` ("CacheConfig").
abstract final class CacheConfig {
  CacheConfig._();

  /// L1 (memory) ceiling: 50MB.
  static const int memoryCacheMaxBytes = 50 * 1024 * 1024;

  /// L1 entry ceiling.
  static const int memoryCacheMaxEntries = 500;

  /// L2 (Hive) ceiling: 200MB.
  static const int hiveCacheMaxBytes = 200 * 1024 * 1024;

  /// The monitor compacts and evicts once Hive passes 90% of its ceiling.
  static const double hiveEvictionThreshold = 0.90;

  /// Fraction of entries dropped per eviction sweep (oldest access first).
  static const double hiveEvictionFraction = 0.20;

  /// How often the size monitor runs.
  static const Duration monitorInterval = Duration(minutes: 5);

  /// Newer than this → serve from cache and revalidate in the background.
  static const Duration validCacheThreshold = Duration(hours: 12);

  /// Older than this → serve from cache but show the amber "Data from …" bar.
  static const Duration staleCacheThreshold = Duration(hours: 24);

  /// Per-request network budget.
  static const Duration apiTimeout = Duration(seconds: 10);

  static const int maxRetryAttempts = 4;
  static const Duration retryBaseDelay = Duration(seconds: 2);

  /// How long a key stays flagged after a corrupt read (Scenario 9, step 4).
  static const Duration corruptionQuarantine = Duration(minutes: 5);

  /// Corrupt reads of one key within an hour before it stops being cached.
  static const int corruptionStrikeLimit = 3;

  /// Consecutive Hive write failures before Hive is disabled for the session.
  static const int writeFailureLimit = 10;
}
