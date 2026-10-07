import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/utils/date_utils.dart';
import 'package:medibook/features/appointments/application/usecases/hospital_time.dart';
import 'package:medibook/features/booking/domain/entities/hospital_clock.dart';

/// §1.11: instants are UTC on the wire and are shown in the hospital's zone —
/// the one the server names on `appointment.hospital.timezone` and on the
/// slot grid — never the device's.
void main() {
  // 03:30 UTC on 2 Oct 2026.
  final instant = DateTime.utc(2026, 10, 2, 3, 30);

  group('HospitalZones', () {
    test('resolves the zones the platform serves; null reads as IST', () {
      expect(
        HospitalZones.offsetOf('Asia/Kolkata'),
        const Duration(hours: 5, minutes: 30),
      );
      expect(
        HospitalZones.offsetOf(null),
        HospitalZones.offsetOf('Asia/Kolkata'),
      );
      expect(HospitalZones.offsetOf('Asia/Dubai'), const Duration(hours: 4));
      expect(HospitalZones.offsetOf('UTC'), Duration.zero);
    });

    test('a zone with daylight saving is not guessed at', () {
      expect(HospitalZones.offsetOf('Europe/London'), isNull);
      expect(HospitalZones.isSupported('Europe/London'), isFalse);
      expect(HospitalZones.isSupported('Asia/Kolkata'), isTrue);
    });
  });

  group('HospitalTime', () {
    test('renders in the zone the appointment names', () {
      expect(HospitalTime.time(instant, timezone: 'Asia/Kolkata'), '9:00 AM');
      expect(HospitalTime.time(instant, timezone: 'Asia/Dubai'), '7:30 AM');
      expect(
        HospitalTime.time(instant, timezone: 'Asia/Singapore'),
        '11:30 AM',
      );
      expect(
        HospitalTime.dateAndTime(instant, timezone: 'Asia/Kolkata'),
        '2 Oct 2026 · 9:00 AM',
      );
    });

    test('a payload without a zone reads as Asia/Kolkata', () {
      expect(HospitalTime.time(instant), '9:00 AM');
    });

    test('the calendar day follows the zone, not UTC', () {
      // 20:00 UTC on 1 Oct is already 2 Oct in Kochi and Singapore.
      final late = DateTime.utc(2026, 10, 1, 20);
      expect(HospitalTime.dayMonthYear(late, timezone: 'UTC'), '1 Oct 2026');
      expect(
        HospitalTime.dayMonthYear(late, timezone: 'Asia/Kolkata'),
        '2 Oct 2026',
      );
      expect(HospitalTime.wallClock(late, timezone: 'Asia/Singapore').day, 2);
    });

    test('an unlisted zone falls back to the device zone', () {
      final wall = HospitalTime.wallClock(instant, timezone: 'Europe/London');
      final local = instant.toLocal();
      expect(wall.hour, local.hour);
      expect(wall.minute, local.minute);
    });
  });

  group('HospitalClock', () {
    test('shares the same offsets', () {
      final wall = HospitalClock.wallClock(instant, timezone: 'Asia/Kolkata');
      expect((wall.hour, wall.minute), (9, 0));
      expect(HospitalClock.isSupported('Asia/Kolkata'), isTrue);
      expect(HospitalClock.isSupported('America/New_York'), isFalse);
      expect(
        HospitalClock.localDate(DateTime.utc(2026, 10, 1, 20), timezone: 'UTC'),
        '2026-10-01',
      );
    });
  });
}
