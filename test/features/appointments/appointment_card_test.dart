import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/appointments/presentation/components/appointment_card.dart';

import '../../support/harness.dart';
import 'support/fixtures.dart';

/// BL-APPT-006: beside the wide "Payment pending" pill the date line was cut
/// to "Tomorrow, …". It now wraps, so the time is always readable.
void main() {
  testWidgets('the date line of an unpaid booking is not cut off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      screenHarness(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: AppointmentCard(
              appointment: Fixtures.appointment(),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // The first text in the card is the date line.
    final dateLine = find
        .descendant(
          of: find.byType(AppointmentCard),
          matching: find.byType(Text),
        )
        .first;
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: dateLine, matching: find.byType(RichText)),
    );
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '"${(tester.widget<Text>(dateLine)).data}" is cut off',
    );
  });
}
