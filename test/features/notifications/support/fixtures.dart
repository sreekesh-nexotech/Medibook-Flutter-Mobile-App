import 'dart:async';

import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/api_client.dart' show Page;
import 'package:medibook/core/network/realtime/ws_client.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/notifications/domain/entities/notification.dart';
import 'package:medibook/features/notifications/domain/entities/push_device.dart';
import 'package:medibook/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:medibook/features/notifications/infrastructure/repositories/notifications_repository_impl.dart';

/// Wire shapes captured from the live backend on 2026-09-30 (the
/// cancellation notification raised by the test booking, deleted after).
abstract final class NotificationFixtures {
  NotificationFixtures._();

  static const String id = '01a0f15c-36dd-7d92-bee4-a4ef0494ddaa';
  static const String appointmentId = '01a0f15b-bcf6-7b91-a0eb-2d9a1d7ebacf';

  static Map<String, Object?> json({
    String id = NotificationFixtures.id,
    String kind = 'cancellation',
    String event = 'appointment.cancelled',
    String? readAt,
    Map<String, Object?>? extraData,
  }) => {
    'id': id,
    'kind': kind,
    'title': 'Appointment cancelled',
    'body':
        'Dr. Suresh Pillai on 02 Oct 2026 at 05:00 PM is cancelled. '
        'Ref LKSB-2609-00182.',
    'data': {'event': event, 'appointment_id': appointmentId, ...?extraData},
    'read_at': readAt,
    'hospital_id': '01a0ee28-80b3-7162-9efe-032fb9e1b6af',
    'created_at': '2026-09-30T08:09:07.549780Z',
  };

  static Map<String, Object?> pageJson(
    List<Map<String, Object?>> rows, {
    int page = 1,
    bool hasNext = false,
  }) => {
    'results': rows,
    'page': page,
    'page_size': 25,
    'total': rows.length,
    'has_next': hasNext,
  };

  static PatientNotification notification({
    String id = NotificationFixtures.id,
    String event = 'appointment.cancelled',
    String? readAt,
  }) => NotificationMappers.notification(
    json(id: id, event: event, readAt: readAt),
  );
}

/// An in-memory [NotificationsRepository] a test scripts.
class FakeNotificationsRepository implements NotificationsRepository {
  final List<Page<PatientNotification>> pages = [];
  Failure? listFailure;
  int unreadCountValue = 0;
  Failure? unreadCountFailure;
  int unreadCountCalls = 0;
  Failure? mutationFailure;
  final List<String> readIds = [];
  final List<String> unreadIds = [];
  final List<String> dismissedIds = [];
  int readAllCalls = 0;
  int readAllResult = 0;
  final List<String> registeredTokens = [];
  final List<String> deletedDevices = [];
  String? storedDeviceId;

  @override
  Stream<CachedResult<Page<PatientNotification>>> watchList(
    NotificationListQuery query, {
    int page = 1,
    int? pageSize,
    bool forceRefresh = false,
  }) async* {
    final failure = listFailure;
    if (failure != null) throw failure;
    yield CachedResult(
      value: pages.isEmpty ? const Page.empty() : pages.first,
      source: CacheSource.network,
      cachedAt: DateTime.now(),
    );
  }

  @override
  Future<Page<PatientNotification>> fetchList(
    NotificationListQuery query, {
    int page = 1,
    int? pageSize,
    bool forceRefresh = false,
  }) async => page - 1 < pages.length ? pages[page - 1] : const Page.empty();

  @override
  Future<int> unreadCount() async {
    unreadCountCalls++;
    final failure = unreadCountFailure;
    if (failure != null) throw failure;
    return unreadCountValue;
  }

  @override
  Future<PatientNotification> markRead(String id) async {
    final failure = mutationFailure;
    if (failure != null) throw failure;
    readIds.add(id);
    return NotificationFixtures.notification(
      id: id,
      readAt: '2026-09-30T08:09:50.202353Z',
    );
  }

  @override
  Future<PatientNotification> markUnread(String id) async {
    final failure = mutationFailure;
    if (failure != null) throw failure;
    unreadIds.add(id);
    return NotificationFixtures.notification(id: id);
  }

  @override
  Future<int> markAllRead() async {
    final failure = mutationFailure;
    if (failure != null) throw failure;
    readAllCalls++;
    return readAllResult;
  }

  @override
  Future<void> dismiss(String id) async {
    final failure = mutationFailure;
    if (failure != null) throw failure;
    dismissedIds.add(id);
  }

  @override
  Future<PushDevice> registerDevice({
    required DevicePlatform platform,
    required String pushToken,
    String? appVersion,
    String? osVersion,
  }) async {
    registeredTokens.add(pushToken);
    storedDeviceId = 'dev-1';
    return PushDevice(id: 'dev-1', platform: platform, pushToken: pushToken);
  }

  @override
  Future<void> deleteDevice(String id) async {
    deletedDevices.add(id);
    storedDeviceId = null;
  }

  @override
  Future<String?> registeredDeviceId() async => storedDeviceId;

  @override
  Future<void> invalidate() async {}
}

/// A hand-driven [WsClient] for the inbox channel.
class FakeInboxSocket extends WsClient {
  FakeInboxSocket(String path)
    : path = path,
      super(url: 'wss://test$path', accessToken: () async => 'token');

  final String path;
  final StreamController<WsFrame> _frames = StreamController.broadcast();
  final StreamController<WsCloseReason> _closed = StreamController.broadcast();
  int connectCalls = 0;
  bool disposed = false;

  @override
  Stream<WsFrame> get frames => _frames.stream;

  @override
  Stream<WsCloseReason> get closed => _closed.stream;

  @override
  Future<void> connect() async => connectCalls++;

  void emit(String type, Map<String, Object?> data) =>
      _frames.add(WsFrame(type: type, data: data));

  void close(WsCloseReason reason) => _closed.add(reason);

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> dispose() async {
    disposed = true;
    await _frames.close();
    await _closed.close();
  }
}
