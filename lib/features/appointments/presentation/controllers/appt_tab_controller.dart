import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/mock_data/models/appointment.dart';

/// The two Appointments tabs, in display order. Consumed by both the segmented
/// tabs and [apptTabProvider]'s seed.
const List<String> kAppointmentTabs = ['Upcoming', 'Past'];

/// The active Appointments tab label ('Upcoming' / 'Past').
///
/// Pure local UI state for the Appointments list, so it is `autoDispose` — it
/// resets to "Upcoming" each time the screen leaves the tree (QA Prompt 6:
/// transient selections are autoDispose, not app-global).
final apptTabProvider = StateProvider.autoDispose<String>(
  (ref) => kAppointmentTabs.first,
);

/// Maps a tab label to the [AppointmentBucket] the list filters on.
AppointmentBucket bucketForTab(String tab) =>
    tab == 'Past' ? AppointmentBucket.past : AppointmentBucket.upcoming;
