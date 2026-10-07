import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/network/models/page.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/features/booking/application/providers/discovery_providers.dart';
import 'package:medibook/features/booking/domain/entities/department.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';
import 'package:medibook/features/booking/domain/entities/hospital.dart';
import 'package:medibook/features/booking/domain/entities/person_summary.dart';
import 'package:medibook/features/booking/domain/entities/slots.dart';
import 'package:medibook/features/booking/domain/repositories/discovery_repository.dart';
import 'package:medibook/features/booking/presentation/components/booking_doctor_card.dart';
import 'package:medibook/features/booking/presentation/components/slot_labels.dart';
import 'package:medibook/features/booking/presentation/screen/booking_screen.dart';

import '../../support/harness.dart';
import '../../support/offline_overrides.dart';

/// The screens behind Home's Quick Booking and Available Services show what
/// the server sends where they used to show the app's own words (Home quick
/// links audit, 6 Oct 2026).
void main() {
  group('booking from a service tile (a department code only)', () {
    Future<void> open(WidgetTester tester, {required String step}) async {
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      HiveInit.store = InMemoryLocalStore();
      await tester.pumpWidget(
        screenHarness(
          BookingScreen(step: step, dept: 'general_medicine'),
          overrides: [
            ...offlineOverrides(),
            discoveryRepositoryProvider.overrideWithValue(_Discovery()),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('step 2 names the department from the server', (tester) async {
      await open(tester, step: '2');
      expect(
        find.text('Hospitals with a General Medicine department.'),
        findsOneWidget,
      );
      expect(find.text('Doctors are listed per hospital.'), findsNothing);
    });

    testWidgets('a search with no match suggests the server names', (
      tester,
    ) async {
      await open(tester, step: '1');
      await tester.enterText(find.byType(TextField).first, 'heart');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Try a department name like "Cardiology" or "General Medicine", '
          'or clear the search to see all 2.',
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('a doctor not booked online gives the hospital number', (
    tester,
  ) async {
    await tester.pumpWidget(
      screenHarness(
        Scaffold(
          body: BookingDoctorCard(
            doctor: const DoctorCard(
              id: 'doc1',
              slug: 'doc1',
              name: 'Dr. Harish Menon',
              department: DepartmentRef(
                id: 'd1',
                code: 'cardiology',
                name: 'Cardiology',
              ),
              hospital: DoctorHospitalRef(
                id: 'h1',
                name: 'Lakeshore Multispeciality Hospital',
                city: 'Kochi',
              ),
              consultationFeePaise: 90000,
              isBookableOnline: false,
            ),
            selected: false,
            onView: () {},
            onBook: () {},
            hospitalPhone: '+914842701000',
          ),
        ),
      ),
    );
    expect(
      find.text(
        'Not bookable online. Call the hospital on +914842701000 to book.',
      ),
      findsOneWidget,
    );
  });

  group('wording from the server state', () {
    test('a slot picked earlier says why it is no longer free', () {
      expect(
        SlotLabels.noLongerFree(SlotState.booked, '9:00 AM'),
        'The 9:00 AM slot has just been taken. Pick another.',
      );
      expect(
        SlotLabels.noLongerFree(SlotState.past, '9:00 AM'),
        'The 9:00 AM slot has passed. Pick another.',
      );
      expect(
        SlotLabels.noLongerFree(SlotState.held, '9:00 AM'),
        contains('booking the 9:00 AM slot right now'),
      );
      expect(
        SlotLabels.noLongerFree(SlotState.blocked, '9:00 AM'),
        contains('no longer open for booking'),
      );
    });

    test('an unpaid booking says when it must be paid', () {
      expect(
        SlotLabels.payBefore(
          DateTime.utc(2026, 10, 6, 16, 1),
          timezone: 'Asia/Kolkata',
        ),
        'by 9:31 PM',
      );
      expect(SlotLabels.payBefore(null), 'before the hold runs out');
    });

    test('booking names a family member as Family Members does', () {
      PersonSummary person(String relation, {String? gender}) => PersonSummary(
        id: relation,
        firstName: 'X',
        relation: relation,
        isSelf: relation == 'self',
        gender: gender,
      );
      expect(person('spouse', gender: 'female').relationLabel, 'Wife');
      expect(person('child', gender: 'male').relationLabel, 'Son');
      expect(person('parent').relationLabel, 'Parent');
      expect(person('other').relationLabel, 'Family member');
    });
  });
}

CachedResult<T> _fresh<T>(T value) => CachedResult<T>(
  value: value,
  source: CacheSource.network,
  cachedAt: DateTime.now(),
);

class _Discovery implements DiscoveryRepository {
  @override
  Stream<CachedResult<Page<DepartmentSummary>>> departments({
    bool forceRefresh = false,
  }) => Stream.value(
    _fresh(
      const Page(
        results: [
          DepartmentSummary(
            code: 'cardiology',
            name: 'Cardiology',
            hospitalCount: 1,
          ),
          DepartmentSummary(
            code: 'general_medicine',
            name: 'General Medicine',
            hospitalCount: 2,
          ),
        ],
        page: 1,
        pageSize: 50,
        total: 2,
        hasNext: false,
      ),
    ),
  );

  @override
  Stream<CachedResult<Page<HospitalCard>>> hospitals(
    HospitalsQuery query, {
    bool forceRefresh = false,
  }) => Stream.value(
    _fresh(
      const Page(
        results: [
          HospitalCard(
            id: 'h1',
            slug: 'h1',
            name: 'Lakeshore Multispeciality Hospital',
            city: 'Kochi',
            departments: [
              DepartmentRef(
                id: 'd2',
                code: 'general_medicine',
                name: 'General Medicine',
              ),
            ],
            onlineBookingEnabled: true,
          ),
        ],
        page: 1,
        pageSize: 50,
        total: 1,
        hasNext: false,
      ),
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
