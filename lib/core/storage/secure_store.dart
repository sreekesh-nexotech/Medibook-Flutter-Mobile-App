import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../error/failure.dart';
import '../utils/logger.dart';

/// The key registry for secure storage.
///
/// Coding Standards §9: tokens and PII never touch Hive or SharedPreferences.
/// Everything listed here goes to the platform keystore (Android Keystore /
/// iOS Keychain) via a [SecureStore] implementation.
abstract final class SecureKeys {
  SecureKeys._();

  /// Short-lived bearer token (15 minutes, §1.4).
  static const String accessToken = 'access_token';

  /// Rotating refresh token (§1.4). Replaced on every refresh.
  static const String refreshToken = 'refresh_token';

  /// Absolute expiry of [accessToken], ISO-8601, so the client can refresh
  /// pre-emptively instead of waiting for a 401.
  static const String accessTokenExpiry = 'access_token_expiry';

  /// The backend session id, for `DELETE /auth/sessions/{id}` bookkeeping.
  static const String sessionId = 'session_id';

  /// The stable per-install id sent as `X-Device-Fingerprint` (§1.3).
  ///
  /// Lives in the keystore rather than Hive because an OTP code is bound to
  /// it: a cache wipe must not change it mid-verification.
  static const String deviceFingerprint = 'device_fingerprint';

  /// The backend `Device.id` registered for push (§12.6).
  static const String pushDeviceId = 'push_device_id';

  /// The AES key the on-device Hive boxes are encrypted with (base64, 32
  /// bytes). Like [deviceFingerprint] it belongs to the install, not the
  /// user, so it survives a sign-out — the boxes kept across sign-out (the
  /// onboarding flag) must stay readable (CL SEC-005).
  static const String localStorageKey = 'local_storage_key';

  /// The user's PIN/biometric gate secret, if the app ever offers one.
  static const String appLockSecret = 'app_lock_secret';

  /// Every key the store owns — what [SecureStore.deleteAll] must clear.
  ///
  /// [deviceFingerprint] is deliberately **not** here: it identifies the
  /// install, not the user, and must survive a sign-out.
  static const List<String> all = [
    accessToken,
    refreshToken,
    accessTokenExpiry,
    sessionId,
    pushDeviceId,
    appLockSecret,
  ];
}

/// Secure key-value storage for tokens and PII.
///
/// Implementations must:
/// * be backed by the platform keystore, never by a plaintext file;
/// * throw a [CacheFailure] (not a platform exception) when the keystore is
///   unavailable, so callers keep dealing in [Failure];
/// * treat a missing key as `null`, not as an error.
abstract interface class SecureStore {
  /// Read [key], or null when it is not set.
  Future<String?> read(String key);

  /// Write [value] at [key]. A null [value] deletes the key.
  Future<void> write(String key, String? value);

  /// Delete [key]. Deleting a missing key is a no-op.
  Future<void> delete(String key);

  /// Delete every key in [SecureKeys.all].
  ///
  /// This is the storage half of CM-53 ("logout clears session") — the other
  /// half is `HiveBoxes.clearedOnLogout`.
  Future<void> deleteAll();

  /// True when [key] has a value.
  Future<bool> containsKey(String key);
}

/// Token-shaped conveniences on top of the raw key-value surface, so callers
/// never hand-spell a key from [SecureKeys].
extension SecureStoreTokens on SecureStore {
  Future<String?> get accessToken => read(SecureKeys.accessToken);

  Future<String?> get refreshToken => read(SecureKeys.refreshToken);

  /// Persist a freshly issued token pair.
  Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? sessionId,
  }) async {
    await write(SecureKeys.accessToken, accessToken);
    await write(SecureKeys.refreshToken, refreshToken);
    await write(SecureKeys.accessTokenExpiry, expiresAt?.toIso8601String());
    if (sessionId != null) await write(SecureKeys.sessionId, sessionId);
  }

  /// True when there is an access token and it has not expired.
  ///
  /// A token with no recorded expiry is treated as valid — the server remains
  /// the authority, and a 401 will correct us.
  Future<bool> get hasValidSession async {
    final token = await accessToken;
    if (token == null || token.isEmpty) return false;
    final raw = await read(SecureKeys.accessTokenExpiry);
    final expiry = raw == null ? null : DateTime.tryParse(raw);
    if (expiry == null) return true;
    return expiry.isAfter(DateTime.now());
  }

  /// Forget the session (sign-out, or a refresh that failed).
  Future<void> clearSession() async {
    await delete(SecureKeys.accessToken);
    await delete(SecureKeys.refreshToken);
    await delete(SecureKeys.accessTokenExpiry);
    await delete(SecureKeys.sessionId);
  }
}

/// An in-memory [SecureStore].
///
/// Used by widget tests and as the provider default. It satisfies the contract
/// exactly, keeps nothing on disk, and dies with the process — the *safe*
/// failure mode for a credential store.
///
/// Not suitable for production. `app/bootstrap/app_bootstrap.dart` overrides
/// it with [FlutterSecureStorageStore].
class InMemorySecureStore implements SecureStore {
  InMemorySecureStore({Map<String, String>? seed}) : _values = {...?seed};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      _values.remove(key);
      return;
    }
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> deleteAll() async {
    for (final key in SecureKeys.all) {
      _values.remove(key);
    }
    AppLogger.info('Secure store cleared', name: 'security');
  }

  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);
}

/// The production [SecureStore]: Android Keystore / iOS Keychain through
/// `flutter_secure_storage`.
///
/// Every platform error is wrapped as a [CacheFailure] so callers keep
/// dealing in [Failure]. Reads of a missing key return null.
class FlutterSecureStorageStore implements SecureStore {
  FlutterSecureStorageStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _guard(() => _storage.read(key: key));

  @override
  Future<void> write(String key, String? value) => _guard(() async {
    if (value == null) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: value);
  });

  @override
  Future<void> delete(String key) => _guard(() => _storage.delete(key: key));

  @override
  Future<void> deleteAll() => _guard(() async {
    for (final key in SecureKeys.all) {
      await _storage.delete(key: key);
    }
    AppLogger.info('Secure store cleared', name: 'security');
  });

  @override
  Future<bool> containsKey(String key) =>
      _guard(() => _storage.containsKey(key: key));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlatformException catch (error, stackTrace) {
      throw CacheFailure(
        userMessage:
            'Secure storage is unavailable on this device. Please sign in '
            'again.',
        debugMessage: 'keystore: ${error.code}',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
