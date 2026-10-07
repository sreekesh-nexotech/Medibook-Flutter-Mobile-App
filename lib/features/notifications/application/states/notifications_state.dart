import '../../../../core/error/failure.dart';
import '../../../../core/storage/cache/cached_fetcher.dart' show CacheSource;
import '../../domain/entities/notification.dart';

/// One paginated notifications list (§12.1) plus its freshness facts.
/// Immutable; every update goes through [copyWith].
class NotificationsListState {
  const NotificationsListState({
    this.items = const <PatientNotification>[],
    this.page = 0,
    this.hasNext = false,
    this.total = 0,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.revalidating = false,
    this.isStale = false,
    this.source,
    this.cachedAt,
    this.failure,
    this.loadMoreFailure,
    this.busyIds = const <String>{},
  });

  final List<PatientNotification> items;
  final int page;
  final bool hasNext;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final bool revalidating;
  final bool isStale;
  final CacheSource? source;
  final DateTime? cachedAt;
  final Failure? failure;
  final Failure? loadMoreFailure;

  /// Ids with a read / unread / dismiss call in flight, so a card cannot
  /// double-fire.
  final Set<String> busyIds;

  bool get hasRowsAndFailure => items.isNotEmpty && failure != null;

  int get unreadInList => items.where((n) => n.unread).length;

  NotificationsListState copyWith({
    List<PatientNotification>? items,
    int? page,
    bool? hasNext,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    bool? revalidating,
    bool? isStale,
    CacheSource? source,
    DateTime? cachedAt,
    Failure? failure,
    bool clearFailure = false,
    Failure? loadMoreFailure,
    bool clearLoadMoreFailure = false,
    Set<String>? busyIds,
  }) {
    return NotificationsListState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      revalidating: revalidating ?? this.revalidating,
      isStale: isStale ?? this.isStale,
      source: source ?? this.source,
      cachedAt: cachedAt ?? this.cachedAt,
      failure: clearFailure ? null : (failure ?? this.failure),
      loadMoreFailure: clearLoadMoreFailure
          ? null
          : (loadMoreFailure ?? this.loadMoreFailure),
      busyIds: busyIds ?? this.busyIds,
    );
  }
}

/// The bell's state: the unread count (from `GET unread-count` and then the
/// inbox socket's `unread_count` frames, §15.2) and whether the socket is up.
class InboxState {
  const InboxState({
    this.unreadCount = 0,
    this.isLive = false,
    this.lastCreatedId,
    this.failure,
  });

  final int unreadCount;

  /// The `/ws/patient/inbox` socket is connected.
  final bool isLive;

  /// The last `notification.created` id — changes when a new one arrives,
  /// so a list on screen can re-fetch.
  final String? lastCreatedId;

  /// The last unread-count fetch failed (the badge keeps its old value).
  final Failure? failure;

  InboxState copyWith({
    int? unreadCount,
    bool? isLive,
    String? lastCreatedId,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return InboxState(
      unreadCount: unreadCount ?? this.unreadCount,
      isLive: isLive ?? this.isLive,
      lastCreatedId: lastCreatedId ?? this.lastCreatedId,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

/// Push-device registration state (§12.6).
class PushDeviceState {
  const PushDeviceState({this.deviceId, this.isBusy = false, this.failure});

  /// The `Device.id` this install holds, once registered.
  final String? deviceId;
  final bool isBusy;
  final Failure? failure;

  PushDeviceState copyWith({
    String? deviceId,
    bool clearDeviceId = false,
    bool? isBusy,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return PushDeviceState(
      deviceId: clearDeviceId ? null : (deviceId ?? this.deviceId),
      isBusy: isBusy ?? this.isBusy,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}
