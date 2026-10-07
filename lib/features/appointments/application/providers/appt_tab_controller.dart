import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/appointment_filter.dart';
import 'appointment_filter_controller.dart';

/// The three Appointments tabs, in display order — the design's
/// Upcoming / Completed / Canceled pills.
const List<AppointmentTab> kAppointmentTabs = AppointmentTab.values;

/// The active Appointments tab.
///
/// Pure local UI state for the Appointments list, so it is `autoDispose` — it
/// resets to Upcoming each time the screen leaves the tree (QA Prompt 6:
/// transient selections are autoDispose, not app-global).
final apptTabProvider = StateProvider.autoDispose<AppointmentTab>(
  (ref) => AppointmentTab.upcoming,
);

/// The request the active tab makes (§10.1): its bucket / status set plus
/// the live filter. Value-equal, so switching back to a tab re-uses the
/// same list provider instance while it is still alive.
final activeAppointmentQueryProvider =
    Provider.autoDispose<AppointmentListQuery>(
      (ref) => AppointmentListQuery(
        tab: ref.watch(apptTabProvider),
        filter: ref
            .watch(appointmentFilterProvider)
            .forTab(ref.watch(apptTabProvider)),
      ),
    );
