import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/router/app_routes.dart';

/// The two route changes this slice made in the shared registry.
void main() {
  test('queuePath carries the appointment id', () {
    expect(AppRoutes.queuePath('appt-1'), '/queue/appt-1');
    expect(
      AppRoutes.fromDeepLink(Uri.parse('medibook://queue/appt-1')),
      '/queue/appt-1',
    );
  });

  test('an old reschedule deep link lands on the appointment detail', () {
    expect(
      AppRoutes.fromDeepLink(Uri.parse('medibook://reschedule/appt-1')),
      AppRoutes.appointmentDetailPath('appt-1'),
    );
    expect(
      AppRoutes.fromDeepLink(Uri.parse('https://medibook.app/reschedule')),
      AppRoutes.appointments,
    );
  });

  // Checklist NAV-006: ids are plain text; traversal, markup and over-long
  // ids are not-founds, never another screen.
  test('support ticket links open the thread', () {
    expect(
      AppRoutes.fromDeepLink(Uri.parse('medibook://support/tickets/tkt-1')),
      '/support/tickets/tkt-1',
    );
    expect(
      AppRoutes.fromDeepLink(Uri.parse('medibook://support/tickets/a.b')),
      isNull,
    );
    expect(AppRoutes.fromDeepLink(Uri.parse('medibook://support')), '/support');
    expect(
      AppRoutes.fromDeepLink(Uri.parse('medibook://support/tickets')),
      '/support/tickets',
    );
  });

  test('hostile link ids are refused', () {
    for (final link in [
      'medibook://appointment/..%2F..%2Fprofile',
      'medibook://doctor/%3Cscript%3Ealert(1)%3C%2Fscript%3E',
      'medibook://hospital/${'a' * 300}',
      'medibook://receipt/a.b',
    ]) {
      expect(AppRoutes.fromDeepLink(Uri.parse(link)), isNull, reason: link);
    }
    expect(
      AppRoutes.fromDeepLink(
        Uri.parse(
          'medibook://appointment/01a0ee2c-5ad7-7df3-889a-696ae03f15c8',
        ),
      ),
      '/appointment/01a0ee2c-5ad7-7df3-889a-696ae03f15c8',
    );
  });
}
