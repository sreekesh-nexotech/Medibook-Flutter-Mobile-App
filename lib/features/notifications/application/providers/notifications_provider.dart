import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener, FlutterError;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/env.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart' show Page;
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/network_exceptions.dart'
    show NetworkExceptions;
import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../core/network/realtime/ws_client.dart';
import '../../../../core/network/realtime/ws_session.dart';
import '../../../../core/storage/cache/cached_fetcher.dart';
import '../../../../core/utils/logger.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../domain/entities/notification.dart';
import '../../domain/entities/push_device.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../states/notifications_state.dart';

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------

/// The notifications repository — the abstract type, so tests can
/// `overrideWithValue(FakeNotificationsRepository())`.
final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => throw UnimplementedError(
    'notificationsRepositoryProvider is wired in app/di',
  ),
);

/// The session as the inbox socket sees it: the token it presents, and a
/// refresh that is skipped when the API client has already replaced it.
final inboxWsSessionProvider = Provider<WsSession>(
  (ref) => WsSession(
    accessToken: () => ref.read(authRepositoryProvider).accessToken(),
    refresh: () async {
      await ref.read(authRepositoryProvider).refreshSession();
    },
  ),
);

/// Builds a [WsClient] for a `/ws/patient/…` path. Overridden in tests.
final inboxSocketFactoryProvider = Provider<WsClient Function(String path)>(
  (ref) =>
      (path) => WsClient(
        url: '${Env.wsBaseUrl}$path',
        accessToken: () => ref.read(inboxWsSessionProvider).accessToken(),
        allowBadCertificate: Env.allowBadCertificate && !Env.isProd,
      ),
);

// ---------------------------------------------------------------------------
// List (§12.1–12.5)
// ---------------------------------------------------------------------------

