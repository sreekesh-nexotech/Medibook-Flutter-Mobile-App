import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/notification.dart';

/// The read/unread view of the notifications list (CM-41) — the `unread`
/// query parameter (§12.1).
enum NotificationReadFilter {
  all('All', null),
  unread('Unread', true),
  read('Read', false);

  const NotificationReadFilter(this.label, this.unreadParam);

  final String label;

  /// What `unread=` sends: null for all, true / false otherwise.
  final bool? unreadParam;

  static NotificationReadFilter fromLabel(String label) {
    for (final option in values) {
      if (option.label == label) return option;
    }
    return all;
  }
}

/// The filter set applied to the notifications list: one optional [kind]
/// plus a read/unread view. Both facets are typed and both map straight
/// onto §12.1's query parameters.
class NotificationFilters {
  const NotificationFilters({
    this.kind,
    this.read = NotificationReadFilter.all,
  });

  /// The only kind to show, or null for every kind.
  final NotificationKind? kind;

  final NotificationReadFilter read;

  bool get isActive => kind != null || read != NotificationReadFilter.all;

  /// The request this filter makes.
  NotificationListQuery get query => NotificationListQuery(
    unread: read.unreadParam,
    kinds: kind == null ? const {} : {kind!},
  );

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

  /// Tapping the selected kind again clears it, so the chip row is its own
  /// way back to the full list.
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

/// The screen's filter state. `autoDispose` — transient UI state scoped to
/// the screen, not account data.
final notificationsFilterProvider =
    StateNotifierProvider.autoDispose<
      NotificationsFilterController,
      NotificationFilters
    >((ref) => NotificationsFilterController());

/// The request the current filters make — what the list provider is keyed
/// on.
final notificationsQueryProvider = Provider.autoDispose<NotificationListQuery>(
  (ref) => ref.watch(notificationsFilterProvider).query,
);
