import '../../../../app/config/constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart' show Page;
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../domain/entities/notification.dart';
import '../../domain/entities/push_device.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../data_sources/local/push_device_local_ds.dart';
import '../data_sources/remote/notifications_api.dart';

/// [NotificationsRepository] over [NotificationsApi] + [CachedFetcher] +
/// [PushDeviceLocalDataSource].
///
/// The list goes through the three-layer cache; the unread count and every
/// read-state change hit the network (a stale badge is worse than a slow
/// one) and invalidate the cached list afterwards. Every throw is a
/// `Failure`.
class NotificationsRepositoryImpl implements NotificationsRepository {
  const NotificationsRepositoryImpl({
    required NotificationsApi api,
    required CachedFetcher fetcher,
    required PushDeviceLocalDataSource local,
  }) : _api = api,
       _fetcher = fetcher,
       _local = local;

  final NotificationsApi _api;
  final CachedFetcher _fetcher;
  final PushDeviceLocalDataSource _local;

  @override
  Stream<CachedResult<Page<PatientNotification>>> watchList(
    NotificationListQuery query, {
    int page = 1,
    int? pageSize,
    bool forceRefresh = false,
  }) => _guardStream(
    _fetcher.fetch(
      _api.listRequest(
        query,
        page: page,
        pageSize: pageSize ?? AppConstants.defaultPageSize,
      ),
      NotificationMappers.page,
      forceRefresh: forceRefresh,
    ),
  );

  @override
  Future<Page<PatientNotification>> fetchList(
    NotificationListQuery query, {
    int page = 1,
    int? pageSize,
    bool forceRefresh = false,
  }) => _guard(
    () => _fetcher.get(
      _api.listRequest(
        query,
        page: page,
        pageSize: pageSize ?? AppConstants.defaultPageSize,
      ),
      NotificationMappers.page,
      forceRefresh: forceRefresh,
    ),
  );

  @override
  Future<int> unreadCount() => _guard(() async {
    final request = _api.unreadCountRequest();
    int decode(Object? json) =>
        NotificationMappers.count(_asMap(json), 'unread_count');
    try {
      // Always asked of the server while online; the answer is saved.
      return await _fetcher.get(request, decode, forceRefresh: true);
    } on Failure catch (failure) {
      if (failure is! NetworkFailure && failure is! TimeoutFailure) rethrow;
      // Offline: the last count the server gave, so the bell does not read
      // "no unread" when there are some (BL-CACHE-010, -019).
      return _fetcher.get(request, decode);
    }
  });

  static Map<String, Object?> _asMap(Object? json) {
    if (json is Map<String, Object?>) return json;
    if (json is Map) return json.cast<String, Object?>();
    throw const ResponseFormatException(message: 'unread-count: not an object');
  }

  @override
  Future<PatientNotification> markRead(String id) => _guard(() async {
    final json = await _api.markRead(id);
    await invalidate();
    return NotificationMappers.notification(json);
  });

  @override
  Future<PatientNotification> markUnread(String id) => _guard(() async {
    final json = await _api.markUnread(id);
    await invalidate();
    return NotificationMappers.notification(json);
  });

  @override
  Future<int> markAllRead() => _guard(() async {
    final json = await _api.markAllRead();
    await invalidate();
    return NotificationMappers.count(json, 'updated_count');
  });

  @override
  Future<void> dismiss(String id) => _guard(() async {
    await _api.dismiss(id);
    await invalidate();
  });

  @override
  Future<PushDevice> registerDevice({
    required DevicePlatform platform,
    required String pushToken,
    String? appVersion,
    String? osVersion,
  }) => _guard(() async {
    final json = await _api.registerDevice(
      platform: platform,
      pushToken: pushToken,
      appVersion: appVersion,
      osVersion: osVersion,
    );
    final device = NotificationMappers.device(json);
    await _local.writeDeviceId(device.id);
    return device;
  });

  @override
  Future<void> deleteDevice(String id) => _guard(() async {
    try {
      await _api.deleteDevice(id);
    } finally {
      // The device forgetting the registration is the requirement; the
      // server forgetting it is best effort (the session is ending anyway).
      await _local.clear();
    }
  });

  @override
  Future<String?> registeredDeviceId() => _local.readDeviceId();

  @override
  Future<void> invalidate() =>
      _fetcher.invalidate(pathPrefix: Endpoints.notifications);

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        NetworkExceptions.toFailure(error, stackTrace),
        stackTrace,
      );
    }
  }

  Stream<T> _guardStream<T>(Stream<T> source) async* {
    try {
      yield* source;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        NetworkExceptions.toFailure(error, stackTrace),
        stackTrace,
      );
    }
  }
}

/// JSON → entity for §12. The only place the wire field names are spelled;
/// a malformed row throws a [ResponseFormatException] so it is never cached.
abstract final class NotificationMappers {
  NotificationMappers._();

  static PatientNotification notification(Map<String, Object?> json) {
    final id = json['id'];
    final title = json['title'];
    final createdAt = _instant(json['created_at']);
    if (id is! String || id.isEmpty || title is! String || createdAt == null) {
      throw const ResponseFormatException(
        message: 'notification is missing id / title / created_at',
      );
    }
    final rawData = json['data'];
    final data = rawData is Map
        ? rawData.cast<String, Object?>()
        : const <String, Object?>{};
    return PatientNotification(
      id: id,
      kind: NotificationKind.fromWire(json['kind'] as String?),
      title: title,
      body: json['body'] as String? ?? '',
      event: data['event'] as String? ?? '',
      createdAt: createdAt,
      readAt: _instant(json['read_at']),
      hospitalId: json['hospital_id'] as String?,
      appointmentId: data['appointment_id'] as String?,
      refundId: data['refund_id'] as String?,
      ticketId: data['ticket_id'] as String?,
      personId: data['person_id'] as String?,
      dsrId: data['dsr_id'] as String?,
    );
  }

  static Page<PatientNotification> page(Object? body) =>
      Page.parse(body, notification);

  static int count(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is num) return value.toInt();
    throw ResponseFormatException(message: 'missing "$key"');
  }

  static PushDevice device(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const ResponseFormatException(message: 'device has no id');
    }
    final platform = json['platform'] as String?;
    return PushDevice(
      id: id,
      platform: DevicePlatform.values.firstWhere(
        (p) => p.wire == platform,
        orElse: () => DevicePlatform.android,
      ),
      pushToken: json['push_token'] as String? ?? '',
      appVersion: json['app_version'] as String?,
      osVersion: json['os_version'] as String?,
      lastSeenAt: _instant(json['last_seen_at']),
      createdAt: _instant(json['created_at']),
    );
  }

  static DateTime? _instant(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}
