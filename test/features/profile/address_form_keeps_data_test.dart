import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/profile/domain/entities/address.dart';
import 'package:medibook/features/profile/presentation/screen/addresses_screen.dart';

import '../../support/harness.dart';

/// BL-PROF-024: an address saved by another client with a custom label and a
/// contact number lost both when edited here (label "Other", phone null).
void main() {
  testWidgets('editing keeps a custom label and the contact number', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    AddressDraft? sent;
    const beachHouse = Address(
      id: 'a1',
      label: 'Beach house',
      addressLine1: '1 Shore Road',
      city: 'Kochi',
      state: 'Kerala',
      pincode: '682001',
      phoneE164: '+919812300000',
      version: 2,
    );

    await tester.pumpWidget(
      screenHarness(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAddressFormSheet(
                context,
                existing: beachHouse,
                onSubmit: (draft) async {
                  sent = draft;
                  return null;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Save Changes'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    expect(sent?.label, 'Beach house');
    expect(sent?.phoneE164, '+919812300000');
  });

  // The address's contact number (`phone_e164`) is now a field of its own:
  // it opens with the number on file, can be changed, and emptying it
  // removes it.
  testWidgets('the contact number can be changed and removed', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sent = <AddressDraft>[];
    const home = Address(
      id: 'a2',
      label: 'Home',
      addressLine1: '13 Panampilly Nagar',
      city: 'Kochi',
      state: 'Kerala',
      pincode: '682020',
      phoneE164: '+919812300000',
      version: 1,
    );

    await tester.pumpWidget(
      screenHarness(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAddressFormSheet(
                context,
                existing: home,
                onSubmit: (draft) async {
                  sent.add(draft);
                  return null;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    Finder phoneField(String digits) => find.byWidgetPredicate(
      (widget) => widget is EditableText && widget.controller.text == digits,
    );

    Future<void> saveWithPhone(String from, String to) async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        phoneField(from),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.enterText(phoneField(from), to);
      await tester.scrollUntilVisible(
        find.text('Save Changes'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
    }

    await saveWithPhone('9812300000', '9895012345');
    expect(sent.last.phoneE164, '+919895012345');

    await saveWithPhone('9812300000', '');
    expect(sent.last.phoneE164, isNull);
  });
}
