import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../application/providers/notifications_provider.dart';
import '../../application/states/notifications_state.dart';
import '../../application/usecases/notification_target.dart';
import '../../domain/entities/notification.dart';
import '../components/notification_card.dart';
import '../components/notification_kind_style.dart';
import '../../application/providers/notifications_filter_controller.dart';

/// Notifications (`/notifications`, pushed) — CM-40 … CM-43, over
/// `GET /patient/notifications` (§12.1).
///
/// * **Filters are the server's.** The All / Unread / Read tabs send
///   `unread=`, the kind chips send `kind=`, and each change is one request
///   (cached first, then the network).
/// * **Read state is the server's.** Tap → `POST /{id}/read`; long-press →
///   `/unread` or `DELETE`; "Mark all as read" → `read-all`, and the toast is
///   built from its `updated_count` — never a success that did not happen.
/// * **Tapping opens the right screen** by `data.event` (§12.1).
/// * **The badge is live.** New notifications arriving on the inbox socket
///   re-fetch the list.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(notificationsFilterProvider);
    final query = ref.watch(notificationsQueryProvider);
    final list = ref.watch(notificationsListProvider(query));
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final online = ref.watch(isOnlineProvider).valueOrNull ?? true;

    // Something new arrived — a `notification.created` frame, or the unread
    // count going up (on this server mostly the count, re-read after the
    // socket drops) → re-fetch past the cache, so the list on screen shows
    // what the badge just counted (BL-NOTIF-014: a plain load was answered
    // from the copy already checked on this visit).
    void reload() => ref
        .read(notificationsListProvider(query).notifier)
        .load(forceRefresh: true);
    ref.listen(inboxProvider.select((s) => s.lastCreatedId), (previous, next) {
      if (next != null && next != previous) reload();
    });
    ref.listen(unreadNotificationCountProvider, (previous, next) {
      if (previous != null && next > previous) reload();
    });

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
                onMarkAllRead: () => _markAllRead(context, ref, query),
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
                      .setRead(NotificationReadFilter.fromLabel(label)),
                ),
              ),
              _KindChipsRow(
                selected: filters.kind,
                onToggle: ref
                    .read(notificationsFilterProvider.notifier)
                    .toggleKind,
              ),
              // Offline is said once, by the app-wide OfflineBar.
              if (online && list.hasRowsAndFailure)
                AppErrorBanner(
                  message: 'Could not update — ${list.failure!.userMessage}',
                  tone: AppBannerTone.danger,
                  iconName: PhIcon.xCircle,
                  onTap: () => _refresh(ref, query),
                )
              else if (list.isStale)
                AppErrorBanner(
                  message: list.cachedAt == null
                      ? 'This may be out of date • Tap to refresh'
                      : 'Data from ${AppDates.relativeAgo(list.cachedAt!)} • '
                            'Tap to refresh',
                  onTap: () => _refresh(ref, query),
                )
              else if (list.revalidating && list.items.isNotEmpty)
                const AppErrorBanner(
                  message: 'Updating…',
                  tone: AppBannerTone.info,
                ),
              Expanded(
                child: AppRefreshIndicator(
                  onRefresh: () => _refresh(ref, query),
                  child: _Body(
                    query: query,
                    list: list,
                    isFiltered: filters.isActive,
                    onClearFilters: ref
                        .read(notificationsFilterProvider.notifier)
                        .clearAll,
                    onBook: () => context.push(AppRoutes.bookingPath(step: 1)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `POST read-all` and report **what actually changed** — `updated_count`.
  Future<void> _markAllRead(
    BuildContext context,
    WidgetRef ref,
    NotificationListQuery query,
  ) async {
    final result = await ref
        .read(notificationsListProvider(query).notifier)
        .markAllRead();
    if (!context.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    final failure = result.failure;
    if (failure != null) {
      toast.show(failure.userMessage);
      return;
    }
    final changed = result.updated ?? 0;
    ref.read(inboxProvider.notifier).setCount(0);
    toast.show(switch (changed) {
      0 => 'Everything is already read',
      1 => '1 notification marked as read',
      _ => '$changed notifications marked as read',
    });
  }

  Future<void> _refresh(WidgetRef ref, NotificationListQuery query) async {
    await Future.wait([
      ref
          .read(notificationsListProvider(query).notifier)
          .load(forceRefresh: true),
      ref.read(inboxProvider.notifier).refresh(),
    ]);
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
            // Disabled with the reason in the label, rather than a button
            // that reports a success it cannot perform (audit §3.1.3).
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

/// The kind filter chips — the six backend kinds (§17). Tapping the selected
/// one clears the filter, so the row is its own way back to the whole list.
class _KindChipsRow extends StatelessWidget {
  const _KindChipsRow({required this.selected, required this.onToggle});

  final NotificationKind? selected;
  final ValueChanged<NotificationKind> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(AppSpacing.x5.w, 0, AppSpacing.x5.w, 10.h),
        itemCount: NotificationKind.values.length,
        separatorBuilder: (_, _) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final kind = NotificationKind.values[index];
          return _KindChip(
            kind: kind,
            isSelected: kind == selected,
            onTap: () => onToggle(kind),
          );
        },
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.kind,
    required this.isSelected,
    required this.onTap,
  });

  final NotificationKind kind;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = NotificationKindStyle.accent(kind);

    return Semantics(
      button: true,
      selected: isSelected,
      label: isSelected
          ? 'Showing ${kind.label} only. Tap to show every kind'
          : '${kind.label}. Tap to show only these',
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
                    kind.label,
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

/// The list in its four states: skeleton, error, empty, rows (grouped
/// Unread / Earlier when no filter is active) with load-more at the bottom.
class _Body extends ConsumerWidget {
  const _Body({
    required this.query,
    required this.list,
    required this.isFiltered,
    required this.onClearFilters,
    required this.onBook,
  });

  final NotificationListQuery query;
  final NotificationsListState list;
  final bool isFiltered;
  final VoidCallback onClearFilters;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (list.isLoading) return const AppSkeletonList(count: 3);

    final failure = list.failure;
    if (failure != null && list.items.isEmpty) {
      return AppErrorView(
        failure: failure,
        onRetry: () => ref
            .read(notificationsListProvider(query).notifier)
            .load(forceRefresh: true),
      );
    }
    if (list.items.isEmpty) {
      return isFiltered
          ? AppEmptyView(
              iconName: PhIcon.bell,
              headline: 'Nothing matches this view',
              body: 'Try another kind, or switch back to All.',
              actionLabel: 'Show all notifications',
              onAction: onClearFilters,
            )
          : AppEmptyView(
              iconName: PhIcon.bell,
              headline: 'No notifications',
              body:
                  'Booking confirmations, reminders and updates to your '
                  'appointments will show up here.',
              actionLabel: 'Book an appointment',
              onAction: onBook,
            );
    }

    final grouped = !isFiltered;
    final unread = grouped
        ? [
            for (final item in list.items)
              if (item.unread) item,
          ]
        : list.items;
    final read = grouped
        ? [
            for (final item in list.items)
              if (item.read) item,
          ]
        : const <PatientNotification>[];

    return SingleChildScrollView(
      physics: appRefreshPhysics,
      padding: EdgeInsets.fromLTRB(AppSpacing.x5.w, 6.h, AppSpacing.x5.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (grouped && unread.isNotEmpty) const _GroupHeading('Unread'),
          for (final item in unread)
            _Row(
              query: query,
              notification: item,
              busy: list.busyIds.contains(item.id),
            ),
          if (grouped && read.isNotEmpty) ...[
            if (unread.isNotEmpty) SizedBox(height: 8.h),
            const _GroupHeading('Earlier'),
            for (final item in read)
              _Row(
                query: query,
                notification: item,
                busy: list.busyIds.contains(item.id),
              ),
          ],
          if (list.loadMoreFailure != null)
            AppInlineError(
              failure: list.loadMoreFailure!,
              retryLabel: 'Load more',
              onRetry: () => ref
                  .read(notificationsListProvider(query).notifier)
                  .loadMore(),
            )
          else if (list.hasNext)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: AppButton(
                label: 'Load more',
                variant: AppButtonVariant.ghost,
                fullWidth: true,
                loading: list.isLoadingMore,
                onPressed: () => ref
                    .read(notificationsListProvider(query).notifier)
                    .loadMore(),
              ),
            ),
        ],
      ),
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

/// One dismissible card, with every callback wired to the controller.
class _Row extends ConsumerWidget {
  const _Row({
    required this.query,
    required this.notification,
    required this.busy,
  });

  final NotificationListQuery query;
  final PatientNotification notification;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Dismissible(
        key: ValueKey('notification-${notification.id}'),
        direction: busy ? DismissDirection.none : DismissDirection.endToStart,
        // The row only leaves once the server has agreed (see `dismiss`).
        confirmDismiss: (_) => _remove(context, ref),
        background: const SizedBox.shrink(),
        secondaryBackground: const _DismissBackground(),
        child: NotificationCard(
          notification: notification,
          busy: busy,
          onOpen: () => _open(context, ref),
          onToggleRead: () => _toggleRead(context, ref),
          onRemove: () => _remove(context, ref),
        ),
      ),
    );
  }

  /// Tapping a card reads it, then follows `data.event` (§12.1).
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (notification.unread) {
      final failure = await ref
          .read(notificationsListProvider(query).notifier)
          .markRead(notification.id);
      if (failure == null) ref.read(inboxProvider.notifier).adjust(-1);
    }
    if (!context.mounted) return;
    _navigate(context, ref, NotificationTargets.of(notification));
  }

  void _navigate(
    BuildContext context,
    WidgetRef ref,
    NotificationTarget target,
  ) {
    switch (target) {
      case AppointmentDetailTarget(:final appointmentId):
        context.push(AppRoutes.appointmentDetailPath(appointmentId));
      case LiveQueueTarget(:final appointmentId):
        context.push(AppRoutes.queuePath(appointmentId));
      case ReceiptTarget(:final appointmentId):
        context.push(AppRoutes.receiptPath(appointmentId));
      case FamilyMembersTarget():
        context.push(AppRoutes.dependants);
      case AccountTarget():
        context.go(AppRoutes.profile);
      case DataExportTarget():
        // The finished file is downloaded from the export screen (§5.7).
        context.push(AppRoutes.profileDataExport);
      case SupportTicketTarget(:final ticketId):
        context.push(
          ticketId == null
              ? AppRoutes.supportTickets
              : AppRoutes.supportTicketPath(ticketId),
        );
      case NoTarget():
        break;
    }
  }

  Future<void> _toggleRead(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(notificationsListProvider(query).notifier);
    final failure = notification.read
        ? await controller.markUnread(notification.id)
        : await controller.markRead(notification.id);
    if (!context.mounted) return;
    if (failure != null) {
      ref.read(toastControllerProvider.notifier).show(failure.userMessage);
      return;
    }
    ref.read(inboxProvider.notifier).adjust(notification.read ? 1 : -1);
  }

  /// `DELETE /{id}`. Returns whether the row may leave the list.
  Future<bool> _remove(BuildContext context, WidgetRef ref) async {
    final wasUnread = notification.unread;
    final failure = await ref
        .read(notificationsListProvider(query).notifier)
        .dismiss(notification.id);
    if (!context.mounted) return failure == null;
    final toast = ref.read(toastControllerProvider.notifier);
    if (failure != null) {
      toast.show(failure.userMessage);
      return false;
    }
    if (wasUnread) ref.read(inboxProvider.notifier).adjust(-1);
    toast.show('“${notification.title}” removed');
    // The controller already removed the row; Dismissible must not animate
    // a second removal of a widget that is gone.
    return false;
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
