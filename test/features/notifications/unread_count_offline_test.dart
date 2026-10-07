import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/core/network/api_client.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/core/storage/local_store.dart';
import 'package:medibook/features/notifications/infrastructure/data_sources/local/push_device_local_ds.dart';
import 'package:medibook/features/notifications/infrastructure/data_sources/remote/notifications_api.dart';
import 'package:medibook/features/notifications/infrastructure/repositories/notifications_repository_impl.dart';

/// Offline, the bell used to read "no unread": the count was never saved
/// (found in the BL-CACHE-010 / -019 runs). Now the last count the server
/// gave is kept, and is asked of the server every time while online.
void main() {
  late _Client client;
  late _Connectivity connectivity;
  late NotificationsRepositoryImpl repository;
  late CachedFetcher fetcher;

  setUp(() {
    client = _Client();
    connectivity = _Connectivity();
    fetcher = CachedFetcher(
      client: client,
      connectivity: connectivity,
      store: InMemoryLocalStore(),
    );
    addTearDown(fetcher.dispose);
    repository = NotificationsRepositoryImpl(
      api: HttpNotificationsApi(client),
      fetcher: fetcher,
      local: _NoPushDevice(),
    );
  });

  test('online: the count is always asked of the server', () async {
    client.count = 13;
    expect(await repository.unreadCount(), 13);
    client.count = 12;
    expect(await repository.unreadCount(), 12);
    expect(client.calls, 2);
  });

  test('offline: the last count is shown, at once', () async {
    client.count = 13;
    await repository.unreadCount();

    connectivity.isOnline = false;
    client.fail = true;
    final count = await repository.unreadCount().timeout(
      const Duration(seconds: 1),
    );
    expect(count, 13);
  });

  test('offline with no saved count is still an error', () async {
    connectivity.isOnline = false;
    client.fail = true;
    await expectLater(repository.unreadCount(), throwsA(anything));
  });
}

class _Client with ApiClientVerbs implements ApiClient {
  int count = 0;
  int calls = 0;
  bool fail = false;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    calls++;
    if (fail) throw const NoConnectionException();
    return ApiResponse(statusCode: 200, data: {'unread_count': count});
  }
}

class _Connectivity extends ConnectivityMonitor {
  final StreamController<void> _never = StreamController<void>.broadcast();

  @override
  bool isOnline = true;

  /// Never reconnects during a test.
  @override
  Stream<void> get onReconnect => _never.stream;
}

class _NoPushDevice implements PushDeviceLocalDataSource {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
