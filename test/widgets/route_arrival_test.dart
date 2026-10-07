import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:medibook/core/widgets/route_arrival.dart';

/// A screen re-reads its data each time it is navigated back to — but not
/// when it is first opened, which is its normal load.
void main() {
  late List<String> arrivals;
  late GoRouter router;

  Widget screen(String name, {String? next}) => RouteArrival(
    onArrive: () => arrivals.add(name),
    child: Scaffold(body: Text('screen $name')),
  );

  setUp(() {
    arrivals = [];
    router = GoRouter(
      initialLocation: '/list',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => shell,
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/list', builder: (_, _) => screen('list')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/other', builder: (_, _) => screen('other')),
              ],
            ),
          ],
        ),
        GoRoute(path: '/detail/:id', builder: (_, _) => screen('detail')),
      ],
    );
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('opening a screen for the first time is not an arrival', (
    tester,
  ) async {
    await pump(tester);
    expect(arrivals, isEmpty);

    router.go('/other');
    await tester.pumpAndSettle();
    expect(arrivals, isEmpty, reason: 'first visit to the other tab');
  });

  testWidgets('switching back to a tab is an arrival', (tester) async {
    await pump(tester);
    router.go('/other');
    await tester.pumpAndSettle();

    router.go('/list');
    await tester.pumpAndSettle();
    expect(arrivals, ['list']);

    router.go('/other');
    await tester.pumpAndSettle();
    expect(arrivals, ['list', 'other']);
  });

  testWidgets('closing a screen opened over it is an arrival', (tester) async {
    await pump(tester);

    router.push('/detail/1');
    await tester.pumpAndSettle();
    expect(arrivals, isEmpty, reason: 'the detail was just opened');

    router.pop();
    await tester.pumpAndSettle();
    expect(arrivals, ['list']);
  });

  testWidgets('without a router the widget does nothing', (tester) async {
    await tester.pumpWidget(MaterialApp(home: screen('alone')));
    await tester.pumpAndSettle();
    expect(find.text('screen alone'), findsOneWidget);
    expect(arrivals, isEmpty);
  });
}
