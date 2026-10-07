import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/app_update/application/providers/app_update_provider.dart';
import 'package:medibook/features/app_update/domain/entities/app_update_offer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/app_update/presentation/components/app_update_gate.dart';
import 'package:medibook/features/common/cached/application/providers/cached_controller.dart';
import 'package:medibook/features/support/application/providers/app_config_provider.dart';
import 'package:medibook/features/support/domain/entities/app_config.dart';

import '../../support/harness.dart';
import 'app_update_controller_test.dart' show FakeAppUpdateRepository;

void main() {
  /// The app config answering once, from the network, with [config].
  Override appConfig([AppConfig config = AppConfig.fallback]) =>
      appConfigProvider.overrideWith(
        (ref) => CachedController<AppConfig>(
          ({required forceRefresh}) => Stream.value(
            CachedResult<AppConfig>(
              value: config,
              source: CacheSource.network,
              cachedAt: DateTime.now(),
            ),
          ),
        ),
      );

  testWidgets('idle: the app shows through untouched', (tester) async {
    final updates = FakeAppUpdateRepository();
    await tester.pumpWidget(
      screenHarness(
        const AppUpdateGate(child: Scaffold(body: Text('the app'))),
        overrides: [
          appUpdateRepositoryProvider.overrideWithValue(updates),
          appConfig(),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(updates.calls, ['check']);
    expect(find.text('the app'), findsOneWidget);
    expect(find.text('Update required'), findsNothing);
  });

  testWidgets('a declined mandatory update blocks the app until "Update now" '
      'succeeds', (tester) async {
    final updates = FakeAppUpdateRepository()
      ..offer = const AppUpdateOffer(
        isAvailable: true,
        immediateAllowed: true,
        flexibleAllowed: true,
      )
      ..installed = '1.0.0'
      ..immediate = AppUpdateOutcome.declined;
    await tester.pumpWidget(
      screenHarness(
        const AppUpdateGate(child: Scaffold(body: Text('the app'))),
        overrides: [
          appUpdateRepositoryProvider.overrideWithValue(updates),
          appConfig(const AppConfig(minVersionAndroid: '1.1.0')),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update required'), findsOneWidget);
    expect(updates.calls.where((c) => c == 'immediate'), hasLength(1));

    updates.immediate = AppUpdateOutcome.accepted;
    await tester.tap(find.text('Update now'));
    await tester.pumpAndSettle();

    expect(updates.calls.where((c) => c == 'immediate'), hasLength(2));
  });
}
