import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/app_update/application/providers/app_update_provider.dart';
import 'package:medibook/features/app_update/application/states/app_update_state.dart';
import 'package:medibook/features/app_update/domain/entities/app_update_offer.dart';
import 'package:medibook/features/app_update/domain/repositories/app_update_repository.dart';

/// The update controller against a fake store.
void main() {
  const available = AppUpdateOffer(
    isAvailable: true,
    immediateAllowed: true,
    flexibleAllowed: true,
  );

  late FakeAppUpdateRepository repository;
  String? minVersion;

  AppUpdateController build() {
    final controller = AppUpdateController(
      repository: repository,
      minVersion: () => minVersion,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  setUp(() {
    repository = FakeAppUpdateRepository();
    minVersion = null;
  });

  test('no update: nothing starts and nothing shows', () async {
    final controller = build();

    await controller.check();

    expect(repository.calls, ['check']);
    expect(controller.state, const AppUpdateState());
  });

  test('an optional update downloads, then asks for the restart', () async {
    repository.offer = available;
    final controller = build();

    await controller.check();
    expect(repository.calls, ['check', 'flexible']);
    expect(controller.state.phase, AppUpdatePhase.idle);

    repository.flexible.complete(AppUpdateOutcome.accepted);
    await pumpEventQueue();
    expect(controller.state.phase, AppUpdatePhase.readyToInstall);

    controller.install();
    expect(repository.calls.last, 'complete');
  });

  test('a dismissed optional update is offered once per launch', () async {
    repository.offer = available;
    final controller = build();

    await controller.check();
    repository.flexible.complete(AppUpdateOutcome.declined);
    await pumpEventQueue();
    await controller.check();

    expect(repository.calls.where((c) => c == 'flexible'), hasLength(1));
    expect(controller.state.phase, AppUpdatePhase.idle);
  });

  test('an already-downloaded update asks for the restart; "Later" holds '
      'until the next launch', () async {
    repository.offer = const AppUpdateOffer(
      isAvailable: true,
      isDownloaded: true,
    );
    final controller = build();

    await controller.check();
    expect(controller.state.phase, AppUpdatePhase.readyToInstall);

    controller.deferInstall();
    await controller.check();
    expect(controller.state.phase, AppUpdatePhase.idle);
  });

  group('below the minimum version', () {
    setUp(() {
      repository.offer = available;
      repository.installed = '1.0.0';
      minVersion = '1.1.0';
    });

    test('runs the immediate flow; accepting leaves the store to it', () async {
      final controller = build();

      await controller.check();

      expect(repository.calls, ['check', 'installedVersion', 'immediate']);
      expect(controller.state.phase, AppUpdatePhase.idle);
    });

    test('backing out raises the gate, and a resume does not relaunch the '
        'store', () async {
      repository.immediate = AppUpdateOutcome.declined;
      final controller = build();

      await controller.check();
      expect(controller.state.phase, AppUpdatePhase.required);

      await controller.check();
      expect(repository.calls.where((c) => c == 'immediate'), hasLength(1));
    });

    test('"Update now" re-runs the flow and keeps the gate if declined '
        'again', () async {
      repository.immediate = AppUpdateOutcome.declined;
      final controller = build();
      await controller.check();

      await controller.retryRequired();

      expect(repository.calls.where((c) => c == 'immediate'), hasLength(2));
      expect(
        controller.state,
        const AppUpdateState(phase: AppUpdatePhase.required),
      );
    });

    test('the gate comes down when the store can no longer update', () async {
      repository.immediate = AppUpdateOutcome.declined;
      final controller = build();
      await controller.check();

      repository.offer = AppUpdateOffer.none;
      await controller.retryRequired();

      expect(controller.state, const AppUpdateState());
    });
  });

  test('the provider builds the controller idle', () {
    final container = ProviderContainer(
      overrides: [appUpdateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    expect(container.read(appUpdateProvider), const AppUpdateState());
  });
}

class FakeAppUpdateRepository implements AppUpdateRepository {
  AppUpdateOffer offer = AppUpdateOffer.none;
  String? installed;
  AppUpdateOutcome immediate = AppUpdateOutcome.accepted;

  /// Completed by the test — the real flow resolves when the download ends.
  final Completer<AppUpdateOutcome> flexible = Completer<AppUpdateOutcome>();

  final List<String> calls = <String>[];

  @override
  Future<AppUpdateOffer> check() async {
    calls.add('check');
    return offer;
  }

  @override
  Future<String?> installedVersion() async {
    calls.add('installedVersion');
    return installed;
  }

  @override
  Future<AppUpdateOutcome> startImmediate() async {
    calls.add('immediate');
    return immediate;
  }

  @override
  Future<AppUpdateOutcome> startFlexible() {
    calls.add('flexible');
    return flexible.future;
  }

  @override
  void completeFlexible() => calls.add('complete');
}
