import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../application/providers/availability_providers.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/slots.dart';
import 'date_strip.dart';
import 'file_image.dart';
import 'slot_grid.dart';
import 'slot_labels.dart';

/// The slot the patient confirmed in [showSlotSheet].
typedef SlotPick = ({String date, Slot slot, String sessionLabel});

/// Opens the design's "Select Time" sheet for [doctor]: the doctor strip
/// (`56` photo, name `18/700`, "spec · fee" `13` muted, close ×), a hairline,
/// "Select Time" (`18/600`), the availability date strip (§8.1), the slots
/// grouped by session (§8.2), and "Continue with 09:30 AM".
///
/// Resolves with the pick, or null when dismissed. [initialDate] /
/// [initial] pre-select the slot already in the draft ("Change" on step 3).
Future<SlotPick?> showSlotSheet(
  BuildContext context, {
  required DoctorCard doctor,
  String? timezone,
  String? initialDate,
  Slot? initial,
}) {
  return showAppSheet<SlotPick>(
    context,
    showCloseButton: false,
    builder: (sheetContext) => _SlotSheet(
      doctor: doctor,
      timezone: timezone,
      initialDate: initialDate,
      initial: initial,
    ),
  );
}

class _SlotSheet extends ConsumerStatefulWidget {
  const _SlotSheet({
    required this.doctor,
    this.timezone,
    this.initialDate,
    this.initial,
  });

  final DoctorCard doctor;
  final String? timezone;
  final String? initialDate;
  final Slot? initial;

  @override
  ConsumerState<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends ConsumerState<_SlotSheet> {
  // Purely visual picks for this sheet; the draft owns the real state.
  String? _date;
  Slot? _slot;
  String? _sessionLabel;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
    _slot = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final availability = ref.watch(doctorAvailabilityProvider(doctor.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: AppRadii.md,
              child: SizedBox(
                width: 56.w,
                height: 56.w,
                child: AppFileImage(
                  fileId: doctor.photoFileId,
                  fallback: const ColoredBox(color: AppColors.surfaceTint),
                  alignment: const Alignment(0, -0.6),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    doctor.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(
                      size: AppFontSize.title,
                      weight: AppText.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    '${doctor.specialityLabel} · '
                    '${Money.paise(doctor.consultationFeePaise).format()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: 'Close',
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: SizedBox(
                    width: 46.r,
                    height: 46.r,
                    child: Center(
                      child: AppIcon(
                        PhIcon.x,
                        size: 22,
                        color: AppColors.textStrong,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Container(
          height: 1.h,
          margin: EdgeInsets.only(top: 16.h, bottom: 20.h),
          color: AppColors.borderSubtle,
        ),
        Text(
          'Select Time',
          style: AppText.poppins(
            size: AppFontSize.title,
            weight: AppText.semibold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 12.h),
        availability.when(
          loading: () => const AppSkeletonList(count: 2, tile: true),
          error: (error, _) => AppInlineError(
            failure: error.asFailure(),
            onRetry: () =>
                ref.invalidate(doctorAvailabilityProvider(doctor.id)),
          ),
          data: (result) {
            final days = result.value.dates;
            final date =
                _date ??
                result.value.firstAvailable?.date ??
                (days.isEmpty ? null : days.first.date);
            if (date == null) {
              return Text(
                'This doctor has no sessions in the booking window.',
                style: AppText.poppins(
                  size: AppFontSize.sm,
                  color: AppColors.textMuted,
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DateStrip(
                  days: days,
                  selectedDate: date,
                  timezone: widget.timezone,
                  onSelect: (day) => setState(() {
                    _date = day.date;
                    _slot = null;
                    _sessionLabel = null;
                  }),
                ),
                SizedBox(height: 16.h),
                _DaySlotsPanel(
                  doctorId: doctor.id,
                  date: date,
                  timezone: widget.timezone,
                  selected: _slot,
                  onPick: (slot, session) => setState(() {
                    _date = date;
                    _slot = slot;
                    _sessionLabel = session.label;
                  }),
                  onCleared: () => setState(() {
                    _slot = null;
                    _sessionLabel = null;
                  }),
                ),
                SizedBox(height: 24.h),
                _Continue(
                  slot: _slot,
                  timezone: widget.timezone,
                  onContinue: () {
                    final slot = _slot;
                    if (slot == null) return;
                    Navigator.of(context).pop((
                      date: date,
                      slot: slot,
                      sessionLabel: _sessionLabel ?? '',
                    ));
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The slots for one day, by session — defaulting the selection to the first
/// free slot as the design does.
class _DaySlotsPanel extends ConsumerWidget {
  const _DaySlotsPanel({
    required this.doctorId,
    required this.date,
    required this.timezone,
    required this.selected,
    required this.onPick,
    required this.onCleared,
  });

  final String doctorId;
  final String date;
  final String? timezone;
  final Slot? selected;
  final void Function(Slot slot, SlotSession session) onPick;

  /// The earlier pick was taken and nothing else is free that day.
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(
      doctorSlotsProvider((doctorId: doctorId, date: date)),
    );
    return slots.when(
      loading: () => const AppSkeletonList(count: 1, tile: true),
      error: (error, _) => AppInlineError(
        failure: error.asFailure(),
        onRetry: () => ref.invalidate(
          doctorSlotsProvider((doctorId: doctorId, date: date)),
        ),
      ),
      data: (result) {
        final day = result.value;
        // Keep the earlier pick only while it is still free: a slot someone
        // else booked meanwhile must not stay confirmable (BL-BOOK-025).
        // Otherwise default to the first free slot, as the design does.
        final stillFree =
            selected != null && day.available.any((s) => s.id == selected!.id);
        // The earlier pick as the server has it now, when it is no longer
        // free: its state says why (taken, being booked, blocked, passed).
        final noLongerFree = selected == null || stillFree
            ? null
            : day.allSlots.where((s) => s.id == selected!.id).firstOrNull;
        final effective = stillFree
            ? selected
            : (day.available.isEmpty ? null : day.available.first);
        if (noLongerFree != null) {
          final time = SlotLabels.time(
            noLongerFree.startsAt,
            timezone: day.timezone ?? timezone,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(toastControllerProvider.notifier)
                .show(SlotLabels.noLongerFree(noLongerFree.state, time));
            if (effective == null) onCleared();
          });
        }
        if (effective != null && effective.id != selected?.id) {
          final session = day.sessionOf(effective);
          if (session != null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => onPick(effective, session),
            );
          }
        }
        return SlotGrid(
          sessions: day.sessions,
          selected: effective,
          // The grid names its own zone (§8.2); the caller's is the fallback.
          timezone: day.timezone ?? timezone,
          emptyMessage: day.isFullyBooked
              ? 'Every slot on this day is taken. Pick another day.'
              : 'The doctor does not consult on this day.',
          onPick: onPick,
          onUnavailable: (slot) => ref
              .read(toastControllerProvider.notifier)
              .show(SlotLabels.unavailableMessage(slot.state)),
        );
      },
    );
  }
}

class _Continue extends StatelessWidget {
  const _Continue({
    required this.slot,
    required this.timezone,
    required this.onContinue,
  });

  final Slot? slot;
  final String? timezone;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final picked = slot;
    return AppButton(
      label: picked == null
          ? 'No free slot on this day'
          : 'Continue with ${SlotLabels.time(picked.startsAt, timezone: timezone)}',
      pill: true,
      fullWidth: true,
      disabled: picked == null,
      onPressed: picked == null ? null : onContinue,
    );
  }
}
