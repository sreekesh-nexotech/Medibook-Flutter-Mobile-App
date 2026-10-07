import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:medibook/features/app_update/domain/entities/app_update_offer.dart';
import 'package:medibook/features/app_update/infrastructure/data_sources/local/play_update_ds.dart';
import 'package:medibook/features/app_update/infrastructure/repositories/app_update_repository_impl.dart';

/// The Play → domain mapping, and the promise that nothing here throws.
void main() {
  late FakePlayUpdateDataSource dataSource;
  late AppUpdateRepositoryImpl repository;

  setUp(() {
    dataSource = FakePlayUpdateDataSource();
    repository = AppUpdateRepositoryImpl(dataSource: dataSource);
  });

  AppUpdateInfo info({
    UpdateAvailability availability = UpdateAvailability.updateAvailable,
    InstallStatus status = InstallStatus.unknown,
  }) => AppUpdateInfo(
    updateAvailability: availability,
    immediateUpdateAllowed: true,
    immediateAllowedPreconditions: const [],
    flexibleUpdateAllowed: true,
    flexibleAllowedPreconditions: const [],
    availableVersionCode: 12,
    installStatus: status,
    packageName: 'com.navoracloudsoft.medibook',
    clientVersionStalenessDays: null,
    updatePriority: 0,
  );

  test('an unsupported platform is never asked', () async {
    dataSource.isSupported = false;

    expect(await repository.check(), AppUpdateOffer.none);
    expect(dataSource.checks, 0);
  });

  test('maps an available update', () async {
    dataSource.info = info();

    expect(
      await repository.check(),
      const AppUpdateOffer(
        isAvailable: true,
        immediateAllowed: true,
        flexibleAllowed: true,
      ),
    );
  });

  test('maps a downloaded update that is still in progress', () async {
    dataSource.info = info(
      availability: UpdateAvailability.developerTriggeredUpdateInProgress,
      status: InstallStatus.downloaded,
    );

    final offer = await repository.check();

    expect(offer.isAvailable, isTrue);
    expect(offer.isDownloaded, isTrue);
  });

  test('no update available', () async {
    dataSource.info = info(availability: UpdateAvailability.updateNotAvailable);

    expect((await repository.check()).isAvailable, isFalse);
  });

  test('a store that cannot be asked reads as no update', () async {
    dataSource.error = PlatformException(code: 'TASK_FAILURE');

    expect(await repository.check(), AppUpdateOffer.none);
  });

  test('maps the flow results, and a thrown error to failed', () async {
    dataSource.result = AppUpdateResult.success;
    expect(await repository.startImmediate(), AppUpdateOutcome.accepted);

    dataSource.result = AppUpdateResult.userDeniedUpdate;
    expect(await repository.startFlexible(), AppUpdateOutcome.declined);

    dataSource.result = AppUpdateResult.inAppUpdateFailed;
    expect(await repository.startImmediate(), AppUpdateOutcome.failed);

    dataSource.error = PlatformException(code: 'REQUIRE_CHECK_FOR_UPDATE');
    expect(await repository.startImmediate(), AppUpdateOutcome.failed);
    expect(await repository.installedVersion(), isNull);
  });
}

class FakePlayUpdateDataSource implements PlayUpdateDataSource {
  @override
  bool isSupported = true;

  AppUpdateInfo? info;
  AppUpdateResult result = AppUpdateResult.success;
  Object? error;
  int checks = 0;

  @override
  Future<AppUpdateInfo> checkForUpdate() async {
    checks++;
    if (error != null) throw error!;
    return info!;
  }

  @override
  Future<AppUpdateResult> performImmediateUpdate() => _flow();

  @override
  Future<AppUpdateResult> startFlexibleUpdate() => _flow();

  Future<AppUpdateResult> _flow() async {
    if (error != null) throw error!;
    return result;
  }

  @override
  Future<void> completeFlexibleUpdate() async {}

  @override
  Future<String> installedVersion() async {
    if (error != null) throw error!;
    return '1.0.0';
  }
}
