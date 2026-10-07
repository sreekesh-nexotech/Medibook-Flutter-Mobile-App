import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/features/common/attachments/application/providers/attachments_provider.dart';
import 'package:medibook/features/common/attachments/domain/entities/stored_file.dart';
import 'package:medibook/features/common/attachments/presentation/components/attachment_upload_tile.dart';
import 'package:medibook/features/support/application/providers/app_config_provider.dart';
import 'package:medibook/features/support/domain/entities/app_config.dart';

import '../../../support/harness.dart';
import 'attachment_upload_controller_test.dart' show FakeFileUploadService;

/// A file that was refused for what it is (too large, a type not accepted,
/// empty) is only offered "Choose another" — sending the same file again
/// cannot work. A failed send keeps "Try again".
void main() {
  late FakeFileUploadService service;

  setUp(() => service = FakeFileUploadService());

  Future<void> failUpload(WidgetTester tester, Failure error) async {
    service.nextError = error;
    await tester.pumpWidget(
      screenHarness(
        const Scaffold(
          body: AttachmentUploadTile(
            purpose: FileUploadPurpose.medicalDocument,
          ),
        ),
        overrides: [
          fileUploadServiceProvider.overrideWithValue(service),
          uploadMaxBytesProvider.overrideWithValue(
            AppConfig.defaultUploadMaxBytes,
          ),
        ],
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AttachmentUploadTile)),
    );
    await container
        .read(
          attachmentUploadProvider(FileUploadPurpose.medicalDocument).notifier,
        )
        .uploadPicked(
          PickedFile(
            name: 'report.pdf',
            mime: 'application/pdf',
            sizeBytes: 4,
            readBytes: () async => Uint8List(4),
          ),
        );
    await tester.pump();
  }

  testWidgets('a file that is too large offers only another file', (
    tester,
  ) async {
    await failUpload(
      tester,
      const ValidationFailure(
        userMessage: 'That file is too large. The limit is 10 MB.',
        apiCode: 'FILE_TOO_LARGE',
        fieldErrors: {'file': 'File too large'},
      ),
    );
    expect(
      find.text('That file is too large. The limit is 10 MB.'),
      findsOneWidget,
    );
    expect(find.text('Choose another'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a failed send can be tried again', (tester) async {
    await failUpload(tester, const NetworkFailure());
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Choose another'), findsOneWidget);
  });
}
