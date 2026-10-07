import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medibook/core/widgets/app_button.dart';
import 'package:medibook/core/widgets/app_badge.dart';
import 'package:medibook/core/widgets/app_tag.dart';
import 'package:medibook/core/widgets/app_checkbox.dart';
import 'package:medibook/core/widgets/app_radio.dart';
import 'package:medibook/core/widgets/app_switch.dart';
import 'package:medibook/core/widgets/app_segmented_tabs.dart';
import 'package:medibook/core/widgets/app_stepper.dart';
import 'package:medibook/core/widgets/app_text_field.dart';
import 'package:medibook/core/widgets/app_avatar.dart';
import 'package:medibook/features/dashboard/presentation/components/token_card.dart';

import '../support/harness.dart';

/// Deterministic behaviour tests for the design-system components — no golden
/// files, so they verify wiring/interaction independent of rendering. Pixel
/// fidelity is covered by the golden tests in `test/goldens/`.
void main() {
  group('AppButton', () {
    testWidgets('renders label and fires onPressed when enabled', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(AppButton(label: 'Log In', onPressed: () => taps++)),
      );
      expect(find.text('Log In'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('does not fire onPressed when disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          AppButton(label: 'Disabled', disabled: true, onPressed: () => taps++),
        ),
      );
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, 0);
    });
  });

  testWidgets('AppBadge renders its label', (tester) async {
    await tester.pumpWidget(
      harness(const AppBadge(label: 'Completed', tone: AppBadgeTone.success)),
    );
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('AppTag renders its label', (tester) async {
    await tester.pumpWidget(harness(const AppTag(label: 'Self', active: true)));
    expect(find.text('Self'), findsOneWidget);
  });

  testWidgets('AppCheckbox toggles via onChanged', (tester) async {
    bool? next;
    await tester.pumpWidget(
      harness(
        AppCheckbox(
          value: false,
          label: 'Remember me',
          onChanged: (v) => next = v,
        ),
      ),
    );
    await tester.tap(find.text('Remember me'));
    await tester.pump();
    expect(next, true);
  });

  testWidgets('AppRadio fires onChanged(true) on tap', (tester) async {
    bool? next;
    await tester.pumpWidget(
      harness(
        AppRadio(selected: false, label: 'Male', onChanged: (v) => next = v),
      ),
    );
    await tester.tap(find.text('Male'));
    await tester.pump();
    expect(next, true);
  });

  testWidgets('AppSwitch toggles via onChanged', (tester) async {
    bool? next;
    await tester.pumpWidget(
      harness(AppSwitch(value: false, onChanged: (v) => next = v)),
    );
    await tester.tap(find.byType(AppSwitch));
    await tester.pump();
    expect(next, true);
  });

  testWidgets('AppSegmentedTabs renders tabs and reports selection', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      harness(
        AppSegmentedTabs(
          tabs: const ['Upcoming', 'Past'],
          active: 'Upcoming',
          onChanged: (v) => picked = v,
        ),
      ),
    );
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    await tester.tap(find.text('Past'));
    await tester.pump();
    expect(picked, 'Past');
  });

  testWidgets('AppStepper renders a number per step', (tester) async {
    await tester.pumpWidget(harness(const AppStepper(steps: 4, current: 2)));
    for (final n in ['1', '2', '3', '4']) {
      expect(find.text(n), findsOneWidget);
    }
  });

  // BL-BOOK-030 / BL-REC-006: the notes boxes pass `maxLength: 2000`.
  testWidgets('AppTextField stops accepting text at maxLength', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(
        AppTextField(label: 'Notes', controller: controller, maxLength: 2000),
      ),
    );

    await tester.enterText(find.byType(TextField), 'n' * 2001);
    await tester.pump();

    expect(controller.text, hasLength(2000));
  });

  testWidgets('AppTextField shows label and error', (tester) async {
    await tester.pumpWidget(
      harness(
        const AppTextField(
          label: 'Email',
          errorText: 'Enter a valid email address',
        ),
      ),
    );
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Enter a valid email address'), findsOneWidget);
  });

  // BL-HOME-003 (owner decision): an unpaid booking is shown, but labelled.
  testWidgets('TokenCard.paymentPending says so instead of showing a token', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      harness(
        TokenCard.paymentPending(
          doctor: 'Dr. Harish Menon',
          when: 'Tomorrow · 11:20 AM',
          onTap: () => taps++,
        ),
      ),
    );

    expect(find.text('Payment pending'), findsOneWidget);
    expect(find.text('Pay now'), findsOneWidget);
    expect(find.text('Pay to confirm this booking'), findsOneWidget);
    expect(find.text('Your Token'), findsNothing);

    await tester.tap(find.text('Pay now'));
    expect(taps, 1);
  });

  testWidgets('TokenCard shows the token for a confirmed booking', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const TokenCard(
          token: 'A001',
          doctor: 'Dr. Harish Menon',
          when: 'Tomorrow · 11:20 AM',
        ),
      ),
    );

    expect(find.text('Your Token'), findsOneWidget);
    expect(find.text('A001'), findsOneWidget);
    expect(find.text('Payment pending'), findsNothing);
  });

  testWidgets('AppAvatar falls back to initials when no image', (tester) async {
    await tester.pumpWidget(
      harness(const AppAvatar(name: 'Alexandra Johnson')),
    );
    expect(find.text('AJ'), findsOneWidget);
  });
}
