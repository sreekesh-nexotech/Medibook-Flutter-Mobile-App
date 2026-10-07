import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../domain/entities/notification.dart';
import 'notification_kind_style.dart';

/// One notification card (CM-40 … CM-43).
///
/// * **Kind.** Each of the six backend kinds gets its own glyph, tint and
///   badge, so they are distinguishable at a glance — and by glyph and label
///   alone, not by colour only. See [NotificationKindStyle].
/// * **Unread state.** An unread card is visibly unread: a tinted surface, a
///   kind-coloured ring, a dot beside the title and a bold title. Its
///   semantics say so too.
/// * **Tap to open.** [onOpen] — the screen marks it read and follows the
///   notification's `data.event` (§12.1).
/// * **Long-press for the rest.** [onToggleRead] and [onRemove] hang off a
///   long press (and, on the screen, a swipe).
///
/// Pure presentation: the screen owns every decision about what happens.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    this.onOpen,
    this.onToggleRead,
    this.onRemove,
    this.busy = false,
  });

  final PatientNotification notification;

  /// Tapping the card.
  final VoidCallback? onOpen;

  /// Flip read ↔ unread. Offered on long press.
  final VoidCallback? onToggleRead;

  /// Dismiss this notification. Offered on long press.
  final VoidCallback? onRemove;

  /// A read / unread / dismiss call is in flight for this row.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final kind = notification.kind;
    final isUnread = notification.unread;
    final accent = NotificationKindStyle.accent(kind);

    return Semantics(
      container: true,
      // The unread marker is a tint, a ring and a dot; none of them is
      // announced, so the state goes in the label (audit §3.3.1).
      label:
          '${kind.label}. ${notification.title}. '
          '${isUnread ? 'Unread' : 'Read'}. '
          '${AppDates.relativeAgo(notification.createdAt)}.',
      child: Opacity(
        opacity: busy ? 0.6 : 1,
        child: AppCard(
          padding: EdgeInsets.all(18.w),
          color: isUnread ? AppColors.surfaceAlt : AppColors.surface,
          border: isUnread ? Border.all(color: accent, width: 1.w) : null,
          onTap: busy ? null : onOpen,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: _hasLongPressMenu && !busy
                ? () => _showActions(context)
                : null,
            child: _Body(notification: notification),
          ),
        ),
      ),
    );
  }

  bool get _hasLongPressMenu => onToggleRead != null || onRemove != null;

  /// The secondary actions, on a long press. A sheet rather than hidden
  /// gestures only, because a swipe is undiscoverable on its own.
  Future<void> _showActions(BuildContext context) async {
    final toggle = onToggleRead;
    final remove = onRemove;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                notification.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.poppins(
                  size: AppFontSize.body,
                  weight: AppText.semibold,
                  color: AppColors.textStrong,
                ),
              ),
              SizedBox(height: 14.h),
              if (toggle != null)
                AppButton(
                  label: notification.read ? 'Mark as unread' : 'Mark as read',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.md,
                  pill: true,
                  fullWidth: true,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    toggle();
                  },
                ),
              if (toggle != null && remove != null) SizedBox(height: 10.h),
              if (remove != null)
                AppButton(
                  label: 'Remove',
                  variant: AppButtonVariant.danger,
                  size: AppButtonSize.md,
                  pill: true,
                  fullWidth: true,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    remove();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The card's contents: kind glyph, title row with the unread dot, body, the
/// kind badge and time.
class _Body extends StatelessWidget {
  const _Body({required this.notification});

  final PatientNotification notification;

  @override
  Widget build(BuildContext context) {
    final kind = notification.kind;
    final isUnread = notification.unread;
    final accent = NotificationKindStyle.accent(kind);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                color: NotificationKindStyle.wash(kind),
                borderRadius: AppRadii.md,
              ),
              child: Center(
                child: AppIcon(
                  NotificationKindStyle.icon(kind),
                  size: 18,
                  color: accent,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                notification.title,
                style: AppText.poppins(
                  size: AppFontSize.body,
                  weight: isUnread ? AppText.bold : AppText.semibold,
                  color: AppColors.textStrong,
                ),
              ),
            ),
            if (isUnread) ...[
              SizedBox(width: 10.w),
              Padding(
                padding: EdgeInsets.only(top: 7.h),
                child: Container(
                  width: 9.r,
                  height: 9.r,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: 10.h),
        Text(
          notification.body,
          style: AppText.poppins(
            size: AppFontSize.sm,
            color: AppColors.textBody,
            height: 1.5,
          ),
        ),
        SizedBox(height: 12.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 8.h,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppBadge(
              label: kind.label,
              tone: NotificationKindStyle.badgeTone(kind),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(PhIcon.clock, size: 14, color: AppColors.textMuted),
                SizedBox(width: 6.w),
                Text(
                  AppDates.relativeAgo(notification.createdAt),
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
