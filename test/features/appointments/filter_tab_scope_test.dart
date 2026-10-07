import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/appointments/domain/entities/appointment.dart';
import 'package:medibook/features/appointments/domain/entities/appointment_filter.dart';
import 'package:medibook/features/appointments/application/providers/appointment_filter_controller.dart';
import 'package:medibook/features/appointments/application/providers/appt_tab_controller.dart';

import '../../support/offline_overrides.dart';

/// BL-APPT-022: a status filter belongs to the Upcoming tab. On Completed
/// and Cancelled it is not applied, not shown as a chip and not counted —
/// and it is still there on returning to Upcoming.
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        ...offlineOverrides(),
        // The chips resolve names from the loaded lists; none are needed here.
        appointmentFilterOptionsProvider.overrideWith(
          (ref) => (doctors: const [], hospitals: const [], persons: const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
      ..listen(appointmentFilterChipsProvider, (_, _) {})
      ..listen(apptTabProvider, (_, _) {});
    container.read(appointmentFilterProvider.notifier)
      ..toggleStatus(AppointmentStatus.scheduled)
      ..toggleStatus(AppointmentStatus.checkedIn);
  });

  test('Upcoming: the statuses are chips and are applied', () {
    expect(container.read(appointmentFilterChipsProvider), hasLength(2));
    expect(
      container.read(activeAppointmentQueryProvider).filter.statuses,
      hasLength(2),
    );
  });

  test('Completed: no status chip, count or filter; back on Upcoming '
      'they return', () {
    container
        .read(apptTabProvider.notifier)
        .update((_) => AppointmentTab.completed);
    expect(container.read(appointmentFilterChipsProvider), isEmpty);
    final query = container.read(activeAppointmentQueryProvider);
    expect(query.filter.statuses, isEmpty);
    expect(
      container
          .read(appointmentFilterProvider)
          .forTab(AppointmentTab.completed)
          .activeCount,
      0,
    );

    container
        .read(apptTabProvider.notifier)
        .update((_) => AppointmentTab.upcoming);
    expect(container.read(appointmentFilterChipsProvider), hasLength(2));
  });
}
