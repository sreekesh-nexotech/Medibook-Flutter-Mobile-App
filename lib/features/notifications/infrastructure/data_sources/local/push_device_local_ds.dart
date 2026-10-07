import '../../../../../app/bootstrap/hive_init.dart';
import '../../../../../core/storage/hive/boxes.dart';
import '../../../../../core/utils/logger.dart';

/// Remembers which `Device.id` this install registered (§12.6), so logout
/// can `DELETE /patient/me/devices/{id}` for exactly this device.
///
/// The only Hive touch in the notifications feature. Lives in the `auth`
/// box (non-secret session metadata) so `HiveBoxes.clearedOnLogout` wipes
/// it with the rest of the session.
abstract interface class PushDeviceLocalDataSource {
  Future<String?> readDeviceId();

  Future<void> writeDeviceId(String id);

  Future<void> clear();
}

class PushDeviceLocalDataSourceImpl implements PushDeviceLocalDataSource {
  const PushDeviceLocalDataSourceImpl({LocalStore? store}) : _store = store;

  final LocalStore? _store;

  /// Key inside [HiveBoxes.auth]. Declared here rather than in
  /// `core/storage/hive/keys.dart` because core is frozen this round.
  static const String deviceIdKey = 'push_device_id';

  LocalStore get _local => _store ?? HiveInit.store;

  @override
  Future<String?> readDeviceId() async {
    try {
      final value = _local.read(HiveBoxes.auth, deviceIdKey);
      return value is String && value.isNotEmpty ? value : null;
    } catch (error) {
      AppLogger.warning(
        'Could not read the push device id',
        name: 'notifications',
        error: error,
      );
      return null;
    }
  }

  @override
  Future<void> writeDeviceId(String id) =>
      _local.write(HiveBoxes.auth, deviceIdKey, id);

  @override
  Future<void> clear() => _local.delete(HiveBoxes.auth, deviceIdKey);
}
