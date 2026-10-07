import 'package:flutter/foundation.dart';

/// What, if anything, the app shows about an update.
enum AppUpdatePhase {
  /// Nothing to show — no update, or one downloading quietly.
  idle,

  /// A flexible update has downloaded; the user is asked to restart.
  readyToInstall,

  /// This version is below the supported minimum and the user backed out of
  /// the update. The app is blocked until they update.
  required,
}

@immutable
class AppUpdateState {
  const AppUpdateState({this.phase = AppUpdatePhase.idle, this.isBusy = false});

  final AppUpdatePhase phase;

  /// True while the "Update now" retry is asking the store — the button
  /// shows its spinner and ignores taps.
  final bool isBusy;

  AppUpdateState copyWith({AppUpdatePhase? phase, bool? isBusy}) =>
      AppUpdateState(phase: phase ?? this.phase, isBusy: isBusy ?? this.isBusy);

  @override
  bool operator ==(Object other) =>
      other is AppUpdateState && other.phase == phase && other.isBusy == isBusy;

  @override
  int get hashCode => Object.hash(phase, isBusy);
}
