import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/common/attachments/application/providers/attachments_provider.dart';
import 'package:medibook/features/common/attachments/domain/entities/stored_file.dart';
import 'package:medibook/features/support/application/providers/app_config_provider.dart';
import 'package:medibook/features/support/domain/entities/app_config.dart';
import 'package:medibook/features/support/presentation/components/ticket_attachments_field.dart';
import 'package:medibook/features/support/application/providers/ticket_attachments_controller.dart';

import '../../support/harness.dart';
import '../common/attachments/attachment_upload_controller_test.dart'
    show FakeFileUploadService;

/// BL-SUP-006 (owner decision): support requests and replies take up to five
/// files.
void main() {
  late FakeFileUploadService service;
  late ProviderContainer container;

  setUp(() {
    service = FakeFileUploadService();
    container = ProviderContainer(
      overrides: [fileUploadServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
  });

  AttachmentUploadController slot(int i) => container.read(
    attachmentSlotProvider(ticketAttachmentSlot(newTicketForm, i)).notifier,
  );

  test('only files the scanner passed are sent; busy and failed are '
      'reported', () async {
    container.listen(ticketAttachmentsProvider(newTicketForm), (_, _) {});
    container
            .read(ticketAttachmentCountProvider(newTicketForm).notifier)
            .state =
        3;

    service.nextOutcome = UploadClean(_stored('f-1', FileStatus.clean));
    await slot(0).uploadPicked(_picked());
    service.nextOutcome = UploadRejected(_stored('f-2', FileStatus.infected));
    await slot(1).uploadPicked(_picked());
    // Slot 2 left empty: it is ignored.

    final files = container.read(ticketAttachmentsProvider(newTicketForm));
    expect(files.readyFileIds, ['f-1']);
    expect(files.hasProblem, isTrue, reason: 'the rejected file');
    expect(files.isBusy, isFalse);
  });

  testWidgets('Attach adds a file slot, up to five', (widgetTester) async {
    await widgetTester.pumpWidget(
      screenHarness(
        const Scaffold(
          body: SingleChildScrollView(
            child: TicketAttachmentsField(form: newTicketForm),
          ),
        ),
        overrides: [
          fileUploadServiceProvider.overrideWithValue(service),
          // The tile words the server's upload limit from app-config.
          uploadMaxBytesProvider.overrideWithValue(
            AppConfig.defaultUploadMaxBytes,
          ),
        ],
      ),
    );
    await widgetTester.pump();
    expect(find.text('Attach a file'), findsOneWidget);

    await widgetTester.tap(find.text('Attach a file'));
    await widgetTester.pump();
    expect(find.text('Attachment'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await widgetTester.ensureVisible(find.text('Attach another file'));
      await widgetTester.tap(find.text('Attach another file'));
      await widgetTester.pump();
    }
    expect(find.text('Attachment 5'), findsOneWidget);
    expect(find.text('Attach another file'), findsNothing);
  });
}

PickedFile _picked() => PickedFile(
  name: 'receipt.pdf',
  mime: 'application/pdf',
  sizeBytes: 3,
  readBytes: () async => Uint8List.fromList([1, 2, 3]),
);

StoredFile _stored(String id, FileStatus status) => StoredFile(
  id: id,
  purpose: FileUploadPurpose.ticketAttachment,
  originalName: 'receipt.pdf',
  mime: 'application/pdf',
  sizeBytes: 3,
  status: status,
  version: 1,
);
