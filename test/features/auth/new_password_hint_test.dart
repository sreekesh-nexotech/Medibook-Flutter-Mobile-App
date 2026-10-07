import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/auth/presentation/components/field_focus_group.dart';
import 'package:medibook/features/auth/presentation/components/new_password_fields.dart';
import 'package:medibook/features/auth/application/providers/auth_form_controller.dart';

import '../../support/harness.dart';

/// BL-AUTH-043: the server and the form require 10 characters (API §4
/// password rules); the hint used to say 6, so following it always failed.
void main() {
  testWidgets('the new-password hint states the real minimum', (tester) async {
    final focus = FieldFocusGroup(onBlur: (_) {});
    addTearDown(focus.dispose);
    final password = TextEditingController();
    final confirm = TextEditingController();
    addTearDown(password.dispose);
    addTearDown(confirm.dispose);

    await tester.pumpWidget(
      screenHarness(
        Scaffold(
          body: NewPasswordFields(
            passwordField: 'new',
            confirmField: 'confirm',
            passwordController: password,
            confirmController: confirm,
            state: const AuthFormState(),
            focus: focus,
            onChanged: (_, _) {},
            onSubmit: () {},
          ),
        ),
      ),
    );

    expect(find.textContaining('At least 10 characters'), findsWidgets);
    expect(find.textContaining('6 characters'), findsNothing);
  });
}
