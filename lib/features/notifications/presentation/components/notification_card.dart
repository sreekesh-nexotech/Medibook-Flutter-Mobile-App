import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/app_notification.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import 'notification_kind_style.dart';

/// One notification card (CM-40 … CM-43).
///
/// What it adds over the four fixed cards the audit found:
///
/// * **Kind.** A confirmation, a reminder, a change, a cancellation and a
///   general notice each get their own glyph, tint and badge, so they are
///   distinguishable at a glance — and by glyph and label alone, not by colour
///   only. See [NotificationKindStyle].
/// * **Unread state.** An unread card is visibly unread: a tinted surface, a
///   kind-coloured ring, a dot beside the title and a bold title. Its
///   semantics say so too, because none of those markers is announced.
/// * **Tap to read.** Tapping the card calls [onOpen], which the screen maps
///   to `markRead(id)` plus any deep link.
/// * **Long-press for the rest.** [onToggleRead] and [onRemove] hang off a
///   long press (and, on the screen, a swipe), so the card itself stays a
///   single obvious tap target.
///
/// Pure presentation: the screen owns every decision about what an action does.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.onAction,
    this.onOpen,
    this.onToggleRead,
    this.onRemove,
  });

  final AppNotification notification;

  /// One of the notification's own two buttons was pressed.
  final ValueChanged<NotificationAction> onAction;

  /// Tapping the card — the screen marks it read and follows any deep link.
  final VoidCallback? onOpen;

  /// Flip read ↔ unread. Offered on long press.
  final VoidCallback? onToggleRead;

  /// Dismiss this notification. Offered on long press.
  final VoidCallback? onRemove;

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
          '${isUnread ? 'Unread' : 'Read'}. ${notification.ago}.',
      child: AppCard(
        padding: EdgeInsets.all(18.w),
        // Unread reads differently three ways over, so it survives greyscale
        // and colour-blindness: a tinted surface, a kind-coloured ring, and
        // the dot + bold title inside.
        color: isUnread ? AppColors.surfaceAlt : AppColors.surface,
        border: isUnread ? Border.all(color: accent, width: 1.w) : null,
        onTap: onOpen,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: _hasLongPressMenu ? () => _showActions(context) : null,
          child: _Body(notification: notification, onAction: onAction),
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
/// kind badge and time, and the notification's own action row.
class _Body extends StatelessWidget {
  const _Body({required this.notification, required this.onAction});

  final AppNotification notification;
  final ValueChanged<NotificationAction> onAction;

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
                AppIcon(MedIcon.clock, size: 14, color: AppColors.textMuted),
                SizedBox(width: 6.w),
                Text(
                  notification.ago,
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (notification.hasActions) ...[
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: notification.action1Label!,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  pill: true,
                  fullWidth: true,
                  onPressed: () => onAction(notification.action1!),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: AppButton(
                  label: notification.action2Label!,
                  size: AppButtonSize.sm,
                  pill: true,
                  fullWidth: true,
                  onPressed: () => onAction(notification.action2!),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
