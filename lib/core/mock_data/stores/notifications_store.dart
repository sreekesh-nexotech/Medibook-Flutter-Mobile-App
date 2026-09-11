import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../medibook_seed.dart';
import '../models/app_notification.dart';

/// Owns the notification list for the whole app.
///
/// **Why this is a shared store rather than a feature controller:** two
/// features read the same records — the Notifications screen renders them, and
/// the Home header's bell badge counts the unread ones. A controller inside
/// `features/notifications/` would leave the badge reading stale seed data.
///
/// This is also the fix for audit §3.1.3 — *"Mark all as read reports success
/// and changes nothing — the notification record has no read flag."* The record
/// has [AppNotification.read] now, and [markAllRead] actually writes it, so the
/// success toast and the UI agree.
///
/// API swap: when the data layer lands this notifier takes a
/// `NotificationRepository` and its methods call it; the seed initialiser goes.
class NotificationsStore extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => MedibookSeed.notifications;

  /// Newest first — the order the screen renders.
  List<AppNotification> get sorted {
    final items = [...state]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// Unread records only.
  List<AppNotification> get unread => state.where((n) => n.unread).toList();

  /// How many are unread — the bell badge.
  int get unreadCount => unread.length;

  /// Mark one record read (opening it from the list).
  void markRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(read: true) else n,
    ];
  }

  /// Mark one record unread again (an undo affordance).
  void markUnread(String id) {
    state = [
      for (final n in state)
        if (n.id == id) n.copyWith(read: false) else n,
    ];
  }

  /// Mark every record read (CM-42).
  ///
  /// Returns how many actually changed, so the caller can say "3 marked as
  /// read" — or say nothing when there was nothing to do — instead of
  /// reporting a success that did not happen.
  int markAllRead() {
    final changed = unreadCount;
    if (changed == 0) return 0;
    state = [for (final n in state) n.read ? n : n.copyWith(read: true)];
    return changed;
  }

  /// Remove one record (swipe to dismiss).
  void remove(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  /// Clear the whole list (CM-43).
  void clearAll() {
    state = const [];
  }

  /// Insert a record at the top — used when an in-app event (a confirmed
  /// booking, a cancellation) should appear in the list immediately.
  void add(AppNotification notification) {
    state = [notification, ...state];
  }

  /// Records of one [kind] — backs the filter chips.
  List<AppNotification> ofKind(NotificationKind kind) =>
      state.where((n) => n.kind == kind).toList();
}

/// The app's notification list. Not autoDispose: the bell badge reads it from
/// the Home header, which outlives the Notifications screen.
final notificationsStoreProvider =
    NotifierProvider<NotificationsStore, List<AppNotification>>(
      NotificationsStore.new,
    );

/// Notifications newest-first — what the list renders.
final sortedNotificationsProvider = Provider<List<AppNotification>>((ref) {
  final items = ref.watch(notificationsStoreProvider);
  final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted;
});

/// Unread count for the bell badge. A narrow provider so the header rebuilds
/// only when the count changes, not on every list edit.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsStoreProvider);
  return items.where((n) => n.unread).length;
});
