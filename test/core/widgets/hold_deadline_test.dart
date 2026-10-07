import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/widgets/hold_deadline.dart';

/// Appointments audit (6 Oct 2026): an unpaid hold's card leaves at its
/// deadline, and the list is re-read until the server has released it.
void main() {
  testWidgets('hides at the deadline and re-checks every 15 s', (tester) async {
    var rechecks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HoldDeadline(
          deadline: DateTime.now().add(const Duration(seconds: 5)),
          onDeadline: () => rechecks++,
          child: const Text('Pay now'),
        ),
      ),
    );
    expect(find.text('Pay now'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Pay now'), findsNothing);
    expect(rechecks, 1);

    await tester.pump(const Duration(seconds: 15));
    expect(rechecks, 2);

    // The booking is gone: the card leaves the tree and the re-checks stop.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 60));
    expect(rechecks, 2);
  });

  testWidgets('a hold already past its deadline is hidden at once', (
    tester,
  ) async {
    var rechecks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HoldDeadline(
          deadline: DateTime.now().subtract(const Duration(minutes: 1)),
          onDeadline: () => rechecks++,
          child: const Text('Pay now'),
        ),
      ),
    );
    // The re-read runs just after the first frame, never during a build.
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Pay now'), findsNothing);
    expect(rechecks, 1);
    await tester.pumpWidget(const SizedBox());
  });
}
