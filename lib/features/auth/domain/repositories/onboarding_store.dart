/// What the first-run onboarding leaves behind on the device.
///
/// Three non-secret facts, all in the `settings` box so they survive a
/// sign-out (`HiveBoxes.clearedOnLogout` does not include `settings`): a
/// returning patient who signs out must not be walked through the intro again.
abstract interface class OnboardingStore {
  /// True once the consent screen's "Agree and Continue" has been pressed on
  /// this device.
  bool readComplete();

  /// The optional hospital-offers opt-in. False when never answered.
  bool readOffersOptIn();

  /// The `LegalDocument.version` the patient accepted, or null.
  String? readAcceptedTermsVersion();

  /// Record the consent-screen outcome in one go.
  Future<void> writeComplete({
    required bool offersOptIn,
    required String acceptedTermsVersion,
  });
}
