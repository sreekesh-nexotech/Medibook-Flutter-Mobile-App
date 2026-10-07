import 'package:uuid/uuid.dart';

import 'secure_store.dart';

/// The stable per-install id sent as `X-Device-Fingerprint` on every OTP call
/// (`FLUTTER_API_INTEGRATION.md` §1.3).
///
/// The backend binds each OTP code to the fingerprint that requested it, so
/// the value must be identical between `start` and `verify` and must survive
/// a cache wipe — hence it lives in the keystore, not Hive, and is minted
/// once per install. It identifies the device, not the user: sign-out does
/// **not** clear it (`SecureKeys.all` excludes it).
class DeviceIdentity {
  DeviceIdentity(this._store);

  final SecureStore _store;
  static const Uuid _uuid = Uuid();
  String? _cached;

  Future<String> fingerprint() async {
    final cached = _cached;
    if (cached != null) return cached;
    var value = await _store.read(SecureKeys.deviceFingerprint);
    if (value == null || value.isEmpty) {
      value = _uuid.v4();
      await _store.write(SecureKeys.deviceFingerprint, value);
    }
    _cached = value;
    return value;
  }
}
