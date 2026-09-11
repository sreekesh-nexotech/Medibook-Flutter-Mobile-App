import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/app_notification.dart';
import '../../../../core/mock_data/models/appointment.dart';
import '../../../../core/mock_data/stores/notifications_store.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../appointments/presentation/controllers/appointments_controller.dart';
import '../components/notification_card.dart';
import '../components/notification_kind_style.dart';
import '../controllers/notifications_filter_controller.dart';

/// Notifications (`/notifications`, pushed) — CM-40 … CM-43.
///
/// What this screen adds over the four fixed cards the audit found:
///
/// * **Unread state is real.** `AppNotification.read` drives a visibly
///   different card, the bell's count badge, tap-to-read, and a long-press
///   toggle back to unread.
/// * **"Mark all as read" actually marks things read.** That was audit
///   §3.1.3 — *"reports success and changes nothing"*. `markAllRead()` returns
///   **how many changed**, and the toast is built from that number: 1 → "1
///   notification marked as read", 3 → "3 notifications marked as read", 0 →
///   the control is disabled and says why, so a second press cannot claim a
///   success. The cards behind it change in the same frame, because they read
///   the same store.
/// * **Kinds are distinguishable.** Confirmation / reminder / change /
///   cancellation / general each get their own glyph, tint and badge, and can
///   be filtered to. With no kind filter the list is grouped Unread first,
///   then Earlier.
/// * **Pull-to-refresh** (§3.9.4 names Notifications as one of the three feeds
///   users will try to pull) and a first-class empty state (§3.2.2).
///
/// Sorting and filtering run on `createdAt` and `kind`, never on the rendered
/// `ago` string (§3.8.3).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(filteredNotificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final filters = ref.watch(notificationsFilterProvider);
    final counts = ref.watch(notificationKindCountsProvider);
    final total = ref.watch(notificationsStoreProvider).length;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: AppConstants.screenIn,
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10.h),
            child: child,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppInnerHeader(
                title: 'Notifications',
                onBack: () => _goBack(context),
                backSemanticLabel: 'Back',
              ),
              _HeaderRow(
                unreadCount: unreadCount,
                onMarkAllRead: () => _markAllRead(context, ref),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.x5.w,
                  0,
                  AppSpacing.x5.w,
                  12.h,
                ),
                child: AppSegmentedTabs(
                  tabs: [
                    for (final option in NotificationReadFilter.values)
                      option.label,
                  ],
                  active: filters.read.label,
                  onChanged: (label) => ref
                      .read(notificationsFilterProvider.notifier)
                      .setRead(_readFilterFor(label)),
                ),
              ),
              _KindChipsRow(
                counts: counts,
                selected: filters.kind,
                onToggle: ref
                    .read(notificationsFilterProvider.notifier)
                    .toggleKind,
              ),
              Expanded(
                child: AppRefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.x5.w,
                      6.h,
                      AppSpacing.x5.w,
                      24.h,
                    ),
                    child: notifications.isEmpty
                        ? _EmptyState(
                            isFiltered: filters.isActive && total > 0,
                            onClearFilters: ref
                                .read(notificationsFilterProvider.notifier)
                                .clearAll,
                            onBook: () =>
                                context.push(AppRoutes.bookingPath(step: 1)),
                          )
                        : _NotificationList(
                            notifications: notifications,
                            grouped: !filters.isActive,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static NotificationReadFilter _readFilterFor(String label) {
    for (final option in NotificationReadFilter.values) {
      if (option.label == label) return option;
    }
    return NotificationReadFilter.all;
  }

  /// Marks every notification read and reports **what actually changed**.
  ///
  /// `markAllRead()` returns the number of records it flipped, so a second
  /// press returns 0 and gets told there was nothing to do — the control can
  /// no longer claim a success it did not perform (audit §3.1.3).
  void _markAllRead(BuildContext context, WidgetRef ref) {
    final changed = ref.read(notificationsStoreProvider.notifier).markAllRead();
    final toast = ref.read(toastControllerProvider.notifier);
    if (changed == 0) {
      toast.show('Everything is already read');
      return;
    }
    toast.show(
      changed == 1
          ? '1 notification marked as read'
          : '$changed notifications marked as read',
    );
  }

  /// Re-derives the list from `notificationsStoreProvider`, the source of truth
  /// in this build.
  ///
  /// Deliberately does **not** invalidate the store: that would reset it to the
  /// seed and undo everything the user has read or dismissed. There is no
  /// network layer yet, so the gesture re-reads rather than re-fetches; when
  /// the repository lands this awaits its reload.
  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(filteredNotificationsProvider);
    await Future<void>.delayed(AppConstants.fadeIn);
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }
}

