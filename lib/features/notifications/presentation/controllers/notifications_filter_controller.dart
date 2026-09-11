import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/app_notification.dart';
import '../../../../core/mock_data/stores/notifications_store.dart';

/// The read/unread view of the notifications list (CM-41).
enum NotificationReadFilter {
  all('All'),
  unread('Unread'),
  read('Read');

  const NotificationReadFilter(this.label);

  final String label;
}

/// The filter set applied to the notifications list: one optional [kind] plus
/// a read/unread view.
///
/// Both facets are **typed** — a [NotificationKind] and an enum, never a
/// display string — and matching runs against `AppNotification.kind` and
/// `.read`. Sorting is on `createdAt`, never on the rendered `ago` label,
/// which was audit §3.8.3.
class NotificationFilters {
  const NotificationFilters({
    this.kind,
    this.read = NotificationReadFilter.all,
  });

  /// The only kind to show, or null for every kind.
  final NotificationKind? kind;

  final NotificationReadFilter read;

  bool get isActive => kind != null || read != NotificationReadFilter.all;

  /// Whether [notification] survives this filter set.
  bool matches(AppNotification notification) {
    if (kind != null && notification.kind != kind) return false;
    return switch (read) {
      NotificationReadFilter.all => true,
      NotificationReadFilter.unread => notification.unread,
      NotificationReadFilter.read => notification.read,
    };
  }

  /// [clearKind] exists because a null argument cannot distinguish "leave it
  /// alone" from "show every kind".
  NotificationFilters copyWith({
    NotificationKind? kind,
    bool clearKind = false,
    NotificationReadFilter? read,
  }) {
    return NotificationFilters(
      kind: clearKind ? null : (kind ?? this.kind),
      read: read ?? this.read,
    );
  }
}

/// Owns [NotificationFilters] for the Notifications screen. Every mutation
/// produces a new immutable state.
class NotificationsFilterController extends StateNotifier<NotificationFilters> {
  NotificationsFilterController() : super(const NotificationFilters());

  /// Tapping the selected kind again clears it, so the chip row is its own way
  /// back to the full list.
  void toggleKind(NotificationKind kind) {
    state = state.kind == kind
        ? state.copyWith(clearKind: true)
        : state.copyWith(kind: kind);
  }

  void clearKind() => state = state.copyWith(clearKind: true);

  void setRead(NotificationReadFilter read) =>
      state = state.copyWith(read: read);

  void clearAll() => state = const NotificationFilters();
}

/// The screen's filter state. `autoDispose` — transient UI state scoped to the
/// screen, not account data.
final notificationsFilterProvider =
    StateNotifierProvider.autoDispose<
      NotificationsFilterController,
      NotificationFilters
    >((ref) => NotificationsFilterController());

/// The notifications the screen renders: newest first on `createdAt`, with
/// [notificationsFilterProvider] applied. Filtering lives here so the screen
/// only reads state.
final filteredNotificationsProvider =
    Provider.autoDispose<List<AppNotification>>((ref) {
      final items = ref.watch(sortedNotificationsProvider);
      final filters = ref.watch(notificationsFilterProvider);
      if (!filters.isActive) return items;
      return items.where(filters.matches).toList();
    });

/// How many notifications exist per kind, so the chip row can hide a kind the
/// account has none of instead of offering a filter that yields nothing.
final notificationKindCountsProvider =
    Provider.autoDispose<Map<NotificationKind, int>>((ref) {
      final items = ref.watch(notificationsStoreProvider);
      final counts = <NotificationKind, int>{};
      for (final notification in items) {
        counts.update(
          notification.kind,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      return counts;
    });
