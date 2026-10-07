import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/logger.dart';

/// The `User-Agent` every API call sends:
/// `Medibook/1.0.0 (Google Pixel 7; Android 14)`.
///
/// The backend records it on each sign-in (`GET /patient/auth/sessions`,
/// §4.9), and Signed-in Devices names a session by the part in brackets — so
/// it has to say which phone this is and which build, not just "the app".
///
/// The device part comes from a small platform channel (`medibook/device`:
/// Android `Build`, iOS `UIDevice`) rather than a device-info plugin, which
/// is not in the locked stack (`docs-flutter/Technical_stack.md`).
abstract final class AppUserAgent {
  AppUserAgent._();

  static const String product = 'Medibook';

  /// The version sent when the build's own cannot be read.
  static const String _fallbackVersion = '1.0';

  /// What [resolve] falls back to when nothing can be read.
  static const String fallback = '$product/$_fallbackVersion';

  /// The longest a device or OS part may be, so an odd model string cannot
  /// bloat every request.
  static const int _maxPartLength = 60;

  static const MethodChannel _channel = MethodChannel('medibook/device');

  /// Reads the build's version and the device once, at bootstrap. Never
  /// throws: a part that cannot be read is left out.
  static Future<String> resolve() async {
    String? version;
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (error) {
      AppLogger.debug('App version unreadable: $error', name: 'bootstrap');
    }

    String? device;
    String? os;
    try {
      final info = await _channel.invokeMapMethod<String, Object?>('describe');
      if (info != null) {
        device = deviceName(
          manufacturer: info['manufacturer'] as String?,
          model: info['model'] as String?,
        );
        os = osName(info['os'] as String?, info['osVersion'] as String?);
      }
    } catch (error) {
      AppLogger.debug('Device details unreadable: $error', name: 'bootstrap');
    }
    os ??= Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
        ? 'iOS'
        : null;

    return format(version: version, device: device, os: os);
  }

  /// `Medibook/<version> (<device>; <os>)`, leaving out whatever is missing.
  @visibleForTesting
  static String format({String? version, String? device, String? os}) {
    final v = _clean(version);
    final details = [_clean(device), _clean(os)].whereType<String>().join('; ');
    final head = '$product/${v ?? _fallbackVersion}';
    return details.isEmpty ? head : '$head ($details)';
  }

  /// "Google" + "Pixel 7" → "Google Pixel 7"; "samsung" + "SM-S911B" →
  /// "Samsung SM-S911B"; a model that already names its maker is kept as is.
  @visibleForTesting
  static String? deviceName({String? manufacturer, String? model}) {
    final maker = _clean(manufacturer);
    final name = _clean(model);
    if (name == null) return maker == null ? null : _capitalise(maker);
    if (maker == null || name.toLowerCase().startsWith(maker.toLowerCase())) {
      return name;
    }
    return '${_capitalise(maker)} $name';
  }

  /// "Android" + "14" → "Android 14".
  @visibleForTesting
  static String? osName(String? name, String? version) {
    final n = _clean(name);
    final v = _clean(version);
    if (n == null) return null;
    return v == null ? n : '$n $v';
  }

  /// Trims, drops the characters that would break the header's own
  /// structure, and caps the length; null when nothing is left.
  static String? _clean(String? value) {
    if (value == null) return null;
    final cleaned = value
        .replaceAll(RegExp(r'[()\r\n;]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return null;
    return cleaned.length > _maxPartLength
        ? cleaned.substring(0, _maxPartLength).trim()
        : cleaned;
  }

  static String _capitalise(String value) =>
      value[0].toUpperCase() + value.substring(1);
}
