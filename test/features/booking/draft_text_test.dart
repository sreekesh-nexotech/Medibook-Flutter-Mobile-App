import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/booking/presentation/components/draft_text.dart';

/// BL-BOOK-030: the booking notes box (and both booking search boxes) lost
/// focus after the first character and deleted a space as soon as it was
/// typed, because the box was rebuilt from the trimmed draft on every key.
void main() {
  late String stored;
  late StateSetter setOuter;

  /// A box whose text is stored above it, trimmed — like the booking notes.
  Widget box() => MaterialApp(
    home: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) {
          setOuter = setState;
          return DraftText(
            value: stored,
            builder: (context, controller) => TextField(
              controller: controller,
              onChanged: (text) => setState(() => stored = text.trim()),
            ),
          );
        },
      ),
    ),
  );

  setUp(() => stored = '');

  String shown(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('the box is not replaced when the first character is typed', (
    tester,
  ) async {
    await tester.pumpWidget(box());
    final before = tester.state(find.byType(EditableText));

    await tester.enterText(find.byType(TextField), 'c');
    await tester.pump();

    expect(tester.state(find.byType(EditableText)), same(before));
    expect(shown(tester), 'c');
  });

  testWidgets('a space typed between words is kept', (tester) async {
    await tester.pumpWidget(box());

    await tester.enterText(find.byType(TextField), 'chest ');
    await tester.pump();
    expect(shown(tester), 'chest ', reason: 'the trailing space must stay');
    expect(stored, 'chest');

    await tester.enterText(find.byType(TextField), 'chest pain');
    await tester.pump();
    expect(shown(tester), 'chest pain');
    expect(stored, 'chest pain');
  });

  testWidgets('spaces only are kept in the box but stored as nothing', (
    tester,
  ) async {
    await tester.pumpWidget(box());

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();

    expect(shown(tester), '   ');
    expect(stored, isEmpty);
  });

  testWidgets('the box follows the state above when it changes from outside', (
    tester,
  ) async {
    await tester.pumpWidget(box());
    await tester.enterText(find.byType(TextField), 'chest pain');
    await tester.pump();

    // A new booking clears the draft.
    setOuter(() => stored = '');
    await tester.pump();
    expect(shown(tester), isEmpty);

    // Returning to a draft that already has notes shows them.
    setOuter(() => stored = 'Follow-up');
    await tester.pump();
    expect(shown(tester), 'Follow-up');
  });
}
