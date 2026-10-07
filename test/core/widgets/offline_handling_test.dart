import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/error_view.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/core/widgets/app_refresh.dart';
import 'package:medibook/core/widgets/offline_bar.dart';
import 'package:medibook/core/widgets/toast/toast_controller.dart';

/// Offline audit (6 Oct 2026): one offline bar for every screen, error views
/// that reload when the connection returns, and a pull that says it is
/// offline instead of spinning for nothing.
void main() {
  late _FakeMonitor monitor;

  setUp(() => monitor = _FakeMonitor());
  tearDown(() => monitor.close());

  Widget app(Widget child, {bool bar = true}) => ProviderScope(
    overrides: [connectivityMonitorProvider.overrideWithValue(monitor)],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, _) => MaterialApp(
        home: bar
            ? OfflineBar(child: Scaffold(body: child))
            : Scaffold(body: child),
      ),
    ),
  );

  testWidgets('the bar shows offline and leaves when back online', (
    tester,
  ) async {
    monitor.online = false;
    await tester.pumpWidget(app(const Text('page')));
    await tester.pump();
    expect(find.bySemanticsLabel(OfflineBar.noNetwork), findsOneWidget);
    expect(find.text('page'), findsOneWidget);

    monitor.set(true);
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel(OfflineBar.noNetwork), findsNothing);
  });

  testWidgets('a network but no server says "Can\'t reach Medibook"', (
    tester,
  ) async {
    monitor
      ..online = false
      ..route = true;
    await tester.pumpWidget(app(const Text('page')));
    await tester.pump();
    expect(find.bySemanticsLabel(OfflineBar.unreachable), findsOneWidget);
  });

  testWidgets('an offline error view retries by itself on reconnect', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      app(
        AppErrorView(failure: const NetworkFailure(), onRetry: () => retries++),
      ),
    );
    await tester.pump();
    monitor.reconnect();
    await tester.pump();
    expect(retries, 1);
  });

  testWidgets('a server error does not retry by itself', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      app(
        AppInlineError(
          failure: const ServerFailure(),
          onRetry: () => retries++,
        ),
      ),
    );
    await tester.pump();
    monitor.reconnect();
    await tester.pump();
    expect(retries, 0);
  });

  testWidgets('a pull while offline says so and does not reload', (
    tester,
  ) async {
    monitor.online = false;
    var reloads = 0;
    late WidgetRef ref;
    await tester.pumpWidget(
      app(
        Consumer(
          builder: (context, r, _) {
            ref = r;
            return AppRefreshIndicator(
              onRefresh: () async => reloads++,
              child: ListView(children: const [SizedBox(height: 900)]),
            );
          },
        ),
        bar: false,
      ),
    );
    final shown = <String?>[];
    ref.listenManual(
      toastControllerProvider,
      (_, next) => shown.add(next?.text),
    );
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(reloads, 0);
    expect(shown, contains(AppRefreshIndicator.offlineMessage));
  });
}

class _FakeMonitor extends ConnectivityMonitor {
  final _changes = StreamController<bool>.broadcast();
  bool online = true;
  bool route = false;

  void set(bool value) {
    online = value;
    _changes.add(value);
  }

  void reconnect() => set(true);

  Future<void> close() => _changes.close();

  @override
  bool get isOnline => online;

  @override
  bool get hasRoute => route;

  @override
  Stream<bool> get changes => _changes.stream;

  @override
  Stream<void> get onReconnect =>
      _changes.stream.where((v) => v).map<void>((_) {});
}