/// Owns one filtered, paginated notifications list and the per-row read /
/// unread / dismiss mutations, which update the row in place from the
/// server's answer (never optimistically).
class NotificationsListController
    extends StateNotifier<NotificationsListState> {
  NotificationsListController({
    required NotificationsRepository repository,
    required NotificationListQuery query,
  }) : _repository = repository,
       _query = query,
       super(const NotificationsListState()) {
    load();
  }

  final NotificationsRepository _repository;
  final NotificationListQuery _query;

  /// Every page-1 subscription still open. A reload does **not** cancel the
  /// previous one outright: cancelling an `async*` stream before its first
  /// event orphans any error it then throws as an unhandled exception, so a
  /// superseded subscription is instead ignored (see [_generation]) and
  /// cancelled at its next safe point — its first event, error or done.
  final Set<StreamSubscription<CachedResult<Page<PatientNotification>>>> _open =
      {};

  /// Bumped on every [load]; events from an older generation are ignored.
  int _generation = 0;

  /// (Re)load page 1; completes once the freshest answer has arrived.
  Future<void> load({bool forceRefresh = false}) {
    final generation = ++_generation;
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    late final StreamSubscription<CachedResult<Page<PatientNotification>>>
    subscription;
    void retire() {
      if (_open.remove(subscription)) unawaited(subscription.cancel());
    }

    state = state.copyWith(
      isLoading: state.items.isEmpty,
      revalidating: state.items.isNotEmpty,
      clearFailure: true,
      clearLoadMoreFailure: true,
    );
    subscription = _repository
        .watchList(_query, page: 1, forceRefresh: forceRefresh)
        .listen(
          (result) {
            if (!mounted || generation != _generation) {
              retire();
              return finish();
            }
            final page = result.value;
            state = state.copyWith(
              items: page.results,
              page: page.page,
              hasNext: page.hasNext,
              total: page.total,
              isLoading: false,
              revalidating: result.revalidating,
              isStale: result.isStale,
              source: result.source,
              cachedAt: result.cachedAt,
              clearFailure: true,
            );
            if (!result.revalidating) finish();
          },
          onError: (Object error, StackTrace stackTrace) {
            _open.remove(subscription);
            if (mounted && generation == _generation) {
              state = state.copyWith(
                isLoading: false,
                revalidating: false,
                failure: NetworkExceptions.toFailure(error, stackTrace),
              );
            }
            finish();
          },
          onDone: () {
            _open.remove(subscription);
            if (mounted && generation == _generation && state.revalidating) {
              state = state.copyWith(revalidating: false);
            }
            finish();
          },
        );
    _open.add(subscription);
    return done.future;
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasNext || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreFailure: true);
    try {
      final next = await _repository.fetchList(_query, page: state.page + 1);
      if (!mounted) return;
      state = state.copyWith(
        items: [...state.items, ...next.results],
        page: next.page,
        hasNext: next.hasNext,
        total: next.total,
        isLoadingMore: false,
      );
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreFailure: NetworkExceptions.toFailure(error, stackTrace),
      );
    }
  }

  /// `POST /{id}/read`. Returns the failure, or null.
  Future<Failure?> markRead(String id) =>
      _mutate(id, () => _repository.markRead(id));

  /// `POST /{id}/unread`.
  Future<Failure?> markUnread(String id) =>
      _mutate(id, () => _repository.markUnread(id));

  /// `DELETE /{id}` — the row leaves the list only once the server agreed.
  Future<Failure?> dismiss(String id) async {
    if (state.busyIds.contains(id)) return null;
    state = state.copyWith(busyIds: {...state.busyIds, id});
    try {
      await _repository.dismiss(id);
      if (!mounted) return null;
      state = state.copyWith(
        items: [
          for (final item in state.items)
            if (item.id != id) item,
        ],
        total: state.total > 0 ? state.total - 1 : 0,
      );
      return null;
    } catch (error, stackTrace) {
      return NetworkExceptions.toFailure(error, stackTrace);
    } finally {
      if (mounted) {
        state = state.copyWith(busyIds: {...state.busyIds}..remove(id));
      }
    }
  }

  /// `POST read-all`. Returns how many changed, or null with the failure.
  Future<({int? updated, Failure? failure})> markAllRead() async {
    try {
      final updated = await _repository.markAllRead();
      if (mounted) {
        final now = DateTime.now().toUtc();
        final items = [
          for (final item in state.items)
            item.unread ? item.copyWith(readAt: now) : item,
        ];
        final kept = [
          for (final item in items)
            if (_matches(item)) item,
        ];
        state = state.copyWith(
          items: kept,
          total: state.total - (items.length - kept.length),
        );
      }
      return (updated: updated, failure: null);
    } catch (error, stackTrace) {
      return (
        updated: null,
        failure: NetworkExceptions.toFailure(error, stackTrace),
      );
    }
  }

  /// Whether [item] still belongs in this list's read/unread filter.
  bool _matches(PatientNotification item) => switch (_query.unread) {
    true => item.unread,
    false => !item.unread,
    null => true,
  };

  Future<Failure?> _mutate(
    String id,
    Future<PatientNotification> Function() operation,
  ) async {
    if (state.busyIds.contains(id)) return null;
    state = state.copyWith(busyIds: {...state.busyIds, id});
    try {
      final updated = await operation();
      if (!mounted) return null;
      // On the Unread tab a read notification no longer belongs (and on a
      // read-only view an unread one): it leaves at once rather than on the
      // next reload (BL-NOTIF-009).
      final stillMatches = _matches(updated);
      state = state.copyWith(
        items: [
          for (final item in state.items)
            if (item.id != updated.id) item else if (stillMatches) updated,
        ],
        total: stillMatches || state.total == 0 ? state.total : state.total - 1,
      );
      return null;
    } catch (error, stackTrace) {
      return NetworkExceptions.toFailure(error, stackTrace);
    } finally {
      if (mounted) {
        state = state.copyWith(busyIds: {...state.busyIds}..remove(id));
      }
    }
  }

  @override
  void dispose() {
    for (final subscription in _open) {
      unawaited(subscription.cancel());
    }
    _open.clear();
    super.dispose();
  }
}

/// One list per filter. autoDispose family — the screen's own state.
final notificationsListProvider = StateNotifierProvider.autoDispose
    .family<
      NotificationsListController,
      NotificationsListState,
      NotificationListQuery
    >(
      (ref, query) => NotificationsListController(
        repository: ref.watch(notificationsRepositoryProvider),
        query: query,
      ),
    );

// ---------------------------------------------------------------------------
// Inbox: the bell badge (§12.2 + §15.2)
// ---------------------------------------------------------------------------

/// Owns the unread count for the whole app: `GET unread-count` once, then
/// the `/ws/patient/inbox` socket's `unread_count` frames. Reconnects with a
/// fresh token on 4401, with backoff on any other drop, and stops when it
/// is disposed (sign-out rebuilds the provider without it).
class InboxController extends StateNotifier<InboxState> {
  InboxController({
    required NotificationsRepository repository,
    required WsClient Function(String path) openSocket,
    required Future<void> Function() refreshSession,
    required bool enabled,
  }) : _repository = repository,
       _openSocket = openSocket,
       _refreshSession = refreshSession,
       super(const InboxState()) {
    if (enabled) {
      unawaited(refresh());
      unawaited(_connect());
    }
  }

  static const int maxReconnects = 8;

  final NotificationsRepository _repository;
  final WsClient Function(String path) _openSocket;
  final Future<void> Function() _refreshSession;

