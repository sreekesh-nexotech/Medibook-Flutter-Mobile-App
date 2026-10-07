import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/features/dashboard/presentation/components/home_header.dart';

import '../../support/harness.dart';
import '../../support/offline_overrides.dart';

/// BL-HOME-009: the greeting uses the first name only, and an account with no
/// first name gets a greeting without one — never a stray "!" or a
/// placeholder name.
void main() {
  setUp(() => HiveInit.store = InMemoryLocalStore());

  Future<void> pump(WidgetTester tester, String name) async {
    await tester.pumpWidget(
      harness(
        HomeHeader(name: name, onBell: () {}, onSearchTap: () {}),
        overrides: offlineOverrides(),
      ),
    );
    await tester.pump();
  }

  testWidgets('greets by the first name only', (tester) async {
    await pump(tester, 'Sanjay Varma');
    expect(find.text('Welcome back,'), findsOneWidget);
    expect(find.text('Sanjay!'), findsOneWidget);
  });

  for (final blank in ['', '   ']) {
    testWidgets('a blank name ("$blank") gives a greeting without a name', (
      tester,
    ) async {
      await pump(tester, blank);
      expect(find.text('Welcome back!'), findsOneWidget);
      expect(find.text('!'), findsNothing);
      expect(find.text('Welcome back,'), findsNothing);
    });
  }
}
