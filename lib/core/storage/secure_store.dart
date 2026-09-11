import 'dart:async';

import '../error/failure.dart';
import '../utils/logger.dart';

/// The key registry for secure storage.
///
/// Coding Standards §9: tokens and PII never touch Hive or SharedPreferences.
/// Everything listed here goes to the platform keystore (Android Keystore /
/// iOS Keychain) via a [SecureStore] implementation.
abstract final class SecureKeys {
  SecureKeys._();

  /// Short-lived bearer token.
  static const String accessToken = 'access_token';

  /// Long-lived refresh token (Coding Standards §6.2).
  static const String refreshToken = 'refresh_token';

  /// Absolute expiry of [accessToken], ISO-8601, so the client can refresh
  /// pre-emptively instead of waiting for a 401.
  static const String accessTokenExpiry = 'access_token_expiry';

  /// Opaque device identifier registered for push.
  static const String deviceToken = 'device_token';

  /// The user's PIN/biometric gate secret, if the app ever offers one.
  static const String appLockSecret = 'app_lock_secret';

  /// Every key the store owns — what [SecureStore.deleteAll] must clear.
  static const List<String> all = [
    accessToken,
    refreshToken,
    accessTokenExpiry,
    deviceToken,
    appLockSecret,
  ];
}

/// Secure key-value storage for tokens and PII.
///
/// Deliberately an **interface**: `flutter_secure_storage` is not a dependency
/// of this presentation-layer build (see `pubspec.yaml`), and adding a
/// credential store before there are credentials to store would be worse than
/// not having one. The data layer supplies
/// `FlutterSecureStorageStore implements SecureStore` and nothing above this
/// file changes.
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

  /// Delete every key this store owns.
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
  }) async {
    await write(SecureKeys.accessToken, accessToken);
    await write(SecureKeys.refreshToken, refreshToken);
    await write(SecureKeys.accessTokenExpiry, expiresAt?.toIso8601String());
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
  }
}

/// An in-memory [SecureStore].
///
/// This is what the app runs on until the platform-backed implementation
/// exists: it satisfies the contract exactly, keeps nothing on disk, and dies
/// with the process — which is the *safe* failure mode for a credential store
/// (a signed-in session simply does not survive a restart) and is honest about
/// being a stand-in, unlike writing tokens to a plaintext preference file.
///
/// Not suitable for production. `app/bootstrap/app_bootstrap.dart` is the one
/// place to swap it.
class InMemorySecureStore implements SecureStore {
  InMemorySecureStore({Map<String, String>? seed})
    : _values = {...?seed};

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
    _values.clear();
    AppLogger.info('Secure store cleared', name: 'security');
  }

  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);
}
