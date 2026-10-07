/// `GET /shared/app-config` (`FLUTTER_API_INTEGRATION.md` §3.1) — read once
/// at launch, before sign-in.
///
/// Plain immutable entity: no JSON, no Flutter. The infrastructure layer maps
/// the wire shape onto it.
class AppConfig {
  const AppConfig({
    this.minVersionAndroid,
    this.minVersionIos,
    this.featureFlags = const <String, bool>{},
    this.otpLength = 4,
    this.supportContacts = const SupportContacts(),
    this.legalVersions = const <String, int>{},
    this.deletionCoolingOffDays,
    this.uploadMaxBytes,
  });

  /// Empty config — what the app assumes before the first successful read.
  static const AppConfig fallback = AppConfig();

  /// The account-deletion cooling-off period when the server does not send
  /// one: the platform's default (`dsr_cooling_off_days`, D-24).
  static const int defaultDeletionCoolingOffDays = 30;

  /// The largest upload when the server does not say: the platform's
  /// default (`upload_max_bytes`, 10 MB, Q117).
  static const int defaultUploadMaxBytes = 10 * 1024 * 1024;

  /// Each may be null when the server has not set one.
  final String? minVersionAndroid;
  final String? minVersionIos;

  /// `feature_flags_public`: key → bool.
  final Map<String, bool> featureFlags;

  /// Build the OTP boxes from this.
  final int otpLength;

  final SupportContacts supportContacts;

  /// `legal_versions`: slug → current published version. Compare with what
  /// the user accepted (§5.9) to decide whether to ask for re-consent.
  final Map<String, int> legalVersions;

  /// `dsr_cooling_off_days`: how long a deleted account can still be
  /// reactivated. A platform setting staff can change; null while the server
  /// does not publish it (BACKEND_BLOCKERS BB-28).
  final int? deletionCoolingOffDays;

  /// `upload_max_bytes`: the largest file the server accepts, in bytes. A
  /// platform setting staff can change; null while the server does not
  /// publish it (BACKEND_BLOCKERS BB-38).
  final int? uploadMaxBytes;

  bool flag(String name) => featureFlags[name] ?? false;

  /// The current version of a legal document, or null when unpublished.
  int? legalVersion(String slug) => legalVersions[slug];

  @override
  bool operator ==(Object other) =>
      other is AppConfig &&
      other.minVersionAndroid == minVersionAndroid &&
      other.minVersionIos == minVersionIos &&
      other.otpLength == otpLength &&
      other.supportContacts == supportContacts &&
      other.deletionCoolingOffDays == deletionCoolingOffDays &&
      other.uploadMaxBytes == uploadMaxBytes &&
      _mapEquals(other.featureFlags, featureFlags) &&
      _mapEquals(other.legalVersions, legalVersions);

  @override
  int get hashCode => Object.hash(
    minVersionAndroid,
    minVersionIos,
    otpLength,
    supportContacts,
    deletionCoolingOffDays,
    uploadMaxBytes,
    Object.hashAll(featureFlags.entries.map((e) => '${e.key}=${e.value}')),
    Object.hashAll(legalVersions.entries.map((e) => '${e.key}=${e.value}')),
  );

  static bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}

/// `support_contacts` — `{}` when not configured.
class SupportContacts {
  const SupportContacts({this.phoneE164, this.email});

  final String? phoneE164;

  /// Not in the documented shape today; kept nullable so a later addition
  /// lands without a model change.
  final String? email;

  bool get isEmpty => phoneE164 == null && email == null;

  @override
  bool operator ==(Object other) =>
      other is SupportContacts &&
      other.phoneE164 == phoneE164 &&
      other.email == email;

  @override
  int get hashCode => Object.hash(phoneE164, email);
}
