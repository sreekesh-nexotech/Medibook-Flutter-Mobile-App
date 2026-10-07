import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../support/application/providers/support_provider.dart';
import 'onboarding_provider.dart';

/// The consent screen's two boxes and whether an accept has been refused.
class ConsentFormState {
  const ConsentFormState({
    this.agreeTerms = false,
    this.agreeOffers = false,
    this.triedAccept = false,
    this.policiesUnavailable = false,
    this.isBusy = false,
  });

  /// Required.
  final bool agreeTerms;

  /// Optional — "hospital offers and health camp updates".
  final bool agreeOffers;

  /// True after "Agree and Continue" was pressed without the terms box.
  final bool triedAccept;

  /// True after "Agree and Continue" was pressed with the box ticked but the
  /// policies it names could not be loaded — nobody can agree to a document
  /// the app could not show them.
  final bool policiesUnavailable;

  /// True while the policies are being fetched or the record is being written.
  final bool isBusy;

  /// The "Please accept the terms to continue." note is shown only after a
  /// refused press, and clears as soon as the box is ticked.
  bool get showRequiredNote => triedAccept && !agreeTerms;

  /// The "could not load the policies" note. Clears on the next press, when
  /// the box is changed, and by itself once the documents arrive.
  bool get showPoliciesNote => policiesUnavailable;

  ConsentFormState copyWith({
    bool? agreeTerms,
    bool? agreeOffers,
    bool? triedAccept,
    bool? policiesUnavailable,
    bool? isBusy,
  }) {
    return ConsentFormState(
      agreeTerms: agreeTerms ?? this.agreeTerms,
      agreeOffers: agreeOffers ?? this.agreeOffers,
      triedAccept: triedAccept ?? this.triedAccept,
      policiesUnavailable: policiesUnavailable ?? this.policiesUnavailable,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

/// The onboarding consent form.
///
/// One required box, one optional. The CTA is never disabled: a press without
/// the terms box lands, so the note can explain the block, instead of a dead
/// button the patient has to guess at.
///
/// Ticking the box is not enough on its own: the documents it names
/// ([requiredPolicies]) must have loaded on this device, so the patient was
/// able to open what they are agreeing to. On a device that is offline at
/// first launch the press is refused with [ConsentFormState.showPoliciesNote]
/// and the same CTA retries the load.
class ConsentFormController extends StateNotifier<ConsentFormState> {
  ConsentFormController(this._ref) : super(const ConsentFormState());

  /// The documents the required box names — "I agree to the Terms &
  /// Conditions and Privacy Policy".
  static const List<String> requiredPolicies = [
    AppRoutes.legalTerms,
    AppRoutes.legalPrivacy,
  ];

  final Ref _ref;

  void setAgreeTerms(bool value) => state = state.copyWith(
    agreeTerms: value,
    triedAccept: false,
    policiesUnavailable: false,
  );

  void toggleAgreeTerms() => setAgreeTerms(!state.agreeTerms);

  void setAgreeOffers(bool value) => state = state.copyWith(agreeOffers: value);

  void toggleAgreeOffers() => setAgreeOffers(!state.agreeOffers);

  /// Record the consent. Returns true when sign-in should open; false when
  /// the terms box is still empty or the policies could not be loaded (the
  /// matching note is now showing).
  Future<bool> accept() async {
    if (state.isBusy) return false;
    if (!state.agreeTerms) {
      state = state.copyWith(triedAccept: true);
      return false;
    }
    state = state.copyWith(
      isBusy: true,
      triedAccept: false,
      policiesUnavailable: false,
    );
    try {
      await Future.wait(requiredPolicies.map(_ensureLoaded));
      if (!mounted) return false;
      if (!_policiesReady) {
        state = state.copyWith(policiesUnavailable: true);
        return false;
      }
      // The version the consent screen could show (`GET /patient/legal/terms`,
      // §3.2). The profile screen's pending-consents check (§3.4) is what
      // records consent with the server.
      final terms = _ref.read(legalDocumentProvider(AppRoutes.legalTerms));
      await _ref
          .read(onboardingProvider.notifier)
          .complete(
            offersOptIn: state.agreeOffers,
            acceptedTermsVersion: terms.value!.version.toString(),
          );
      return true;
    } finally {
      if (mounted) state = state.copyWith(isBusy: false);
    }
  }

  bool get _policiesReady => requiredPolicies.every(
    (slug) => _ref.read(legalDocumentProvider(slug)).hasValue,
  );

  /// Waits for [slug]'s first load if it is still in flight; retries it once
  /// if it has already failed (offline at first launch, most likely). A copy
  /// served from the cache counts — the patient could open it.
  Future<void> _ensureLoaded(String slug) async {
    final provider = legalDocumentProvider(slug);
    final current = _ref.read(provider);
    if (current.hasValue) return;
    final notifier = _ref.read(provider.notifier);
    if (current.isLoading) {
      await notifier.stream.firstWhere(
        (next) => !next.isLoading,
        orElse: () => current,
      );
      return;
    }
    await notifier.refresh(force: true);
  }

  /// Drops the "could not load" note as soon as the documents arrive (the
  /// connection came back while the patient was reading it).
  void _onPoliciesChanged() {
    if (!mounted || !state.policiesUnavailable || !_policiesReady) return;
    state = state.copyWith(policiesUnavailable: false);
  }
}

/// autoDispose — one visit to the screen, one form state.
///
/// Listening to the policies here starts their load when the consent screen
/// opens and keeps the (autoDispose) documents resident for as long as the
/// form is, so [ConsentFormController.accept] has an answer to check.
final consentFormControllerProvider =
    StateNotifierProvider.autoDispose<ConsentFormController, ConsentFormState>((
      ref,
    ) {
      final controller = ConsentFormController(ref);
      for (final slug in ConsentFormController.requiredPolicies) {
        ref.listen(
          legalDocumentProvider(slug),
          (_, _) => controller._onPoliciesChanged(),
        );
      }
      return controller;
    });
