import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/location_scope.dart';
import '../../domain/repositories/location_scope_store.dart';

final locationScopeLocalDataSourceProvider = Provider<LocationScopeStore>(
  (ref) => throw UnimplementedError(
    'locationScopeLocalDataSourceProvider is wired in app/di',
  ),
);

/// The saved browse location, or null for "everywhere" (CL DISC-001).
/// Read synchronously at start so Home's first request is already scoped.
final locationScopeProvider =
    StateNotifierProvider<LocationScopeController, LocationScope?>(
      (ref) => LocationScopeController(
        ref.watch(locationScopeLocalDataSourceProvider),
      ),
    );

class LocationScopeController extends StateNotifier<LocationScope?> {
  LocationScopeController(this._local) : super(_local.read());

  final LocationScopeStore _local;

  Future<void> choose(LocationScope scope) async {
    state = scope;
    await _local.write(scope);
  }

  Future<void> clear() async {
    state = null;
    await _local.clear();
  }
}
