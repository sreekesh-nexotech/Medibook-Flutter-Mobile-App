import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/widgets/states/app_not_found_view.dart';

import '../support/harness.dart';

/// The not-found screen's main button says where it goes: "Go to Home" by
/// default, "Go to Records" from a missing document (it used to say Home
/// and open Records).
void main() {
  testWidgets('the main button names its destination', (tester) async {
    await tester.pumpWidget(
      screenHarness(
        Scaffold(
          body: AppNotFoundView(
            headline: 'Document not found',
            onGoHome: () {},
            homeLabel: 'Go to Records',
          ),
        ),
      ),
    );
    expect(find.text('Go to Records'), findsOneWidget);
    expect(find.text('Go to Home'), findsNothing);
  });

  testWidgets('without a label it still says Go to Home', (tester) async {
    await tester.pumpWidget(
      screenHarness(Scaffold(body: AppNotFoundView(onGoHome: () {}))),
    );
    expect(find.text('Go to Home'), findsOneWidget);
  });
}
