import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/widgets/app_bottom_sheet.dart';
import 'package:medibook/core/widgets/app_unsaved_changes_guard.dart';

import '../support/harness.dart';

/// A form in a sheet asks before unsaved changes are dropped. The sheet's
/// close button used to pop it straight past the form's guard, so the
/// Records edit sheet lost an edit without a word.
void main() {
  Future<bool?>? result;

  Future<void> open(
    WidgetTester tester, {
    required bool unsaved,
    bool? enableDrag,
  }) async {
    await tester.pumpWidget(
      screenHarness(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = showAppSheet<bool>(
                context,
                title: 'Edit document',
                enableDrag: enableDrag,
                builder: (_) => AppUnsavedChangesGuard(
                  hasUnsavedChanges: unsaved,
                  child: const SizedBox(height: 200, child: Text('The form')),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('The form'), findsOneWidget);
  }

  testWidgets('close asks first when there are unsaved changes', (
    tester,
  ) async {
    await open(tester, unsaved: true);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();
    expect(find.text('The form'), findsOneWidget, reason: 'kept');

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('The form'), findsNothing);
    expect(await result, isNull, reason: 'a discarded sheet saves nothing');
  });

  testWidgets('with nothing changed, close shuts the sheet at once', (
    tester,
  ) async {
    await open(tester, unsaved: false);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsNothing);
    expect(find.text('The form'), findsNothing);
  });

  // A swipe closes a sheet without asking its guard, so a guarded form
  // turns swiping off.
  testWidgets('a sheet that cannot be swiped stays when dragged down', (
    tester,
  ) async {
    await open(tester, unsaved: true, enableDrag: false);
    await tester.drag(find.text('Edit document'), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('The form'), findsOneWidget);
  });
}
