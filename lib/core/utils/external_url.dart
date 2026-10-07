import 'package:url_launcher/url_launcher.dart';

/// Hands [url] (a signed file link) to the system browser or viewer.
///
/// False when nothing on the device could take it. On Android the plugin
/// *throws* in that case rather than returning false, so every caller that
/// only checked the return value told the patient nothing (BL-REC-033);
/// this is the one place that turns both into a plain `false`.
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
