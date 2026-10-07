import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/profile/presentation/screen/profile_edit_screen.dart';

import '../../support/harness.dart';

/// BL-PROF-020: the sign-in number cannot also be the alternate number. The
/// server refused it, the sheet closed, and the toast pointed at
/// "highlighted fields" that were gone.
void main() {
  testWidgets('the sign-in number is refused in the sheet, which stays open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? result = 'not closed';

    await tester.pumpWidget(
      screenHarness(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showAlternatePhoneSheet(
                context,
                current: null,
                mainPhoneE164: '+919808683257',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '9808683257');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('This is already your sign-in number. Enter a different one.'),
      findsOneWidget,
    );
    expect(result, 'not closed');
  });
}
