import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../domain/entities/slots.dart';
import 'slot_labels.dart';

/// The design's slot panel: a white, hairline-bordered `--radius-lg` box
/// (`16` padding) of time chips wrapping at `12` gaps, one panel per
/// **session** (the queue unit, §8.2) with the session's label above it.
///
/// A chip is `46` tall, `12px 16px`, `--radius-md`, `13`; `surface-alt` by
/// default, brand with white `600` text when chosen, grey and struck
/// through when it cannot be picked — taken, being booked, blocked or
/// passed, as the server says. Times render in the hospital's zone.
///
/// Shared by the booking slot sheet and Doctor Details, so the two read
/// identically.
class SlotGrid extends StatelessWidget {
  const SlotGrid({
    super.key,
    required this.sessions,
    required this.selected,
    required this.onPick,
    required this.onUnavailable,
    this.timezone,
    this.emptyMessage = 'The doctor does not consult on this day.',
  });

  final List<SlotSession> sessions;

  /// The chosen slot, matched on id.
  final Slot? selected;

  /// Fires with the slot and its session.
  final void Function(Slot slot, SlotSession session) onPick;

  /// Tapping a chip that cannot be picked; the caller toasts why, from the
  /// slot's state ([SlotLabels.unavailableMessage]).
  final ValueChanged<Slot> onUnavailable;
  final String? timezone;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final withSlots = [
      for (final s in sessions)
        if (s.slots.isNotEmpty) s,
    ];
    if (withSlots.isEmpty) {
      return _Panel(
        child: Text(
          emptyMessage,
          style: AppText.poppins(
            size: AppFontSize.sm,
            color: AppColors.textMuted,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < withSlots.length; i++) ...[
          if (i > 0) SizedBox(height: 16.h),
          _SessionHeading(session: withSlots[i], timezone: timezone),
          SizedBox(height: 8.h),
          _Panel(
            child: Wrap(
              spacing: 12.w,
              runSpacing: 12.h,
              children: [
                for (final slot in withSlots[i].slots)
                  _SlotChip(
                    label: SlotLabels.time(slot.startsAt, timezone: timezone),
                    selectable: slot.isSelectable,
                    unavailableNote: SlotLabels.unavailableNote(slot.state),
                    selected: selected?.id == slot.id,
                    onTap: slot.isSelectable
                        ? () => onPick(slot, withSlots[i])
                        : () => onUnavailable(slot),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// "Morning OPD · 9:00 AM – 12:00 PM", with a muted note when the session is
/// paused or closed.
class _SessionHeading extends StatelessWidget {
  const _SessionHeading({required this.session, required this.timezone});

  final SlotSession session;
  final String? timezone;

  @override
  Widget build(BuildContext context) {
    final note = switch (session.status) {
      SessionStatus.paused => ' · paused',
      SessionStatus.closed => ' · closed',
      SessionStatus.cancelled => ' · cancelled',
      _ => '',
    };
    return Text(
      '${session.label} · '
      '${SlotLabels.time(session.startsAt, timezone: timezone)} – '
      '${SlotLabels.time(session.endsAt, timezone: timezone)}$note',
      style: AppText.poppins(
        size: AppFontSize.sm,
        weight: AppText.medium,
        color: AppColors.textBody,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lg,
        border: Border.all(color: AppColors.borderSubtle, width: 1.w),
      ),
      child: child,
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selectable,
    required this.unavailableNote,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selectable;

  /// Why it cannot be picked ("taken", "passed" …), from the server.
  final String unavailableNote;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final off = !selectable;
    return Semantics(
      button: true,
      selected: selected,
      label: off ? '$label, $unavailableNote' : label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: 46.h),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: selected && !off ? AppColors.brand : AppColors.surfaceAlt,
              borderRadius: AppRadii.md,
            ),
            child: Text(
              label,
              style: AppText.poppins(
                size: AppFontSize.sm,
                weight: selected ? AppText.semibold : AppText.medium,
                color: off
                    ? AppColors.grey300
                    : (selected
                          ? AppColors.textOnBrand
                          : AppColors.textPrimary),
              ).copyWith(decoration: off ? TextDecoration.lineThrough : null),
            ),
          ),
        ),
      ),
    );
  }
}
