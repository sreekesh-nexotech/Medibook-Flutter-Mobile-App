import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/network/models/page.dart';
import 'package:medibook/core/storage/cache/cached_fetcher.dart';
import 'package:medibook/core/widgets/app_icon.dart';
import 'package:medibook/core/widgets/toast/toast_controller.dart';
import 'package:medibook/features/booking/application/providers/discovery_providers.dart';
import 'package:medibook/features/booking/domain/entities/availability.dart';
import 'package:medibook/features/booking/domain/entities/department.dart';
import 'package:medibook/features/booking/domain/entities/doctor.dart';
import 'package:medibook/features/booking/domain/entities/hospital.dart';
import 'package:medibook/features/booking/domain/entities/slots.dart';
import 'package:medibook/features/booking/domain/repositories/availability_repository.dart';
import 'package:medibook/features/booking/domain/repositories/discovery_repository.dart';
import 'package:medibook/features/booking/presentation/screen/doctor_detail_screen.dart';
import 'package:medibook/features/booking/presentation/screen/hospital_detail_screen.dart';

import '../../support/harness.dart';
import '../../support/offline_overrides.dart';

/// Doctor Details and Hospital Details show what the server sends where
/// they used to show the app's own words (Doctor & Hospital audit,
/// 6 Oct 2026): a holiday's department, each department's icon, the
/// doctor's years as given, the hospital's number for a doctor not booked
/// online, a closed day that is not "fully booked", and a past slot that
/// is not "taken".
void main() {
  const cardiology = DepartmentRef(
    id: 'd1',
    code: 'cardiology',
    name: 'Cardiology',
  );

  HospitalDetail hospital() => HospitalDetail(
    card: const HospitalCard(
      id: 'h1',
      slug: 'h1',
      name: 'Lakeshore Multispeciality Hospital',
      city: 'Kochi',
      departments: [
        cardiology,
        DepartmentRef(id: 'd2', code: 'general_medicine', name: 'General'),
      ],
      onlineBookingEnabled: true,
    ),
    timezone: 'Asia/Kolkata',
    hours: const [],
    holidays: const [
      HospitalHoliday(
        id: 'x',
        name: 'Foundation day',
        dateFrom: '2030-01-08',
        dateTo: '2030-01-08',
        departmentId: 'd1',
      ),
    ],
    banners: const [],
    bookingWindowDays: 30,
    followUpWindowDays: 7,
    version: 1,
    phoneE164: '+914842701000',
  );

  DoctorCard card({bool online = true}) => DoctorCard(
    id: 'doc1',
    slug: 'doc1',
    name: 'Dr. Harish Menon',
    department: cardiology,
    hospital: const DoctorHospitalRef(
      id: 'h1',
      name: 'Lakeshore Multispeciality Hospital',
      city: 'Kochi',
    ),
    consultationFeePaise: 90000,
    isBookableOnline: online,
    experienceYears: 18,
  );

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget screen, {
    bool online = true,
  }) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    HiveInit.store = InMemoryLocalStore();
    await tester.pumpWidget(
      screenHarness(
        screen,
        overrides: [
          ...offlineOverrides(),
          discoveryRepositoryProvider.overrideWithValue(
            _Discovery(hospital(), card(online: online)),
          ),
          availabilityRepositoryProvider.overrideWithValue(_Availability()),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byWidget(screen)));
  }

  group('Hospital Details', () {
    testWidgets('a holiday for one department names it', (tester) async {
      await pump(tester, const HospitalDetailScreen(id: 'h1'));
      expect(find.text('Foundation day (Cardiology)'), findsOneWidget);
      expect(find.textContaining('one department'), findsNothing);
    });

    testWidgets('each speciality chip shows its department icon', (
      tester,
    ) async {
      await pump(tester, const HospitalDetailScreen(id: 'h1'));
      expect(
        find.byWidgetPredicate(
          (w) => w is AppIcon && w.name == DeptIcon.cardiology,
        ),
        findsOneWidget,
      );
    });
  });

  group('Doctor Details', () {
    testWidgets('the years are the server figure, not "18+"', (tester) async {
      await pump(tester, const DoctorDetailScreen(id: 'doc1'));
      expect(find.text('18'), findsOneWidget);
      expect(find.text('18+'), findsNothing);
    });

    testWidgets('a doctor not booked online gives the hospital number', (
      tester,
    ) async {
      await pump(tester, const DoctorDetailScreen(id: 'doc1'), online: false);
      expect(
        find.text(
          'This doctor does not take online bookings. Call the hospital on '
          '+914842701000 to book.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a closed day is not "fully booked"; a full one is', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const DoctorDetailScreen(id: 'doc1'));
      expect(find.bySemanticsLabel('Mon 7, not available'), findsOneWidget);
      expect(find.bySemanticsLabel('Wed 9, fully booked'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Mon 7.*fully')), findsNothing);
      semantics.dispose();
    });

    testWidgets('a past slot says it has passed, not that it is taken', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final container = await pump(
        tester,
        const DoctorDetailScreen(id: 'doc1'),
      );
      expect(find.bySemanticsLabel('9:00 AM, passed'), findsOneWidget);
      await tester.tap(find.text('9:00 AM'));
      await tester.pump();
      expect(
        container.read(toastControllerProvider)?.text,
        'That time has already passed.',
      );
      semantics.dispose();
    });
  });
}

CachedResult<T> _fresh<T>(T value) => CachedResult<T>(
  value: value,
  source: CacheSource.network,
  cachedAt: DateTime.now(),
);

class _Discovery implements DiscoveryRepository {
  _Discovery(this._hospital, this._doctor);

  final HospitalDetail _hospital;
  final DoctorCard _doctor;

  @override
  Stream<CachedResult<HospitalDetail>> hospital(
    String hospitalId, {
    bool forceRefresh = false,
  }) => Stream.value(_fresh(_hospital));

  @override
  Stream<CachedResult<Page<DoctorCard>>> hospitalDoctors(
    HospitalDoctorsQuery query, {
    bool forceRefresh = false,
  }) => Stream.value(
    _fresh(
      Page(results: [_doctor], page: 1, pageSize: 50, total: 1, hasNext: false),
    ),
  );

  @override
  Stream<CachedResult<DoctorDetail>> doctor(
    String doctorId, {
    bool forceRefresh = false,
  }) => Stream.value(
    _fresh(DoctorDetail(card: _doctor, slotLengthMin: 10, version: 1)),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Mon 7 Jan 2030: the session is over (`closed`); Tue 8: open, with one
/// slot already past; Wed 9: `full`.
class _Availability implements AvailabilityRepository {
  static AvailabilityDay _day(String date, SessionAvailability state) {
    final day = int.parse(date.substring(8));
    return AvailabilityDay(
      date: date,
      sessions: [
        AvailabilitySession(
          sessionId: 's$day',
          sessionCode: 'morning',
          label: 'Morning OPD',
          state: state,
          startsAt: DateTime.utc(2030, 1, day, 3, 30),
          endsAt: DateTime.utc(2030, 1, day, 6, 30),
        ),
      ],
    );
  }

  @override
  Stream<CachedResult<DoctorAvailability>> availability(
    String doctorId, {
    String? from,
    String? to,
    bool forceRefresh = false,
  }) => Stream.value(
    _fresh(
      DoctorAvailability(
        doctorId: doctorId,
        from: '2030-01-07',
        to: '2030-01-09',
        dates: [
          _day('2030-01-07', SessionAvailability.closed),
          _day('2030-01-08', SessionAvailability.available),
          _day('2030-01-09', SessionAvailability.full),
        ],
      ),
    ),
  );

  @override
  Stream<CachedResult<DaySlots>> slots(
    String doctorId, {
    required String date,
    bool forceRefresh = false,
  }) => Stream.value(
    _fresh(
      DaySlots(
        doctorId: doctorId,
        date: date,
        timezone: 'Asia/Kolkata',
        sessions: [
          SlotSession(
            sessionId: 's8',
            sessionCode: 'morning',
            label: 'Morning OPD',
            status: SessionStatus.open,
            startsAt: DateTime.utc(2030, 1, 8, 3, 30),
            endsAt: DateTime.utc(2030, 1, 8, 6, 30),
            slots: [
              Slot(
                id: 'past',
                sessionId: 's8',
                startsAt: DateTime.utc(2030, 1, 8, 3, 30),
                endsAt: DateTime.utc(2030, 1, 8, 3, 40),
                state: SlotState.past,
              ),
              Slot(
                id: 'free',
                sessionId: 's8',
                startsAt: DateTime.utc(2030, 1, 8, 3, 40),
                endsAt: DateTime.utc(2030, 1, 8, 3, 50),
                state: SlotState.available,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
