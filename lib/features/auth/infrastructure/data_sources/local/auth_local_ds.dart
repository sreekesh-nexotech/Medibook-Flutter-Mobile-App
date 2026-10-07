import 'dart:async';

import '../../../../../app/bootstrap/hive_init.dart';
import '../../../../../core/storage/hive/boxes.dart';
import '../../../../../core/storage/hive/keys.dart';
import '../../../../../core/storage/secure_store.dart';
import '../../../../../core/utils/logger.dart';
import '../../../domain/entities/user.dart';
import '../../../../../core/storage/session_files.dart';

/// Local persistence for the auth feature.
///
/// Splits cleanly in two, and the split is the security boundary:
/// * **Credentials** ([AuthSession]) go to [SecureStore] — the platform
///   keystore. Never Hive, never a preference file (Coding Standards §9).
/// * **Non-secret session metadata** (user id, display name, phone, the
///   lockout deadline the server announced) goes to the `auth` Hive box,
///   where it is cheap to read at startup.
///
/// This is the only file in the feature that touches Hive or the keystore
/// (QA Prompt 6 §11).
abstract interface class AuthLocalDataSource {
  /// The cached user, or null.
  Future<User?> readUser();

  /// Cache [user] (non-secret fields only).
  Future<void> writeUser(User user);

  /// The stored session, or null.
  Future<AuthSession?> readSession();

  /// Persist [session] to secure storage.
  Future<void> writeSession(AuthSession session);

  /// The access token only — the hot path for every request.
  Future<String?> readAccessToken();

  /// The lockout deadline the server announced, or null.
  Future<DateTime?> readLockedUntil();

  /// The account the lockout belongs to, or null (a lockout remembered
  /// before this was recorded applies to every account).
  Future<String?> readLockedIdentifier();

  /// Remember a server lockout of [identifier] ending at [until].
  Future<void> writeLockedUntil(DateTime until, {String? identifier});

  /// Clear any remembered lockout.
  Future<void> clearLockout();

  /// Erase everything: credentials, cached user and session boxes.
  ///
  /// This is the local half of CM-53 — after this, nothing about the previous
  /// patient remains on the device.
  Future<void> clear();
}

/// [AuthLocalDataSource] over [SecureStore] + the process-wide [LocalStore].
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl({required SecureStore secureStore})
    : _secure = secureStore;

  final SecureStore _secure;

  LocalStore get _local => HiveInit.store;

  @override
  Future<User?> readUser() async {
    final id = _local.read(HiveBoxes.auth, HiveKeys.userId);
    if (id is! String || id.isEmpty) return null;
    final first = _local.read(HiveBoxes.auth, HiveKeys.userDisplayName);
    final last = _local.read(HiveBoxes.auth, HiveKeys.userLastName);
    final phone = _local.read(HiveBoxes.auth, HiveKeys.userPhone);
    final hasPassword = _local.read(HiveBoxes.auth, HiveKeys.userHasPassword);
    final version = _local.read(HiveBoxes.auth, HiveKeys.userVersion);
    return User(
      id: id,
      firstName: first is String ? first : '',
      lastName: last is String ? last : null,
      // Email is not cached — it is PII with no startup value. The `/me`
      // refresh fills it in.
      phoneE164: phone is String ? phone : null,
      hasPassword: hasPassword == true,
      version: version is int ? version : 1,
    );
  }

  @override
  Future<void> writeUser(User user) async {
    await _local.write(HiveBoxes.auth, HiveKeys.userId, user.id);
    await _local.write(
      HiveBoxes.auth,
      HiveKeys.userDisplayName,
      user.firstName,
    );
    await _local.write(HiveBoxes.auth, HiveKeys.userLastName, user.lastName);
    await _local.write(HiveBoxes.auth, HiveKeys.userPhone, user.phoneE164);
    await _local.write(
      HiveBoxes.auth,
      HiveKeys.userHasPassword,
      user.hasPassword,
    );
    await _local.write(HiveBoxes.auth, HiveKeys.userVersion, user.version);
    await _local.write(
      HiveBoxes.auth,
      HiveKeys.lastLoginAt,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<AuthSession?> readSession() async {
    final token = await _secure.accessToken;
    if (token == null || token.isEmpty) return null;
    final expiryRaw = await _secure.read(SecureKeys.accessTokenExpiry);
    return AuthSession(
      accessToken: token,
      refreshToken: await _secure.refreshToken,
      expiresAt: expiryRaw == null ? null : DateTime.tryParse(expiryRaw),
      sessionId: await _secure.read(SecureKeys.sessionId),
    );
  }

  @override
  Future<void> writeSession(AuthSession session) => _secure.saveSession(
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
    expiresAt: session.expiresAt,
    sessionId: session.sessionId,
  );

  @override
  Future<String?> readAccessToken() => _secure.accessToken;

  @override
  Future<DateTime?> readLockedUntil() async {
    final value = _local.read(HiveBoxes.auth, HiveKeys.lockedUntil);
    if (value is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  @override
  Future<String?> readLockedIdentifier() async {
    final value = _local.read(HiveBoxes.auth, HiveKeys.lockedIdentifier);
    return value is String && value.isNotEmpty ? value : null;
  }

  @override
  Future<void> writeLockedUntil(DateTime until, {String? identifier}) async {
    await _local.write(
      HiveBoxes.auth,
      HiveKeys.lockedUntil,
      until.millisecondsSinceEpoch,
    );
    if (identifier == null) {
      await _local.delete(HiveBoxes.auth, HiveKeys.lockedIdentifier);
    } else {
      await _local.write(HiveBoxes.auth, HiveKeys.lockedIdentifier, identifier);
    }
  }

  @override
  Future<void> clearLockout() async {
    await _local.delete(HiveBoxes.auth, HiveKeys.lockedUntil);
    await _local.delete(HiveBoxes.auth, HiveKeys.lockedIdentifier);
  }

  @override
  Future<void> clear() async {
    // Credentials first: if anything below fails, the token is already gone.
    await _secure.deleteAll();
    await HiveInit.clearOnLogout();
    // Not awaited: sign-out must not wait on the file system (and the
    // files are deleted moments later either way).
    unawaited(SessionFiles.clear());
    AppLogger.info('Auth local state cleared', name: 'auth');
  }
}
