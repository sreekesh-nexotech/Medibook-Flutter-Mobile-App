import 'app_update_offer.dart';

/// Decides how an available update is offered.
///
/// The rule: an install **below the backend's minimum supported version**
/// (`min_versions` in `GET /shared/app-config`, §3.1) must update before it
/// is used again, so it gets the immediate flow. Every other update is
/// flexible — it downloads in the background and never interrupts a booking.
abstract final class AppUpdatePolicy {
  AppUpdatePolicy._();

  /// The flow to start for [offer], or null when there is nothing to do.
  ///
  /// A mandatory update falls back to the flexible flow when the store will
  /// not run the immediate one on this device, rather than offering nothing.
  static AppUpdateKind? decide({
    required AppUpdateOffer offer,
    required String? installedVersion,
    required String? minVersion,
  }) {
    if (!offer.isAvailable) return null;
    if (offer.immediateAllowed &&
        isBelowMinimum(installedVersion, minVersion)) {
      return AppUpdateKind.immediate;
    }
    return offer.flexibleAllowed ? AppUpdateKind.flexible : null;
  }

  /// True when [installed] is older than [minimum]. False when either is
  /// missing — an unknown version never forces an update.
  static bool isBelowMinimum(String? installed, String? minimum) {
    if (installed == null || installed.trim().isEmpty) return false;
    if (minimum == null || minimum.trim().isEmpty) return false;
    return compareVersions(installed, minimum) < 0;
  }

  /// Compares dotted versions numerically (`1.10.0` is newer than `1.9.3`).
  /// Build metadata and pre-release suffixes (`+12`, `-beta`) are ignored, a
  /// missing segment counts as 0, and so does one that is not a number.
  static int compareVersions(String a, String b) {
    final left = _segments(a);
    final right = _segments(b);
    final length = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < length; i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l < r ? -1 : 1;
    }
    return 0;
  }

  static List<int> _segments(String version) => [
    for (final part in version.trim().split(RegExp('[+-]')).first.split('.'))
      int.tryParse(part) ?? 0,
  ];
}
