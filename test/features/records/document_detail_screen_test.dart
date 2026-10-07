import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/network/connectivity/connectivity_monitor.dart';
import 'package:medibook/features/records/application/providers/records_provider.dart';
import 'package:medibook/features/records/presentation/screen/document_detail_screen.dart';

import '../../support/harness.dart';
import 'documents_controllers_test.dart';

/// BL-REC-034 (owner decision): View and Download did the same thing, so the
/// record offers a single "Open file".
void main() {
  testWidgets('a record offers one Open file action', (tester) async {
    await tester.pumpWidget(
      screenHarness(
        const DocumentDetailScreen(documentId: 'd1'),
        overrides: [
          documentsRepositoryProvider.overrideWithValue(
            FakeDocumentsRepository(),
          ),
          isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Open file'), findsOneWidget);
    expect(find.text('View'), findsNothing);
    expect(find.text('Download'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label ?? '').contains('opens in your browser'),
      ),
      findsOneWidget,
    );
  });
}
