import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The device-side data source: Google Play's in-app update API.
///
/// "Local" in the four-layer sense — it talks to the Play Store app on the
/// device, not to the Medibook backend — and it is the only file in the app
/// that imports `in_app_update` or `package_info_plus`. Every call may throw a
/// `PlatformException`; the repository maps those.
abstract interface class PlayUpdateDataSource {
  /// False where the Play API does not exist (iOS, web, desktop).
  bool get isSupported;

  Future<AppUpdateInfo> checkForUpdate();

  Future<AppUpdateResult> performImmediateUpdate();

  /// Completes once the download has finished.
  Future<AppUpdateResult> startFlexibleUpdate();

  /// Never completes on success — Play restarts the app instead of answering
  /// — so callers must not await it. It only ever completes with an error.
  Future<void> completeFlexibleUpdate();

  /// The installed version name, without the build number.
  Future<String> installedVersion();
}

class PlatformPlayUpdateDataSource implements PlayUpdateDataSource {
  const PlatformPlayUpdateDataSource();

  @override
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<AppUpdateInfo> checkForUpdate() => InAppUpdate.checkForUpdate();

  @override
  Future<AppUpdateResult> performImmediateUpdate() =>
      InAppUpdate.performImmediateUpdate();

  @override
  Future<AppUpdateResult> startFlexibleUpdate() =>
      InAppUpdate.startFlexibleUpdate();

  @override
  Future<void> completeFlexibleUpdate() => InAppUpdate.completeFlexibleUpdate();

  @override
  Future<String> installedVersion() async =>
      (await PackageInfo.fromPlatform()).version;
}
