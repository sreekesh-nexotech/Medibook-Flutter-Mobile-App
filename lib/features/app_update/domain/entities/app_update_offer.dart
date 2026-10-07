/// What the store has for this install, as far as the app needs to know.
///
/// Plain immutable entity: no Flutter, no plugin types. The infrastructure
/// layer maps Google Play's `AppUpdateInfo` onto it.
class AppUpdateOffer {
  const AppUpdateOffer({
    this.isAvailable = false,
    this.isDownloaded = false,
    this.immediateAllowed = false,
    this.flexibleAllowed = false,
  });

  /// Nothing to offer — also what the app assumes when the store cannot be
  /// asked (iOS, a sideloaded or debug build, no Play Services).
  static const AppUpdateOffer none = AppUpdateOffer();

  /// A newer version is published, or an update this app started is still
  /// in progress.
  final bool isAvailable;

  /// A flexible update has finished downloading and only needs the restart.
  final bool isDownloaded;

  /// Whether the store will run each flow on this device right now.
  final bool immediateAllowed;
  final bool flexibleAllowed;

  @override
  bool operator ==(Object other) =>
      other is AppUpdateOffer &&
      other.isAvailable == isAvailable &&
      other.isDownloaded == isDownloaded &&
      other.immediateAllowed == immediateAllowed &&
      other.flexibleAllowed == flexibleAllowed;

  @override
  int get hashCode =>
      Object.hash(isAvailable, isDownloaded, immediateAllowed, flexibleAllowed);
}

/// How an available update is offered.
enum AppUpdateKind {
  /// Downloads in the background while the app stays usable; the user
  /// restarts when it is ready.
  flexible,

  /// The store's full-screen flow: the app cannot be used until it finishes.
  immediate,
}

/// How one update flow ended.
enum AppUpdateOutcome {
  /// Immediate: the user agreed and the store is installing. Flexible: the
  /// download finished and the update is ready to install.
  accepted,

  /// The user dismissed the store's prompt.
  declined,

  /// The flow could not start or did not complete.
  failed,
}
