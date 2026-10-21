import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medibook/app/bootstrap/hive_init.dart';
import 'package:medibook/core/widgets/app_phone_field.dart';
import 'package:medibook/features/auth/application/providers/login_form_controller.dart';
import 'package:medibook/features/auth/presentation/screen/login_screen.dart';

import '../../support/harness.dart';
import '../../support/offline_overrides.dart';

/// The email tab's account field takes an email or a mobile number. Once the
/// entry is a number (more than three digits) the country chip the mobile tab
/// shows appears beside it, and the number is sent with the code in front.
void main() {
  group('LoginFormController.isNationalNumber', () {
    test('more than three digits is a number', () {
      expect(LoginFormController.isNationalNumber('9808'), isTrue);
      expect(LoginFormController.isNationalNumber(' 9808683257 '), isTrue);
    });

    test('three digits, an email or a +code number is not', () {
      expect(LoginFormController.isNationalNumber('980'), isFalse);
      expect(LoginFormController.isNationalNumber('asha@x.example'), isFalse);
      expect(LoginFormController.isNationalNumber('+919808683257'), isFalse);
      expect(LoginFormController.isNationalNumber('98a08'), isFalse);
    });
  });

  testWidgets(
    'the country chip appears beside a typed number and focus stays',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      HiveInit.store = InMemoryLocalStore();
      await tester.pumpWidget(
        screenHarness(const LoginScreen(), overrides: offlineOverrides()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Email'));
      await tester.pumpAndSettle();
      expect(find.byType(AppCountryCodeChip), findsNothing);

      final field = find.byType(EditableText).first;
      await tester.tap(field);
      await tester.enterText(field, '980');
      await tester.pump();
      expect(find.byType(AppCountryCodeChip), findsNothing);

      await tester.enterText(field, '9808');
      await tester.pump();
      expect(find.byType(AppCountryCodeChip), findsOneWidget);
      expect(find.text('+91'), findsOneWidget);
      // The box kept its focus (the keyboard stays up) when the chip appeared.
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        isTrue,
      );

      await tester.enterText(field, 'asha@example.com');
      await tester.pump();
      expect(find.byType(AppCountryCodeChip), findsNothing);
    },
  );
}
