/// `Device.platform` (§17).
enum DevicePlatform {
  android('android'),
  ios('ios'),
  web('web');

  const DevicePlatform(this.wire);

  final String wire;
}

/// A registered push device (§12.6). [id] is also the optional `device_id`
/// on the login calls.
class PushDevice {
  const PushDevice({
    required this.id,
    required this.platform,
    required this.pushToken,
    this.appVersion,
    this.osVersion,
    this.lastSeenAt,
    this.createdAt,
  });

  final String id;
  final DevicePlatform platform;
  final String pushToken;
  final String? appVersion;
  final String? osVersion;
  final DateTime? lastSeenAt;
  final DateTime? createdAt;
}
