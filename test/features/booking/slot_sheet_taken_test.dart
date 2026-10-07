import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/core/widgets/toast/toast_controller.dart';
import 'package:medibook/features/booking/application/providers/availability_providers.dart';
import 'package:medibook/features/booking/domain/entities/availability.dart';
import 'package:medibook/features/booking/domain/entities/department.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';
import 'package:medibook/features/booking/domain/entities/slots.dart';
import 'package:medibook/features/booking/presentation/components/slot_sheet.dart';

import '../../support/harness.dart';
import '../../support/offline_overrides.dart';

/// BL-BOOK-025: "Change" on step 3 re-opens the sheet on the slot already
/// chosen. If someone else booked it meanwhile, it must not stay
/// confirmable.
void main() {
  const date = '2026-10-07';
  const doctor = DoctorCard(
    id: 'doc1',
    slug: 'doc1',
    name: 'Dr. Test',
    department: DepartmentRef(id: 'd1', code: 'gm', name: 'General'),
    hospital: DoctorHospitalRef(id: 'h1', name: 'H', city: 'Kochi'),
    consultationFeePaise: 50000,
    isBookableOnline: true,
  );

  Slot slot(String id, int hour, SlotState state) => Slot(
    id: id,
    sessionId: 's1',
    startsAt: DateTime.utc(2026, 10, 7, hour),
    endsAt: DateTime.utc(2026, 10, 7, hour, 10),
    state: state,
  );

  CachedResult<T> fresh<T>(T value) => CachedResult<T>(
    value: value,
    source: CacheSource.network,
    cachedAt: DateTime.now(),
  );

  Future<void> open(WidgetTester tester, List<Slot> slots) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    HiveInit.store = InMemoryLocalStore();
    final start = DateTime.utc(2026, 10, 7, 3);
    await tester.pumpWidget(
      screenHarness(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showSlotSheet(
              context,
              doctor: doctor,
              timezone: 'UTC',
              initialDate: date,
              // Chosen earlier, while it was free.
              initial: slot('mine', 4, SlotState.available),
            ),
            child: const Text('Change'),
          ),
        ),
        overrides: [
          ...offlineOverrides(),
          doctorAvailabilityProvider('doc1').overrideWith(
            (_) => Stream.value(
              fresh(
                DoctorAvailability(
                  doctorId: 'doc1',
                  from: date,
                  to: date,
                  dates: [
                    AvailabilityDay(
                      date: date,
                      sessions: [
                        AvailabilitySession(
                          sessionId: 's1',
                          sessionCode: 'morning',
                          label: 'Morning OPD',
                          state: SessionAvailability.available,
                          startsAt: start,
                          endsAt: start.add(const Duration(hours: 3)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          doctorSlotsProvider((doctorId: 'doc1', date: date)).overrideWith(
            (_) => Stream.value(
              fresh(
                DaySlots(
                  doctorId: 'doc1',
                  date: date,
                  timezone: 'UTC',
                  sessions: [
                    SlotSession(
                      sessionId: 's1',
                      sessionCode: 'morning',
                      label: 'Morning OPD',
                      status: SessionStatus.open,
                      startsAt: start,
                      endsAt: start.add(const Duration(hours: 3)),
                      slots: slots,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
  }

  String? toast(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(TextButton)),
  ).read(toastControllerProvider)?.text;

  testWidgets('a slot still free stays chosen', (tester) async {
    await open(tester, [
      slot('early', 3, SlotState.available),
      slot('mine', 4, SlotState.available),
    ]);
    expect(find.text('Continue with 4:00 AM'), findsOneWidget);
  });

  testWidgets('a slot taken meanwhile moves to the first free one', (
    tester,
  ) async {
    await open(tester, [
      slot('early', 3, SlotState.available),
      slot('mine', 4, SlotState.booked),
    ]);
    expect(find.text('Continue with 4:00 AM'), findsNothing);
    expect(find.text('Continue with 3:00 AM'), findsOneWidget);
    expect(toast(tester), contains('has just been taken'));
  });

  // The server says why the earlier pick is gone; it was always "taken".
  testWidgets('a slot that has passed meanwhile says so', (tester) async {
    await open(tester, [
      slot('early', 3, SlotState.available),
      slot('mine', 4, SlotState.past),
    ]);
    expect(find.text('Continue with 3:00 AM'), findsOneWidget);
    expect(toast(tester), 'The 4:00 AM slot has passed. Pick another.');
  });

  testWidgets('nothing else free: Continue is off', (tester) async {
    await open(tester, [slot('mine', 4, SlotState.booked)]);
    expect(find.textContaining('Continue with'), findsNothing);
    expect(find.text('No free slot on this day'), findsOneWidget);
  });
}