  WsClient? _socket;
  StreamSubscription<WsFrame>? _frames;
  StreamSubscription<WsCloseReason>? _closed;
  Timer? _reconnectTimer;
  int _drops = 0;

  /// True once a handshake was refused even with a freshly refreshed token.
  bool _refusedWithFreshToken = false;
  bool _disposed = false;

  /// The app is in the background: no socket and no reconnect timer
  /// (CL PERF-008 — the server drops idle sockets every few seconds and the
  /// backgrounded app kept reconnecting).
  bool _paused = false;

  /// True once the socket has been down: whatever it would have pushed in
  /// the gap is gone, so the next successful connect re-reads the count.
  bool _missedFrames = false;

  /// Re-read `GET /patient/notifications/unread-count`.
  Future<void> refresh() async {
    try {
      final count = await _repository.unreadCount();
      if (mounted) {
        state = state.copyWith(unreadCount: count, clearFailure: true);
      }
    } catch (error, stackTrace) {
      if (mounted) {
        state = state.copyWith(
          failure: NetworkExceptions.toFailure(error, stackTrace),
        );
      }
    }
  }

  /// The device is back online: re-read the count now and, if the socket is
  /// down (its retries may have run out while offline), open it again.
  void resume() {
    if (_disposed) return;
    _paused = false;
    unawaited(refresh());
    if (!state.isLive) {
      _reconnectTimer?.cancel();
      _drops = 0;
      unawaited(_connect());
    }
  }

  /// The app went to the background: close the socket and stop retrying
  /// until [resume]. Whatever it would have pushed meanwhile is re-read then.
  void pause() {
    if (_disposed || _paused) return;
    _paused = true;
    _reconnectTimer?.cancel();
    _missedFrames = true;
    unawaited(_teardownSocket());
    if (mounted) state = state.copyWith(isLive: false);
  }

  /// The list screen tells the inbox what it changed, so the badge follows
  /// without a round trip (the socket confirms shortly after).
  void adjust(int delta) {
    final next = state.unreadCount + delta;
    state = state.copyWith(unreadCount: next < 0 ? 0 : next);
  }

  void setCount(int count) => state = state.copyWith(unreadCount: count);

  Future<void> _connect({bool withFreshToken = false}) async {
    if (_disposed || _paused) return;
    if (withFreshToken) {
      try {
        await _refreshSession();
      } catch (error) {
        AppLogger.warning(
          'Inbox: token refresh failed; badge stays on REST',
          name: 'notifications',
          error: error,
        );
        return;
      }
      if (_disposed) return;
    }
    await _teardownSocket();
    final socket = _openSocket(Endpoints.wsInbox);
    _socket = socket;
    _frames = socket.frames.listen(_onFrame);
    _closed = socket.closed.listen(_onClosed);
    try {
      await socket.connect();
      // Frames sent while the socket was down are not replayed, and a count
      // that failed to load (a cold start offline) is still unknown: re-read
      // it whenever the connection comes back after a gap.
      final resync = _missedFrames || state.failure != null;
      _missedFrames = false;
      _drops = 0;
      _refusedWithFreshToken = false;
      if (mounted) state = state.copyWith(isLive: true);
      if (resync) unawaited(refresh());
    } catch (error) {
      AppLogger.warning(
        'Inbox socket refused',
        name: 'notifications',
        error: error,
      );
      _missedFrames = true;
      // A refused handshake is how the server answers an expired token
      // (HTTP 403, never a 4401 close): one retry with a fresh token before
      // falling back to the backoff.
      if (error is WsHandshakeRefused) {
        if (withFreshToken) {
          // Refused with a brand-new token too: the token is not the reason,
          // so the later retries must not refresh again (BL-QUEUE-015).
          _refusedWithFreshToken = true;
        } else if (!_refusedWithFreshToken) {
          unawaited(_connect(withFreshToken: true));
          return;
        }
      }
      _scheduleReconnect();
    }
  }

  void _onFrame(WsFrame frame) {
    if (!mounted) return;
    switch (frame.type) {
      case 'unread_count':
        final n = frame.data['n'];
        if (n is num) state = state.copyWith(unreadCount: n.toInt());
      case 'notification.created':
        final id = frame.data['id'];
        state = state.copyWith(
          lastCreatedId: id is String ? id : null,
          // The badge is authoritative from the next `unread_count`; until
          // then a new notification is, by definition, unread.
          unreadCount: state.unreadCount + 1,
        );
    }
  }

