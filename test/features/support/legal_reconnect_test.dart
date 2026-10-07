import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/support/application/providers/support_provider.dart';
import 'package:medibook/features/support/domain/entities/legal_document.dart';
import 'package:medibook/features/support/domain/repositories/support_content_repository.dart';

/// Checklist ONB-004: a policy opened offline from the consent screen kept
/// showing "You appear to be offline" after the connection came back. A
/// document whose load failed loads again on reconnect.
void main() {
  test('a failed policy loads again when the device reconnects', () async {
    final repository = _Repository();
    final monitor = _Monitor();
    final container = ProviderContainer(
      overrides: [
        supportContentRepositoryProvider.overrideWithValue(repository),
        connectivityMonitorProvider.overrideWithValue(monitor),
      ],
    );
    addTearDown(container.dispose);
    final provider = legalDocumentProvider('terms');
    final sub = container.listen(provider, (_, _) {});
    addTearDown(sub.close);

    await pumpEventQueue();
    expect(sub.read().isError, isTrue);

    repository.online = true;
    monitor.reconnect();
    await pumpEventQueue();

    expect(sub.read().value?.title, 'Terms of Service');
  });
}

class _Repository implements SupportContentRepository {
  bool online = false;

  @override
  Stream<CachedResult<LegalDocument>> legalDocument(
    String slug, {
    bool forceRefresh = false,
  }) async* {
    if (!online) throw const NetworkFailure();
    yield CachedResult(
      value: LegalDocument(
        slug: slug,
        version: 1,
        title: 'Terms of Service',
        bodyMd: 'x',
      ),
      source: CacheSource.network,
      cachedAt: DateTime.now(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Monitor extends ConnectivityMonitor {
  final StreamController<void> _reconnects = StreamController<void>.broadcast();

  void reconnect() => _reconnects.add(null);

  @override
  Stream<void> get onReconnect => _reconnects.stream;
}
