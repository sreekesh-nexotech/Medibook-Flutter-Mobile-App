import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../support/application/providers/app_config_provider.dart';
import '../../domain/entities/app_update_offer.dart';
import '../../domain/entities/app_update_policy.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../states/app_update_state.dart';

/// Tests override this with a fake; nothing below reads the implementation.
final appUpdateRepositoryProvider = Provider<AppUpdateRepository>(
  (ref) => throw UnimplementedError(
    'appUpdateRepositoryProvider is wired in app/di',
  ),
);

/// Drives Google Play's in-app update flows.
///
/// No `BuildContext`, no navigation: `AppUpdateGate` calls [check] at launch
/// and on every resume, and reacts to [AppUpdateState.phase].
class AppUpdateController extends StateNotifier<AppUpdateState> {
  AppUpdateController({
    required AppUpdateRepository repository,
    required String? Function() minVersion,
  }) : _repository = repository,
       _minVersion = minVersion,
       super(const AppUpdateState());

  final AppUpdateRepository _repository;

  /// The backend's minimum supported version, read at decision time because
  /// the app config can arrive after the first check.
  final String? Function() _minVersion;

  bool _evaluating = false;

  /// The flexible prompt is shown once per launch; a user who dismissed it is
  /// not asked again every time the app comes back to the foreground.
  bool _flexibleOffered = false;

  /// "Later" on the restart prompt holds until the next launch, for the same
  /// reason.
  bool _installDeferred = false;

  /// Looks for an update and starts the right flow. Safe to call often.
  Future<void> check() async {
    // Once the gate is up its button drives the flow — re-launching the
    // store's screen on every resume would trap the user in a loop.
    if (state.phase == AppUpdatePhase.required) return;
    await _evaluate();
  }

  /// The gate's "Update now": asks the store again and re-runs the flow.
  Future<void> retryRequired() async {
    if (state.isBusy) return;
    state = state.copyWith(isBusy: true);
    await _evaluate();
    if (mounted) state = state.copyWith(isBusy: false);
  }

  /// Installs the downloaded flexible update. The app restarts.
  void install() => _repository.completeFlexible();

  /// The user chose "Later" on the restart prompt.
  void deferInstall() {
    _installDeferred = true;
    state = state.copyWith(phase: AppUpdatePhase.idle);
  }

  Future<void> _evaluate() async {
    if (_evaluating) return;
    _evaluating = true;
    try {
      final offer = await _repository.check();
      if (!mounted) return;
      if (offer.isDownloaded) {
        if (!_installDeferred) {
          state = state.copyWith(phase: AppUpdatePhase.readyToInstall);
        }
        return;
      }

      final minimum = _minVersion();
      final installed = offer.isAvailable && minimum != null
          ? await _repository.installedVersion()
          : null;
      if (!mounted) return;

      switch (AppUpdatePolicy.decide(
        offer: offer,
        installedVersion: installed,
        minVersion: minimum,
      )) {
        case AppUpdateKind.immediate:
          final outcome = await _repository.startImmediate();
          if (!mounted) return;
          // Accepted: the store installs and restarts the app. Anything else
          // leaves an unsupported version running, so the gate goes up.
          if (outcome != AppUpdateOutcome.accepted) {
            state = state.copyWith(phase: AppUpdatePhase.required);
          }
        case AppUpdateKind.flexible:
          _releaseGate();
          if (_flexibleOffered) return;
          _flexibleOffered = true;
          // Not awaited: the download can take minutes and must not hold up
          // later checks (a mandatory minimum may arrive in the meantime).
          unawaited(_download());
        case null:
          _releaseGate();
      }
    } finally {
      _evaluating = false;
    }
  }

  Future<void> _download() async {
    final outcome = await _repository.startFlexible();
    if (!mounted || outcome != AppUpdateOutcome.accepted) return;
    state = state.copyWith(phase: AppUpdatePhase.readyToInstall);
  }

  /// The gate only stands while the store can actually run the mandatory
  /// update; if it no longer can, blocking the app would strand the user.
  void _releaseGate() {
    if (state.phase == AppUpdatePhase.required) {
      state = state.copyWith(phase: AppUpdatePhase.idle);
    }
  }
}

/// **Not** autoDispose: the gate above the router holds it for the life of
/// the app, and the once-per-launch prompt flag lives in the controller.
final appUpdateProvider =
    StateNotifierProvider<AppUpdateController, AppUpdateState>(
      (ref) => AppUpdateController(
        repository: ref.watch(appUpdateRepositoryProvider),
        minVersion: () => ref.read(appConfigValueProvider).minVersionAndroid,
      ),
    );
