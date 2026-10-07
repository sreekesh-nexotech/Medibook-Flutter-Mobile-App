import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/common/persons/application/providers/persons_read_provider.dart';
import 'package:medibook/features/common/persons/domain/entities/person_summary.dart';
import 'package:medibook/features/common/persons/domain/repositories/persons_read_repository.dart';
import 'package:medibook/features/records/application/providers/linkable_appointments_provider.dart';
import 'package:medibook/features/records/application/providers/records_provider.dart';
import 'package:medibook/features/records/presentation/screen/document_edit_sheet.dart';
import 'package:medibook/features/support/application/providers/app_config_provider.dart';
import 'package:medibook/features/support/domain/entities/app_config.dart';

import '../../support/harness.dart';
import 'documents_controllers_test.dart';

/// The Edit document sheet closed with an edit not saved used to drop it
/// without a word (Records re-test, 6 Oct 2026); it now asks, as the upload
/// screen does, and cannot be swiped away past that question.
void main() {
  late FakeDocumentsRepository repository;

  setUp(() => repository = FakeDocumentsRepository());

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      screenHarness(
        Scaffold(
          // As on the detail screen: the document is loaded before the
          // sheet opens, and the form starts from it.
          body: Consumer(
            builder: (context, ref, _) {
              final loaded = ref.watch(documentProvider('a')).hasValue;
              return TextButton(
                onPressed: loaded
                    ? () => showDocumentEditSheet(context, 'a')
                    : null,
                child: const Text('Edit details'),
              );
            },
          ),
        ),
        overrides: [
          documentsRepositoryProvider.overrideWithValue(repository),
          personsReadRepositoryProvider.overrideWithValue(_FakePersons()),
          linkableAppointmentsProvider.overrideWithValue(const []),
          uploadMaxBytesProvider.overrideWithValue(
            AppConfig.defaultUploadMaxBytes,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(find.text('Edit document'), findsOneWidget);
  }

  testWidgets('closing with an unsaved edit asks before dropping it', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Doc a'),
      'Doc a, renamed',
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);
    expect(
      find.text('Your changes to this document will not be saved.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();
    expect(find.text('Doc a, renamed'), findsOneWidget, reason: 'kept');

    // Swiping down does not get past the question either.
    await tester.drag(find.text('Edit document'), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('Edit document'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Edit document'), findsNothing);
  });

  testWidgets('an untouched form closes at once', (tester) async {
    await openSheet(tester);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsNothing);
    expect(find.text('Edit document'), findsNothing);
  });
}

class _FakePersons implements PersonsReadRepository {
  @override
  Future<List<PersonSummary>> persons({bool forceRefresh = false}) async =>
      const [
        PersonSummary(
          id: 'self',
          firstName: 'Test',
          relation: 'self',
          isSelf: true,
        ),
      ];
}
