import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/external_url.dart';

/// The two hand-offs to the OS the appointments feature makes (§10.9,
/// §10.10), kept in one place so every screen spells them the same.
abstract final class ExternalLinks {
  ExternalLinks._();

  /// Opens a signed URL (the receipt PDF) in the system browser / viewer.
  /// False when nothing on the device could handle it.
  static Future<bool> openUrl(String url) => openExternalUrl(url);

  /// Hands a saved file to the OS share sheet, where the calendar app takes
  /// an `.ics`. A `file://` URI cannot leave the app's private storage on
  /// Android, so the file goes through `share_plus`' content provider.
  ///
  /// False only when the sheet could not be shown at all — a dismissed sheet
  /// is the user's choice, not a failure.
  static Future<bool> shareFile(String path, {required String mimeType}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path, mimeType: mimeType)]),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
