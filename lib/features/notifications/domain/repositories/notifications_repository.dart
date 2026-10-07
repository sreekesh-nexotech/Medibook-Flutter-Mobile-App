import '../../../../core/network/models/page.dart';
import '../../../../core/storage/cache/cached_result.dart';
import '../entities/notification.dart';
import '../entities/push_device.dart';

/// The notifications contract (`FLUTTER_API_INTEGRATION.md` §12).
///
/// **Error contract:** every method throws a `Failure` — `NotFoundFailure`
/// for an id that is not the user's, `NetworkFailure` / `TimeoutFailure`
/// when offline — never a raw exception.
abstract interface class NotificationsRepository {
  // ---- List (§12.1) ----

  /// One page, newest first; the cached copy first, then the network.
  Stream<CachedResult<Page<PatientNotification>>> watchList(
    NotificationListQuery query, {
    int page = 1,
    int? pageSize,
    bool forceRefresh = false,
  });

  /// One-shot form of [watchList].
  Future<Page<PatientNotification>> fetchList(
    NotificationListQuery query, {
    int page = 1,
    int? pageSize,
    bool forceRefresh = false,
  });

  // ---- Read state (§12.2–12.5) ----

  /// `GET /patient/notifications/unread-count` — always the network.
  Future<int> unreadCount();

  Future<PatientNotification> markRead(String id);

  Future<PatientNotification> markUnread(String id);

  /// Returns how many actually changed (`updated_count`).
  Future<int> markAllRead();

  /// `DELETE /patient/notifications/{id}` → 204.
  Future<void> dismiss(String id);

  // ---- Push devices (§12.6) ----

  /// Register (or refresh) this device's push token. 201 new / 200 known.
  Future<PushDevice> registerDevice({
    required DevicePlatform platform,
    required String pushToken,
    String? appVersion,
    String? osVersion,
  });

  /// `DELETE /patient/me/devices/{id}` — call on logout.
  Future<void> deleteDevice(String id);

  /// The device id this install registered, if any (local only).
  Future<String?> registeredDeviceId();

  /// Forget every cached notification read.
  Future<void> invalidate();
}
