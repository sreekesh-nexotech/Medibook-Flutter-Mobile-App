import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/toast/toast_controller.dart';
import '../../application/providers/appointments_provider.dart';
import '../../application/states/appointment_action_state.dart';
import 'external_links.dart';

/// "Add to calendar" for one appointment (§10.10), shared by the receipt and
/// the two booking-confirmation screens so they behave identically: download
/// `calendar.ics`, save it and hand it to the OS share sheet, where the
/// calendar app takes it; a failure to fetch or to hand over is said plainly.
///
/// Call from a callback (`onPressed`), never from a `build`.
Future<void> addAppointmentToCalendar(
  BuildContext context,
  WidgetRef ref,
  String appointmentId,
) async {
  // Another action on this appointment (the receipt PDF, say) is still
  // running: this tap is ignored, not answered with an error (BL-APPT-058).
  if (ref.read(appointmentActionsProvider(appointmentId)).isBusy) return;
  final path = await ref
      .read(appointmentActionsProvider(appointmentId).notifier)
      .saveCalendar();
  if (!context.mounted) return;
  final toast = ref.read(toastControllerProvider.notifier);
  if (path == null) {
    toast.show(
      ref
              .read(appointmentActionsProvider(appointmentId))
              .failure
              ?.userMessage ??
          'Could not download the calendar file.',
    );
    return;
  }
  // The share sheet is its own confirmation; only its absence needs words.
  final shown = await ExternalLinks.shareFile(path, mimeType: 'text/calendar');
  if (!context.mounted || shown) return;
  toast.show('No app on this device could take the calendar file.');
}

/// True while [appointmentId]'s `.ics` is being fetched — the button's
/// `loading:`. Watches only that bit, so nothing else rebuilds the caller.
bool watchCalendarBusy(WidgetRef ref, String appointmentId) => ref.watch(
  appointmentActionsProvider(
    appointmentId,
  ).select((s) => s.isRunning(AppointmentActionKind.calendar)),
);