/// "Recent notifications" + the honest "Mark all as read" control.
class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.unreadCount, required this.onMarkAllRead});

  final int unreadCount;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.x5.w, 0, AppSpacing.x5.w, 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent notifications',
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  hasUnread ? '$unreadCount unread' : 'All caught up',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          AppButton(
            label: 'Mark all as read',
            variant: AppButtonVariant.ghost,
            size: AppButtonSize.sm,
            // Disabled with the reason in the label, rather than a button that
            // reports a success it cannot perform (audit §3.1.3).
            disabled: !hasUnread,
            semanticLabel: hasUnread
                ? 'Mark all $unreadCount unread notifications as read'
                : 'Mark all as read — nothing is unread',
            onPressed: hasUnread ? onMarkAllRead : null,
          ),
        ],
      ),
    );
  }
}

/// The kind filter chips. Only kinds the account actually has are offered, so
/// the row never proposes a filter that yields nothing.
class _KindChipsRow extends StatelessWidget {
  const _KindChipsRow({
    required this.counts,
    required this.selected,
    required this.onToggle,
  });

  final Map<NotificationKind, int> counts;
  final NotificationKind? selected;
  final ValueChanged<NotificationKind> onToggle;

  @override
  Widget build(BuildContext context) {
    final kinds = [
      for (final kind in NotificationKind.values)
        if ((counts[kind] ?? 0) > 0) kind,
    ];
    if (kinds.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.x5.w, 0, AppSpacing.x5.w, 10.h),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          for (final kind in kinds)
            _KindChip(
              kind: kind,
              count: counts[kind] ?? 0,
              isSelected: kind == selected,
              onTap: () => onToggle(kind),
            ),
        ],
      ),
    );
  }
}

/// One kind chip. Tapping the selected one clears the filter, so the row is
/// its own way back to the whole list.
class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final NotificationKind kind;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = NotificationKindStyle.accent(kind);

    return Semantics(
      button: true,
      selected: isSelected,
      label: isSelected
          ? 'Showing ${kind.label} only, $count. Tap to show every kind'
          : '${kind.label}, $count. Tap to show only these',
      child: ExcludeSemantics(
        child: Material(
          color: isSelected
              ? NotificationKindStyle.wash(kind)
              : AppColors.surface,
          borderRadius: AppRadii.pill,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.pill,
            child: Container(
              // Minimum, not fixed: the chip grows with the OS text scale.
              constraints: BoxConstraints(minHeight: 34.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                borderRadius: AppRadii.pill,
                border: Border.all(
                  color: isSelected ? accent : AppColors.border,
                  width: 1.w,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    NotificationKindStyle.icon(kind),
                    size: 14,
                    color: isSelected ? accent : AppColors.textMuted,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    '${kind.label} · $count',
                    style: AppText.poppins(
                      size: AppFontSize.xs,
                      weight: AppText.medium,
                      color: isSelected ? accent : AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The list itself, optionally grouped Unread / Earlier.
///
/// Each card is swipe-to-dismiss as well as long-press-to-act: the swipe is
/// fast for people who know it, the long-press sheet is discoverable for
/// everyone else.
class _NotificationList extends ConsumerWidget {
  const _NotificationList({required this.notifications, required this.grouped});

  final List<AppNotification> notifications;

  /// Split into Unread / Earlier. Off while a filter is active, since the
  /// filter already says what the list is.
  final bool grouped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!grouped) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final item in notifications) _Row(notification: item)],
      );
    }

    final unread = [
      for (final item in notifications)
        if (item.unread) item,
    ];
    final read = [
      for (final item in notifications)
        if (item.read) item,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (unread.isNotEmpty) ...[
          _GroupHeading('Unread'),
          for (final item in unread) _Row(notification: item),
        ],
        if (read.isNotEmpty) ...[
          if (unread.isNotEmpty) SizedBox(height: 8.h),
          _GroupHeading('Earlier'),
          for (final item in read) _Row(notification: item),
        ],
      ],
    );
  }
}

