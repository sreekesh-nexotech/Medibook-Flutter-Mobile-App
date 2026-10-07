import '../../../../../app/bootstrap/hive_init.dart';
import '../../../../../core/storage/hive/boxes.dart';
import '../../../../../core/storage/hive/keys.dart';
import '../../../domain/entities/location_scope.dart';
import '../../../domain/repositories/location_scope_store.dart';

class LocationScopeLocalDataSourceImpl implements LocationScopeStore {
  const LocationScopeLocalDataSourceImpl();

  LocalStore get _local => HiveInit.store;

  @override
  LocationScope? read() {
    final city = _local.read(HiveBoxes.settings, HiveKeys.selectedCity);
    if (city is! String || city.isEmpty) return null;
    final area = _local.read(HiveBoxes.settings, HiveKeys.selectedArea);
    return LocationScope(
      city: city,
      area: area is String && area.isNotEmpty ? area : null,
    );
  }

  @override
  Future<void> write(LocationScope scope) async {
    await _local.write(HiveBoxes.settings, HiveKeys.selectedArea, scope.area);
    await _local.write(HiveBoxes.settings, HiveKeys.selectedCity, scope.city);
  }

  @override
  Future<void> clear() async {
    await _local.delete(HiveBoxes.settings, HiveKeys.selectedCity);
    await _local.delete(HiveBoxes.settings, HiveKeys.selectedArea);
  }
}
