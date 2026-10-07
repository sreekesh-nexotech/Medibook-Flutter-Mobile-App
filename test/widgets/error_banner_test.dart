import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/error_view.dart';

import '../support/harness.dart';

/// A tappable banner (the amber "Data from … ago • Tap to refresh" bar) used
/// to carry its sentence twice for a screen reader: once as the label and
/// once from the text inside it (found while running BL-CACHE-003).
void main() {
  const message = 'Data from 1 day ago • Tap to refresh';

  testWidgets('a tappable banner is announced once and can be activated', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      screenHarness(
        Scaffold(
          body: AppErrorBanner(message: message, onTap: () => taps++),
        ),
      ),
    );
    await tester.pump();

    final data = tester.getSemantics(find.text(message)).getSemanticsData();
    expect(data.label, message);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    await tester.tap(find.text(message));
    expect(taps, 1);
    semantics.dispose();
  });

  testWidgets('an informational banner is announced once', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      screenHarness(const Scaffold(body: AppErrorBanner(message: message))),
    );
    await tester.pump();

    expect(tester.getSemantics(find.text(message)).label, message);
    semantics.dispose();
  });
}
