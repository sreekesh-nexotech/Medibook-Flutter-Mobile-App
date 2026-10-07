import 'dart:async';

import 'package:in_app_update/in_app_update.dart';

import '../../../../app/monitoring/crash_reporting.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/app_update_offer.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../data_sources/local/play_update_ds.dart';

class AppUpdateRepositoryImpl implements AppUpdateRepository {
  const AppUpdateRepositoryImpl({required PlayUpdateDataSource dataSource})
    : _dataSource = dataSource;

  final PlayUpdateDataSource _dataSource;

  @override
  Future<AppUpdateOffer> check() async {
    if (!_dataSource.isSupported) return AppUpdateOffer.none;
    try {
      final info = await _dataSource.checkForUpdate();
      return AppUpdateOffer(
        isAvailable:
            info.updateAvailability == UpdateAvailability.updateAvailable ||
            info.updateAvailability ==
                UpdateAvailability.developerTriggeredUpdateInProgress,
        isDownloaded: info.installStatus == InstallStatus.downloaded,
        immediateAllowed: info.immediateUpdateAllowed,
        flexibleAllowed: info.flexibleUpdateAllowed,
      );
    } catch (error) {
      // Expected on any install that did not come from Google Play (debug
      // and sideloaded builds, emulators without Play Services) — not a
      // fault, so it is logged and not reported.
      AppLogger.debug('Update check unavailable: $error', name: 'app_update');
      return AppUpdateOffer.none;
    }
  }

  @override
  Future<String?> installedVersion() async {
    try {
      return await _dataSource.installedVersion();
    } catch (error, stackTrace) {
      CrashReporting.recordError(
        error,
        stackTrace,
        reason: 'app_update:installed_version',
      );
      return null;
    }
  }

  @override
  Future<AppUpdateOutcome> startImmediate() =>
      _run(_dataSource.performImmediateUpdate, 'app_update:immediate');

  @override
  Future<AppUpdateOutcome> startFlexible() =>
      _run(_dataSource.startFlexibleUpdate, 'app_update:flexible');

  @override
  void completeFlexible() {
    // Not awaited: the call only comes back when the install could not start.
    unawaited(
      _dataSource.completeFlexibleUpdate().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        CrashReporting.recordError(
          error,
          stackTrace,
          reason: 'app_update:complete',
        );
      }),
    );
  }

  Future<AppUpdateOutcome> _run(
    Future<AppUpdateResult> Function() flow,
    String reason,
  ) async {
    try {
      return switch (await flow()) {
        AppUpdateResult.success => AppUpdateOutcome.accepted,
        AppUpdateResult.userDeniedUpdate => AppUpdateOutcome.declined,
        AppUpdateResult.inAppUpdateFailed => AppUpdateOutcome.failed,
      };
    } catch (error, stackTrace) {
      CrashReporting.recordError(error, stackTrace, reason: reason);
      return AppUpdateOutcome.failed;
    }
  }
}
