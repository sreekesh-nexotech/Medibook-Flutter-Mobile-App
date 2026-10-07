import 'dart:io' show HttpDate;

import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/utils/server_clock.dart';

/// BL-CORE-007: deadlines the server sets are judged on the server's clock.
/// With the phone's clock ten minutes fast, the payment window closed while
/// four real minutes were left.
void main() {
  tearDown(ServerClock.reset);

  test('a phone ten minutes fast is corrected by the Date header', () {
    final phone = DateTime.utc(2026, 10, 5, 10, 10);
    final server = phone.subtract(const Duration(minutes: 10));
    ServerClock.observe(HttpDate.format(server), receivedAt: phone);

    expect(ServerClock.offset, const Duration(minutes: -10));
    // A deadline four minutes away on the server's clock...
    final deadline = server.add(const Duration(minutes: 4));
    // ...is reached when the phone's clock shows 14 minutes past.
    expect(
      ServerClock.onDeviceClock(deadline),
      phone.add(const Duration(minutes: 4)),
    );
  });

  test('a clock within a few seconds is left alone', () {
    final phone = DateTime.utc(2026, 10, 5, 10);
    ServerClock.observe(
      HttpDate.format(phone.add(const Duration(seconds: 2))),
      receivedAt: phone,
    );
    expect(ServerClock.offset, Duration.zero);
  });

  test('a missing or broken header changes nothing', () {
    ServerClock.observe(null);
    ServerClock.observe('not a date');
    expect(ServerClock.offset, Duration.zero);
  });
}
