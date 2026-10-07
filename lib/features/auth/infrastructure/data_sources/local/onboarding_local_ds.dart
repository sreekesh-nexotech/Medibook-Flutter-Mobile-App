import '../../../../../app/bootstrap/hive_init.dart';
import '../../../../../core/storage/hive/boxes.dart';
import '../../../../../core/storage/hive/keys.dart';
import '../../../domain/repositories/onboarding_store.dart';

/// Reads and writes through the process-wide [LocalStore], like the auth
/// feature's other local data source. Reads are synchronous so the router's
/// redirect can consult the flag without a frame of splash.
class OnboardingLocalDataSourceImpl implements OnboardingStore {
  const OnboardingLocalDataSourceImpl();

  LocalStore get _local => HiveInit.store;

  @override
  bool readComplete() =>
      _local.read(HiveBoxes.settings, HiveKeys.onboardingComplete) == true;

  @override
  bool readOffersOptIn() =>
      _local.read(HiveBoxes.settings, HiveKeys.offersOptIn) == true;

  @override
  String? readAcceptedTermsVersion() {
    final value = _local.read(
      HiveBoxes.settings,
      HiveKeys.acceptedTermsVersion,
    );
    return value is String && value.isNotEmpty ? value : null;
  }

  @override
  Future<void> writeComplete({
    required bool offersOptIn,
    required String acceptedTermsVersion,
  }) async {
    await _local.write(HiveBoxes.settings, HiveKeys.offersOptIn, offersOptIn);
    await _local.write(
      HiveBoxes.settings,
      HiveKeys.acceptedTermsVersion,
      acceptedTermsVersion,
    );
    // Written last: if anything above fails the intro simply shows again,
    // which is the safe direction for a consent record.
    await _local.write(HiveBoxes.settings, HiveKeys.onboardingComplete, true);
  }
}