  void _onClosed(WsCloseReason reason) {
    if (_disposed) return;
    _missedFrames = true;
    if (mounted) state = state.copyWith(isLive: false);
    switch (reason) {
      case WsCloseReason.unauthorized:
        unawaited(_connect(withFreshToken: true));
      case WsCloseReason.idle:
      case WsCloseReason.other:
        _scheduleReconnect();
      case WsCloseReason.local:
        break;
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _paused) return;
    _drops++;
    if (_drops > maxReconnects) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      NetworkExceptions.backoffFor(_drops + 1),
      () => unawaited(_connect()),
    );
  }

  Future<void> _teardownSocket() async {
    await _frames?.cancel();
    await _closed?.cancel();
    _frames = null;
    _closed = null;
    final socket = _socket;
    _socket = null;
    await socket?.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    unawaited(_teardownSocket());
    super.dispose();
  }
}

/// The inbox for the signed-in user. **Not** autoDispose: the bell badge in
/// the Home header outlives every screen. Rebuilt (and the socket closed)
/// whenever the session changes.
final inboxProvider = StateNotifierProvider<InboxController, InboxState>((ref) {
  final enabled = ref.watch(isAuthenticatedProvider);
  final controller = InboxController(
    repository: ref.watch(notificationsRepositoryProvider),
    openSocket: ref.watch(inboxSocketFactoryProvider),
    refreshSession: () => ref.read(inboxWsSessionProvider).refreshIfStale(),
    enabled: enabled,
  );
  if (enabled) {
    // In the background the socket is closed and nothing retries; it comes
    // back (and the count is re-read) when the app returns (CL PERF-008).
    try {
      final lifecycle = AppLifecycleListener(
        onHide: controller.pause,
        onShow: controller.resume,
      );
      ref.onDispose(lifecycle.dispose);
    } on FlutterError {
      // No widgets binding (a plain unit test): nothing to follow.
    }
    // HIVE Scenario 3: no polling while offline — one retry when the
    // connectivity stream reports the network is back.
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (previous, next) {
      if (previous?.valueOrNull == false && next.valueOrNull == true) {
        controller.resume();
      }
    });
  }
  return controller;
});

/// Unread count for the bell badge (`GET unread-count` + `/ws/patient/inbox`
/// `unread_count` frames). A narrow provider so the header rebuilds only
/// when the count changes.
///
/// Read by the dashboard header in place of the former
/// the pre-integration seed provider of the same name (now removed).
final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref.watch(inboxProvider.select((s) => s.unreadCount)),
);

// ---------------------------------------------------------------------------
// Push devices (§12.6)
// ---------------------------------------------------------------------------

/// Registers this install's push token after login and removes it on
/// logout. Token *acquisition* is not wired: there is no FCM SDK in the
/// stack (see `docs/integration-gaps/appointments-notifications.md`).
class PushDeviceController extends StateNotifier<PushDeviceState> {
  PushDeviceController({required NotificationsRepository repository})
    : _repository = repository,
      super(const PushDeviceState()) {
    unawaited(_restore());
  }

  final NotificationsRepository _repository;

  Future<void> _restore() async {
    final id = await _repository.registeredDeviceId();
    if (mounted && id != null) state = state.copyWith(deviceId: id);
  }

  /// `POST /patient/me/devices`. Returns the failure, or null.
  Future<Failure?> register({
    required DevicePlatform platform,
    required String pushToken,
    String? appVersion,
    String? osVersion,
  }) async {
    if (state.isBusy) return null;
    state = state.copyWith(isBusy: true, clearFailure: true);
    try {
      final device = await _repository.registerDevice(
        platform: platform,
        pushToken: pushToken,
        appVersion: appVersion,
        osVersion: osVersion,
      );
      if (mounted) state = state.copyWith(deviceId: device.id);
      return null;
    } catch (error, stackTrace) {
      final failure = NetworkExceptions.toFailure(error, stackTrace);
      if (mounted) state = state.copyWith(failure: failure);
      return failure;
    } finally {
      if (mounted) state = state.copyWith(isBusy: false);
    }
  }

  /// `DELETE /patient/me/devices/{id}` for this install — call **before**
  /// the session is cleared, while the bearer is still valid.
  Future<Failure?> unregister() async {
    final id = state.deviceId ?? await _repository.registeredDeviceId();
    if (id == null) return null;
    try {
      await _repository.deleteDevice(id);
      if (mounted) state = state.copyWith(clearDeviceId: true);
      return null;
    } catch (error, stackTrace) {
      final failure = NetworkExceptions.toFailure(error, stackTrace);
      // Local registration is cleared regardless (see the repository).
      if (mounted) {
        state = state.copyWith(clearDeviceId: true, failure: failure);
      }
      return failure;
    }
  }
}

/// This install's push registration. Not autoDispose — app-lifetime.
final pushDeviceProvider =
    StateNotifierProvider<PushDeviceController, PushDeviceState>(
      (ref) => PushDeviceController(
        repository: ref.watch(notificationsRepositoryProvider),
      ),
    );
