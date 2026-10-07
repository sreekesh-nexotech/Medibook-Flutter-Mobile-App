import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/monitoring/crash_reporting.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// What [SentryCrashSink] hands the SDK. Events are intercepted in
/// `beforeSend` and dropped, so nothing leaves the test.
void main() {
  late List<SentryEvent> events;
  const sink = SentryCrashSink();

  setUp(() async {
    events = <SentryEvent>[];
    await Sentry.init((options) {
      options
        ..dsn = 'https://public@o0.ingest.sentry.io/0'
        ..beforeSend = (event, hint) {
          events.add(event);
          return null;
        };
    });
  });

  tearDown(Sentry.close);

  test('a handled failure carries its reason tag and context', () async {
    sink.recordError(
      const NetworkFailure(),
      StackTrace.current,
      reason: 'failure:network',
      context: const {'failure_code': 'network', 'retryable': true},
    );
    await pumpEventQueue();

    final event = events.single;
    expect(event.throwable, isA<NetworkFailure>());
    expect(event.tags?['reason'], 'failure:network');
    expect(event.contexts['medibook'], {
      'failure_code': 'network',
      'retryable': true,
    });
    expect(event.level, isNot(SentryLevel.fatal));
  });

  test('a fatal report is sent at fatal level', () async {
    sink.recordError(StateError('boom'), StackTrace.current, fatal: true);
    await pumpEventQueue();

    expect(events.single.level, SentryLevel.fatal);
  });

  test('the user is identified by id only, and cleared on reset', () async {
    sink.setUserIdentifier('usr_42');
    sink.recordError(StateError('one'), null);
    await pumpEventQueue();
    expect(events.last.user?.id, 'usr_42');
    expect(events.last.user?.email, isNull);
    expect(events.last.user?.name, isNull);

    sink.setUserIdentifier(null);
    sink.recordError(StateError('two'), null);
    await pumpEventQueue();
    expect(events.last.user?.id, isNull);
  });

  test('custom keys and breadcrumbs ride along on the next report', () async {
    sink
      ..setCustomKey('environment', 'stg')
      ..log('opened booking');
    await pumpEventQueue();
    sink.recordError(StateError('later'), null);
    await pumpEventQueue();

    final event = events.single;
    expect(event.tags?['environment'], 'stg');
    expect(
      event.breadcrumbs?.map((b) => b.message),
      contains('opened booking'),
    );
  });

  test('it tells CrashReporting the SDK owns uncaught errors', () {
    expect(sink.capturesUncaughtErrors, isTrue);
    expect(const LoggingCrashSink().capturesUncaughtErrors, isFalse);
  });
}
