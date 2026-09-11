import '../../../../../app/bootstrap/hive_init.dart';
import '../../../../../core/storage/hive/boxes.dart';
import '../../../../../core/storage/hive/keys.dart';
import '../../../../../core/storage/secure_store.dart';
import '../../../../../core/utils/logger.dart';
import '../../../domain/entities/user.dart';

/// Local persistence for the auth feature.
///
/// Splits cleanly in two, and the split is the security boundary:
/// * **Credentials** ([AuthSession]) go to [SecureStore] — the platform
///   keystore. Never Hive, never a preference file (Coding Standards §9).
/// * **Non-secret session metadata** (user id, display name, the CM-05
///   attempt counter and lockout deadline) goes to the `auth` Hive box, where
///   it is cheap to read at startup.
///
/// The lockout state is stored here rather than held in memory on purpose:
/// an in-memory counter is defeated by force-quitting the app, which would
/// make CM-05 decorative.
abstract interface class AuthLocalDataSource {
  /// The cached user, or null.
  Future<User?> readUser();

  /// Cache [user] (non-secret fields only).
  Future<void> writeUser(User user);

  /// The stored session, or null.
  Future<AuthSession?> readSession();

  /// Persist [session] to secure storage.
  Future<void> writeSession(AuthSession session);

  /// Failed sign-in attempts recorded on this device.
  Future<int> readFailedAttempts();

  /// Increment and return the new count.
  Future<int> incrementFailedAttempts();

  /// The active lockout deadline, or null.
  Future<DateTime?> readLockedUntil();

  /// Start a lockout ending at [until].
  Future<void> writeLockedUntil(DateTime until);

  /// Reset the counter and clear any lockout.
  Future<void> clearFailedAttempts();

  /// Erase everything: credentials, cached user and session boxes.
  ///
  /// This is the local half of CM-53 — after this, nothing about the previous
  /// patient remains on the device.
  Future<void> clear();
}

/// The in-memory-plus-store implementation the app runs on today.
///
/// It is *real* code against the two storage interfaces, not a placeholder:
/// point [SecureStore] at the keystore implementation and [HiveInit.store] at
/// Hive, and this class becomes production-correct with no edits.
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl({SecureStore? secureStore})
    : _secure = secureStore ?? InMemorySecureStore();

  final SecureStore _secure;

  LocalStore get _local => HiveInit.store;

  @override
  Future<User?> readUser() async {
    final id = _local.read(HiveBoxes.auth, HiveKeys.userId);
    if (id is! String || id.isEmpty) return null;
    final name = _local.read(HiveBoxes.auth, HiveKeys.userDisplayName);
    final phone = _local.read(HiveBoxes.auth, HiveKeys.userPhone);
    return User(
      id: id,
      name: name is String ? name : '',
      // Email is not cached — it is PII with no startup value. The `/me`
      // refresh fills it in.
      email: '',
      phone: phone is String ? phone : null,
    );
  }

  @override
  Future<void> writeUser(User user) async {
    await _local.write(HiveBoxes.auth, HiveKeys.userId, user.id);
    await _local.write(HiveBoxes.auth, HiveKeys.userDisplayName, user.name);
    await _local.write(HiveBoxes.auth, HiveKeys.userPhone, user.phone);
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
    );
  }

  @override
  Future<void> writeSession(AuthSession session) => _secure.saveSession(
    accessToken: session.accessToken,
    refreshToken: session.refreshToken,
    expiresAt: session.expiresAt,
  );

  @override
  Future<int> readFailedAttempts() async {
    final value = _local.read(HiveBoxes.auth, HiveKeys.failedLoginAttempts);
    return value is int ? value : 0;
  }

  @override
  Future<int> incrementFailedAttempts() async {
    final next = await readFailedAttempts() + 1;
    await _local.write(HiveBoxes.auth, HiveKeys.failedLoginAttempts, next);
    return next;
  }

  @override
  Future<DateTime?> readLockedUntil() async {
    final value = _local.read(HiveBoxes.auth, HiveKeys.lockedUntil);
    if (value is! int) return null;
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  @override
  Future<void> writeLockedUntil(DateTime until) => _local.write(
    HiveBoxes.auth,
    HiveKeys.lockedUntil,
    until.millisecondsSinceEpoch,
  );

  @override
  Future<void> clearFailedAttempts() async {
    await _local.delete(HiveBoxes.auth, HiveKeys.failedLoginAttempts);
    await _local.delete(HiveBoxes.auth, HiveKeys.lockedUntil);
  }

  @override
  Future<void> clear() async {
    // Credentials first: if anything below fails, the token is already gone.
    await _secure.deleteAll();
    await HiveInit.clearOnLogout();
    AppLogger.info('Auth local state cleared', name: 'auth');
  }
}
