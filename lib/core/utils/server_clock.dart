import 'dart:io' show HttpDate;

import 'package:meta/meta.dart';

/// The server's time, learned from the `Date` header of every API response.
///
/// Deadlines the server sets — above all a booking's 5-minute payment window
/// (`booking_deadline_at`) — must be judged on the server's clock. Judged on
/// the phone's, a clock set ten minutes fast closed the window while four
/// real minutes were left (BL-CORE-007).
abstract final class ServerClock {
  ServerClock._();

  /// Server time minus phone time. Zero until a response has been seen, or
  /// while the two agree to within [_tolerance] (the header has one-second
  /// resolution, and the request itself takes time).
  static Duration _offset = Duration.zero;

  static const Duration _tolerance = Duration(seconds: 3);

  static Duration get offset => _offset;

  /// Now, on the server's clock.
  static DateTime now() => DateTime.now().add(_offset);

  /// When the phone's own clock reaches [serverTime] — what a countdown
  /// driven by the phone's clock must count to.
  static DateTime onDeviceClock(DateTime serverTime) =>
      serverTime.subtract(_offset);

  /// Learn from a response's `Date` header. Unparseable or missing headers
  /// are ignored.
  static void observe(String? dateHeader, {DateTime? receivedAt}) {
    if (dateHeader == null || dateHeader.isEmpty) return;
    final DateTime server;
    try {
      server = HttpDate.parse(dateHeader);
    } catch (_) {
      return;
    }
    final difference = server.difference(receivedAt ?? DateTime.now());
    _offset = difference.abs() <= _tolerance ? Duration.zero : difference;
  }

  @visibleForTesting
  static void reset() => _offset = Duration.zero;
}
