import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/endpoints.dart';
import '../../../domain/entities/notification.dart';
import '../../../domain/entities/push_device.dart';

/// The notification and push-device endpoints (§12), as a typed remote data
/// source: the list as an [ApiRequest] for the cache, everything else over
/// [ApiClient]. No caching, no mapping, no `try`/`catch`.
abstract interface class NotificationsApi {
  /// `GET /patient/notifications` with `unread` / `kind` only (§12.1).
  ApiRequest listRequest(
    NotificationListQuery query, {
    required int page,
    required int pageSize,
  });

  /// `GET /patient/notifications/unread-count` → `{unread_count}`.
  ApiRequest unreadCountRequest();

  /// `POST /patient/notifications/{id}/read` → Notification.
  Future<Map<String, Object?>> markRead(String id);

  /// `POST /patient/notifications/{id}/unread` → Notification.
  Future<Map<String, Object?>> markUnread(String id);

  /// `POST /patient/notifications/read-all` → `{updated_count}`.
  Future<Map<String, Object?>> markAllRead();

  /// `DELETE /patient/notifications/{id}` → 204.
  Future<void> dismiss(String id);

  /// `POST /patient/me/devices` → Device (201 new, 200 known).
  Future<Map<String, Object?>> registerDevice({
    required DevicePlatform platform,
    required String pushToken,
    String? appVersion,
    String? osVersion,
  });

  /// `DELETE /patient/me/devices/{id}` → 204.
  Future<void> deleteDevice(String id);
}

/// [NotificationsApi] over the [ApiClient] interface.
class HttpNotificationsApi implements NotificationsApi {
  const HttpNotificationsApi(this._client);

  final ApiClient _client;

  @override
  ApiRequest listRequest(
    NotificationListQuery query, {
    required int page,
    required int pageSize,
  }) => ApiRequest(
    path: Endpoints.notifications,
    query: {
      ...Endpoints.page(page, size: pageSize),
      'unread': query.unread,
      'kind': query.kinds.isEmpty
          ? null
          : query.kinds.map((k) => k.wire).join(','),
    },
  );

  @override
  ApiRequest unreadCountRequest() =>
      const ApiRequest(path: Endpoints.notificationsUnreadCount);

  @override
  Future<Map<String, Object?>> markRead(String id) async {
    final response = await _client.post(Endpoints.notificationRead(id));
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> markUnread(String id) async {
    final response = await _client.post(Endpoints.notificationUnread(id));
    return response.requireMap;
  }

  @override
  Future<Map<String, Object?>> markAllRead() async {
    final response = await _client.post(Endpoints.notificationsReadAll);
    return response.requireMap;
  }

  @override
  Future<void> dismiss(String id) => _client.delete(Endpoints.notification(id));

  @override
  Future<Map<String, Object?>> registerDevice({
    required DevicePlatform platform,
    required String pushToken,
    String? appVersion,
    String? osVersion,
  }) async {
    final response = await _client.post(
      Endpoints.devices,
      body: {
        'platform': platform.wire,
        'push_token': pushToken,
        'app_version': ?appVersion,
        'os_version': ?osVersion,
      },
    );
    return response.requireMap;
  }

  @override
  Future<void> deleteDevice(String id) => _client.delete(Endpoints.device(id));
}