/// A group heading over a run of cards.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Text(
        text,
        style: AppText.poppins(
          size: AppFontSize.sm,
          weight: AppText.semibold,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// One dismissible card, with every callback wired to the store.
class _Row extends ConsumerWidget {
  const _Row({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Dismissible(
        key: ValueKey('notification-${notification.id}'),
        direction: DismissDirection.endToStart,
        background: const SizedBox.shrink(),
        secondaryBackground: _DismissBackground(),
        onDismissed: (_) => _remove(context, ref),
        child: NotificationCard(
          notification: notification,
          onOpen: () => _open(context, ref),
          onToggleRead: () => _toggleRead(ref),
          onRemove: () => _remove(context, ref),
          onAction: (action) => _handleAction(context, ref, action),
        ),
      ),
    );
  }

  /// Tapping a card reads it, then follows the notification's own deep link
  /// when it has one.
  void _open(BuildContext context, WidgetRef ref) {
    if (notification.unread) {
      ref.read(notificationsStoreProvider.notifier).markRead(notification.id);
    }
    final appointmentId = notification.appointmentId;
    if (appointmentId == null) return;
    final appointment = ref.read(appointmentByIdProvider(appointmentId));
    if (appointment == null) {
      ref
          .read(toastControllerProvider.notifier)
          .show('That appointment is no longer on your account');
      return;
    }
    context.push(AppRoutes.appointmentDetailPath(appointmentId));
  }

  void _toggleRead(WidgetRef ref) {
    final store = ref.read(notificationsStoreProvider.notifier);
    if (notification.read) {
      store.markUnread(notification.id);
    } else {
      store.markRead(notification.id);
    }
  }

  void _remove(BuildContext context, WidgetRef ref) {
    ref.read(notificationsStoreProvider.notifier).remove(notification.id);
    ref
        .read(toastControllerProvider.notifier)
        .show('“${notification.title}” removed');
  }

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    NotificationAction action,
  ) {
    void toast(String message) =>
        ref.read(toastControllerProvider.notifier).show(message);

    // Acting on a notification reads it — you have clearly seen it.
    if (notification.unread) {
      ref.read(notificationsStoreProvider.notifier).markRead(notification.id);
    }

    /// The appointment this notification is about may have been cancelled
    /// since it was raised, so the navigation actions check first.
    bool apptLive(String id) {
      final appointment = ref.read(appointmentByIdProvider(id));
      return appointment != null &&
          appointment.bucket == AppointmentBucket.upcoming;
    }

    final appointmentId = notification.appointmentId ?? '1';

    switch (action) {
      case NotificationAction.rescheduleTodayAppt:
        if (apptLive(appointmentId)) {
          context.push(AppRoutes.reschedulePath(appointmentId));
        } else {
          toast('That appointment was cancelled');
        }
      case NotificationAction.viewTodayApptDetail:
        if (apptLive(appointmentId)) {
          context.push(AppRoutes.appointmentDetailPath(appointmentId));
        } else {
          toast('That appointment was cancelled');
        }
      case NotificationAction.viewRecords:
        context.go(AppRoutes.records);
      case NotificationAction.downloadPrescription:
        // No storage or PDF package in this build, so say so rather than
        // reporting a download that never happened.
        showStubbedToast(context, ref, 'Download');
      case NotificationAction.remindLater:
        // Honest: there is no scheduler, so this hides the notice rather than
        // promising a reminder the app cannot send.
        ref.read(notificationsStoreProvider.notifier).markRead(notification.id);
        toast('Marked as read — reminders are not scheduled in this demo');
      case NotificationAction.scheduleBooking:
        context.push(AppRoutes.bookingPath(step: 1));
    }
  }
}

/// The red "Remove" plate revealed by a swipe.
class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: EdgeInsets.symmetric(horizontal: 22.w),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: AppRadii.lg,
      ),
      child: Text(
        'Remove',
        style: AppText.poppins(
          size: AppFontSize.sm,
          weight: AppText.semibold,
          color: AppColors.dangerText,
        ),
      ),
    );
  }
}

/// Two empties, because they need two different ways out.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isFiltered,
    required this.onClearFilters,
    required this.onBook,
  });

  final bool isFiltered;
  final VoidCallback onClearFilters;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    if (isFiltered) {
      return AppEmptyView(
        iconName: MedIcon.bell,
        headline: 'Nothing matches this view',
        body: 'Try another kind, or switch back to All.',
        actionLabel: 'Show all notifications',
        onAction: onClearFilters,
      );
    }
    return AppEmptyView(
      iconName: MedIcon.bell,
      headline: 'No notifications',
      body:
          'Booking confirmations, reminders and changes to your '
          'appointments will show up here.',
      actionLabel: 'Book an appointment',
      onAction: onBook,
    );
  }
}
