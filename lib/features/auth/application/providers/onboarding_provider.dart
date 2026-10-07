import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/logger.dart';
import '../../domain/repositories/onboarding_store.dart';

/// Whether the device has been through the first-run intro, and what the
/// patient chose there. Immutable; the controller replaces it whole.
class OnboardingState {
  const OnboardingState({
    required this.isComplete,
    required this.offersOptIn,
    this.acceptedTermsVersion,
  });

  /// Nothing recorded yet — the router shows the intro before sign-in.
  const OnboardingState.fresh()
    : isComplete = false,
      offersOptIn = false,
      acceptedTermsVersion = null;

  final bool isComplete;
  final bool offersOptIn;
  final String? acceptedTermsVersion;
}

/// Onboarding local data source.
final onboardingLocalDataSourceProvider = Provider<OnboardingStore>(
  (ref) => throw UnimplementedError(
    'onboardingLocalDataSourceProvider is wired in app/di',
  ),
);

/// Owns the onboarding record for the whole app.
///
/// Deliberately **not** autoDispose: the router's redirect reads it on every
/// navigation, and it is a device-level fact rather than one screen's state.
/// The initial value is read synchronously from storage so there is never a
/// frame where the guard has to guess.
class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController(this._local) : super(_read(_local));

  final OnboardingStore _local;

  static OnboardingState _read(OnboardingStore local) => OnboardingState(
    isComplete: local.readComplete(),
    offersOptIn: local.readOffersOptIn(),
    acceptedTermsVersion: local.readAcceptedTermsVersion(),
  );

  /// The consent screen's outcome. [acceptedTermsVersion] is the
  /// `LegalDocument.version` shown, so a later re-consent can be prompted.
  Future<void> complete({
    required bool offersOptIn,
    required String acceptedTermsVersion,
  }) async {
    await _local.writeComplete(
      offersOptIn: offersOptIn,
      acceptedTermsVersion: acceptedTermsVersion,
    );
    state = OnboardingState(
      isComplete: true,
      offersOptIn: offersOptIn,
      acceptedTermsVersion: acceptedTermsVersion,
    );
    AppLogger.info(
      'Onboarding complete (offers opt-in: $offersOptIn)',
      name: 'auth',
    );
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>(
      (ref) =>
          OnboardingController(ref.watch(onboardingLocalDataSourceProvider)),
    );

/// True once the intro has been completed on this device.
final isOnboardingCompleteProvider = Provider<bool>(
  (ref) => ref.watch(onboardingProvider).isComplete,
);
