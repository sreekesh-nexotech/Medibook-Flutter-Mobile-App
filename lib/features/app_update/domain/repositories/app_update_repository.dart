import '../entities/app_update_offer.dart';

/// The store's in-app update flows (Google Play on Android).
///
/// Nothing here throws. An update check is a background courtesy: when the
/// store cannot be asked the answer is [AppUpdateOffer.none], and a flow that
/// breaks ends as [AppUpdateOutcome.failed].
abstract interface class AppUpdateRepository {
  /// Asks the store what it has for this install. Must be called before
  /// either flow is started.
  Future<AppUpdateOffer> check();

  /// The installed version name (`1.4.0`), or null when it cannot be read.
  Future<String?> installedVersion();

  /// Runs the store's full-screen flow. On [AppUpdateOutcome.accepted] the
  /// store installs the update and restarts the app itself.
  Future<AppUpdateOutcome> startImmediate();

  /// Asks for consent, then downloads in the background. Completes with
  /// [AppUpdateOutcome.accepted] once the download has **finished**.
  Future<AppUpdateOutcome> startFlexible();

  /// Installs a downloaded flexible update. The app restarts.
  void completeFlexible();
}
