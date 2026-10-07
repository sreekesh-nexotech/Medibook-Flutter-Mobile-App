import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';

/// BL-CACHE-019: Wi-Fi with no internet. The platform still reports a
/// connection, so the requests themselves decide.
void main() {
  test('two failed requests in a row mean offline; one does not', () {
    final monitor = ConnectivityMonitor();
    addTearDown(monitor.dispose);

    monitor.reportUnreachable();
    expect(monitor.isOnline, isTrue, reason: 'one failure is not enough');
    monitor.reportReachable();
    monitor.reportUnreachable();
    expect(monitor.isOnline, isTrue, reason: 'a success resets the count');
    monitor.reportUnreachable();
    expect(monitor.isOnline, isFalse);
  });

  test('any answer from the server brings it back, with a reconnect', () async {
    final monitor = ConnectivityMonitor();
    addTearDown(monitor.dispose);
    final reconnects = <void>[];
    final sub = monitor.onReconnect.listen(reconnects.add);
    addTearDown(sub.cancel);

    monitor
      ..reportUnreachable()
      ..reportUnreachable();
    expect(monitor.isOnline, isFalse);
    monitor.reportReachable();
    await Future<void>.delayed(Duration.zero);
    expect(monitor.isOnline, isTrue);
    expect(reconnects, hasLength(1));
  });

  test('while offline the probe runs until the server answers', () async {
    final monitor = ConnectivityMonitor(
      probeInterval: const Duration(milliseconds: 20),
    );
    addTearDown(monitor.dispose);
    var answers = false;
    var probes = 0;
    monitor.reachabilityProbe = () async {
      probes++;
      return answers;
    };

    monitor
      ..reportUnreachable()
      ..reportUnreachable();
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(probes, greaterThanOrEqualTo(2));
    expect(monitor.isOnline, isFalse);

    answers = true;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(monitor.isOnline, isTrue);

    // Back online: no more probing.
    final settled = probes;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(probes, settled);
  });
}
