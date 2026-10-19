import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/utils/logger.dart';

/// The installed build as "1.0.0 (1)", for the licences page a patient opens
/// when support asks which version they run (UAT REL-010). Null when the
/// platform cannot say — the page then simply shows no version.
final appVersionProvider = FutureProvider<String?>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version} (${info.buildNumber})';
  } catch (error) {
    AppLogger.debug('App version unreadable: $error', name: 'profile');
    return null;
  }
});
