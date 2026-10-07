import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../utils/logger.dart';

/// Whether the device can currently reach the internet.
///
/// HIVE spec, Scenario 3: when offline the app shows a persistent indicator,
/// does **not** retry continuously, and retries once when connectivity comes
/// back. This is the single source of that fact; screens read
/// [isOnlineProvider] and repositories subscribe to [ConnectivityMonitor.onReconnect].
///
/// Two inputs decide it:
/// * **a network route**, from the platform (Wi-Fi / mobile data / none);
/// * **reachability**, from the requests themselves. A route is not the
///   internet: on Wi-Fi with no internet (a hotel or hospital login page, a
///   router whose line is down) the platform still says "connected"
///   (BL-CACHE-019). After [unreachableAfter] requests in a row fail with no
///   connection or a timeout, the device is treated as offline; while it is,
///   [reachabilityProbe] is tried every [probeInterval], and any answer from
///   the server — a probe or a request — brings it back online.
class ConnectivityMonitor {
  ConnectivityMonitor({
    Connectivity? connectivity,
    this.unreachableAfter = 2,
    this.probeInterval = const Duration(seconds: 10),
  }) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Consecutive failed requests before a route is treated as offline.
  final int unreachableAfter;

  /// How often, while unreachable, [reachabilityProbe] is tried.
  final Duration probeInterval;

  /// A light request to the server; true when it answered at all. Set by
  /// bootstrap (this file depends on no client).
  Future<bool> Function()? reachabilityProbe;

  final StreamController<bool> _online = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _hasRoute = true;
  bool _reachable = true;
  int _failures = 0;
  Timer? _probe;

  bool get isOnline => _hasRoute && _reachable;

  /// The device has a network at all (not airplane mode, some Wi-Fi or
  /// mobile data) — whether or not the server can be reached on it.
  bool get hasRoute => _hasRoute;

  /// Emits the online flag whenever it changes.
  Stream<bool> get changes => _online.stream;

  /// Fires once each time the device goes from offline to online.
  Stream<void> get onReconnect =>
      changes.where((online) => online).map<void>((_) {});

  Future<void> start() async {
    try {
      _apply(await _connectivity.checkConnectivity());
      _sub = _connectivity.onConnectivityChanged.listen(_apply);
    } catch (error) {
      // A platform without the plugin (tests, desktop) is treated as online.
      AppLogger.warning(
        'Connectivity plugin unavailable; assuming online',
        name: 'connectivity',
        error: error,
      );
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final hasRoute =
        results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
    if (hasRoute == _hasRoute) return;
    _update(() {
      _hasRoute = hasRoute;
      // A new route is worth trying from scratch.
      if (hasRoute) _markReachable();
    });
  }

  /// A request reached the server (any HTTP status counts).
  void reportReachable() {
    if (_reachable && _failures == 0) return;
    _update(_markReachable);
  }

  /// A request failed with no connection or a timeout.
  void reportUnreachable() {
    if (!_hasRoute || !_reachable) return;
    _failures++;
    if (_failures < unreachableAfter) return;
    _update(() => _reachable = false);
    _probe ??= Timer.periodic(probeInterval, (_) => _runProbe());
  }

  void _markReachable() {
    _failures = 0;
    _reachable = true;
    _probe?.cancel();
    _probe = null;
  }

  bool _probing = false;

  Future<void> _runProbe() async {
    final probe = reachabilityProbe;
    if (probe == null || _probing || !_hasRoute) return;
    _probing = true;
    try {
      if (await probe()) reportReachable();
    } catch (_) {
      // Still unreachable; the next tick tries again.
    } finally {
      _probing = false;
    }
  }

  /// Runs [change] and emits once if [isOnline] flipped.
  void _update(void Function() change) {
    final before = isOnline;
    change();
    final after = isOnline;
    if (before == after || _online.isClosed) return;
    AppLogger.info(
      after
          ? 'Back online'
          : (_hasRoute ? 'Offline (no internet on this network)' : 'Offline'),
      name: 'connectivity',
    );
    _online.add(after);
  }

  Future<void> dispose() async {
    _probe?.cancel();
    await _sub?.cancel();
    await _online.close();
  }
}

/// The process-wide monitor. Overridden in bootstrap with a started instance.
final connectivityMonitorProvider = Provider<ConnectivityMonitor>(
  (ref) => ConnectivityMonitor(),
);

/// True while the device has a network route. Screens watch this for the
/// offline indicator (Scenario 3).
final isOnlineProvider = StreamProvider<bool>((ref) {
  final monitor = ref.watch(connectivityMonitorProvider);
  return monitor.changes.startWith(monitor.isOnline);
});

extension<T> on Stream<T> {
  Stream<T> startWith(T first) async* {
    yield first;
    yield* this;
  }
}
