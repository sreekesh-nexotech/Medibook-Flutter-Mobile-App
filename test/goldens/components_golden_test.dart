import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medibook/core/widgets/app_button.dart';
import 'package:medibook/core/widgets/app_badge.dart';
import 'package:medibook/core/widgets/app_tag.dart';
import 'package:medibook/core/widgets/app_stepper.dart';
import 'package:medibook/core/widgets/app_segmented_tabs.dart';
import 'package:medibook/core/widgets/app_switch.dart';
import 'package:medibook/core/widgets/app_avatar.dart';
import 'package:medibook/core/widgets/app_rating.dart';
import 'package:medibook/core/widgets/app_status_pill.dart';
import 'package:medibook/core/widgets/status_style.dart';
import 'package:medibook/core/mock_data/models/appointment.dart';

import '../support/harness.dart';

/// Golden (pixel) baselines for the design-system components.
///
/// Generate baselines once in a real Flutter environment:
///   flutter test --update-goldens test/goldens/components_golden_test.dart
/// then `flutter test` compares future renders against them. `matchesGoldenFile`
/// captures just the widget under test (via the `find.byType` finder), so each
/// PNG is the component at its natural size. Fonts are loaded by
/// `test/flutter_test_config.dart`.
void main() {
  Future<void> golden(WidgetTester tester, Widget w, Finder finder, String name) async {
    await tester.pumpWidget(harness(w));
    await tester.pumpAndSettle();
    await expectLater(finder, matchesGoldenFile('images/$name.png'));
  }

  testWidgets('button/primary', (t) => golden(
        t, const AppButton(label: 'Log In', fullWidth: true), find.byType(AppButton), 'button_primary'));

  testWidgets('button/secondary', (t) => golden(
        t, const AppButton(label: 'View Report', variant: AppButtonVariant.secondary), find.byType(AppButton), 'button_secondary'));

  testWidgets('button/soft', (t) => golden(
        t, const AppButton(label: 'Back to Home', variant: AppButtonVariant.soft, fullWidth: true), find.byType(AppButton), 'button_soft'));

  testWidgets('button/danger', (t) => golden(
        t, const AppButton(label: 'Cancel', variant: AppButtonVariant.danger), find.byType(AppButton), 'button_danger'));

  testWidgets('badge/success', (t) => golden(
        t, const AppBadge(label: 'Completed', tone: AppBadgeTone.success), find.byType(AppBadge), 'badge_success'));

  testWidgets('badge/danger', (t) => golden(
        t, const AppBadge(label: 'Pending', tone: AppBadgeTone.danger), find.byType(AppBadge), 'badge_danger'));

  testWidgets('tag/active', (t) => golden(
        t, const AppTag(label: 'Self', active: true), find.byType(AppTag), 'tag_active'));

  testWidgets('stepper/step2of4', (t) => golden(
        t, const AppStepper(steps: 4, current: 2), find.byType(AppStepper), 'stepper_2of4'));

  testWidgets('segmentedTabs', (t) => golden(
        t, const AppSegmentedTabs(tabs: ['Upcoming', 'Past'], active: 'Upcoming'), find.byType(AppSegmentedTabs), 'segmented_tabs'));

  testWidgets('switch/on', (t) => golden(
        t, const AppSwitch(value: true), find.byType(AppSwitch), 'switch_on'));

  testWidgets('avatar/initials-ring', (t) => golden(
        t, const AppAvatar(name: 'Alexandra Johnson', size: 56, ring: true), find.byType(AppAvatar), 'avatar_initials_ring'));

  testWidgets('rating/value', (t) => golden(
        t, const AppRating(value: 4.8, showValue: true, size: 15), find.byType(AppRating), 'rating_value'));

  testWidgets('statusPill/completed', (t) => golden(
        t,
        AppStatusPill(label: 'Completed', colors: AppStatusStyle.appointment(AppointmentStatus.completed)),
        find.byType(AppStatusPill),
        'status_pill_completed'));
}
