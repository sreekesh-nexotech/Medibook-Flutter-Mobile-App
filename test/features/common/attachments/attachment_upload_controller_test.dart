import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/features/common/attachments/application/providers/attachments_provider.dart';
import 'package:medibook/features/common/attachments/application/states/attachment_upload_state.dart';
import 'package:medibook/features/common/attachments/domain/entities/stored_file.dart';
import 'package:medibook/features/common/attachments/domain/repositories/file_upload_service.dart';

/// The shared attachment slot: pick → upload → typed end state, with the
/// failure kept on the state and the picked file kept for a retry.
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

  final provider = attachmentUploadProvider(FileUploadPurpose.medicalDocument);

  test('starts idle', () {
    expect(container.read(provider).status, AttachmentStatus.idle);
    expect(container.read(provider).readyFileId, isNull);
  });

  test('a cancelled pick returns to idle', () async {
    service.nextPick = null;
    await container.read(provider.notifier).pickAndUpload();
    expect(container.read(provider).status, AttachmentStatus.idle);
    expect(service.uploads, 0);
  });

  test('a picked file uploads and becomes ready with its file id', () async {
    service.nextPick = _picked();
    service.nextOutcome = UploadClean(_stored(FileStatus.clean));
    final state = await container.read(provider.notifier).pickAndUpload();
    expect(state.status, AttachmentStatus.ready);
    expect(state.readyFileId, 'file-1');
    expect(service.lastPurpose, FileUploadPurpose.medicalDocument);
  });

  test('a rejected scan is a rejected slot, not a failure', () async {
    service.nextPick = _picked();
    service.nextOutcome = UploadRejected(_stored(FileStatus.infected));
    final state = await container.read(provider.notifier).pickAndUpload();
    expect(state.status, AttachmentStatus.rejected);
    expect(state.failure, isNull);
    expect(state.readyFileId, isNull);
  });

  test('a timed-out scan can be waited for again', () async {
    service.nextPick = _picked();
    service.nextOutcome = UploadScanTimedOut(_stored(FileStatus.scanning));
    await container.read(provider.notifier).pickAndUpload();
    expect(container.read(provider).status, AttachmentStatus.scanTimedOut);

    service.nextOutcome = UploadClean(_stored(FileStatus.clean));
    final state = await container.read(provider.notifier).waitForScan();
    expect(state.status, AttachmentStatus.ready);
    expect(service.awaitScanCalls, ['file-1']);
  });

  test('a network failure keeps the pick so retry re-uploads it', () async {
    service.nextPick = _picked();
    service.nextError = const NetworkFailure();
    var state = await container.read(provider.notifier).pickAndUpload();
    expect(state.status, AttachmentStatus.failed);
    expect(state.failure, isA<NetworkFailure>());
    expect(state.picked, isNotNull);

    service.nextError = null;
    service.nextOutcome = UploadClean(_stored(FileStatus.clean));
    state = await container.read(provider.notifier).retry();
    expect(state.status, AttachmentStatus.ready);
    expect(service.uploads, 2);
  });

  test('a client-side validation failure is shown as failed', () async {
    service.nextPick = _picked(mime: 'text/plain');
    service.nextError = const ValidationFailure(
      userMessage: 'That file type is not accepted.',
      apiCode: 'FILE_TYPE_NOT_ALLOWED',
    );
    final state = await container.read(provider.notifier).pickAndUpload();
    expect(state.status, AttachmentStatus.failed);
    expect(state.failure?.apiCode, 'FILE_TYPE_NOT_ALLOWED');
  });

  test('clear deletes the orphaned server file and resets', () async {
    service.nextPick = _picked();
    service.nextOutcome = UploadClean(_stored(FileStatus.clean));
    await container.read(provider.notifier).pickAndUpload();
    await container.read(provider.notifier).clear();
    expect(container.read(provider).status, AttachmentStatus.idle);
    expect(service.deleted, ['file-1']);
  });

  // BL-REC-031: a file the slot gives up must not stay on the server.
  group('files that are no longer wanted are deleted', () {
    StoredFile stored(String id, FileStatus status) => StoredFile(
      id: id,
      purpose: FileUploadPurpose.medicalDocument,
      originalName: 'a.pdf',
      mime: 'application/pdf',
      sizeBytes: 3,
      status: status,
      version: 1,
    );

    test('replacing a ready file deletes the one it replaces', () async {
      service.nextPick = _picked();
      service.nextOutcome = UploadClean(stored('first', FileStatus.clean));
      await container.read(provider.notifier).pickAndUpload();

      service.nextOutcome = UploadClean(stored('second', FileStatus.clean));
      final state = await container.read(provider.notifier).pickAndUpload();

      expect(state.readyFileId, 'second');
      expect(service.deleted, ['first']);
    });

    test(
      'choosing another after a rejected scan deletes the rejected file',
      () async {
        service.nextPick = _picked();
        service.nextOutcome = UploadRejected(
          stored('infected', FileStatus.infected),
        );
        await container.read(provider.notifier).pickAndUpload();

        service.nextOutcome = UploadClean(stored('good', FileStatus.clean));
        await container.read(provider.notifier).pickAndUpload();

        expect(service.deleted, ['infected']);
      },
    );

    // BL-REC-030: the failure's own words survive a cancelled picker.
    test('cancelling the picker after a failure keeps its message', () async {
      service.nextPick = _picked();
      service.nextError = const NetworkFailure(
        userMessage: 'The file could not be sent to our storage.',
      );
      await container.read(provider.notifier).pickAndUpload();
      expect(container.read(provider).status, AttachmentStatus.failed);

      service.nextPick = null; // the picker is cancelled
      await container.read(provider.notifier).pickAndUpload();
      final state = container.read(provider);
      expect(state.status, AttachmentStatus.failed);
      expect(
        state.failure?.userMessage,
        'The file could not be sent to our storage.',
      );
    });

    test('cancelling the picker keeps the current file', () async {
      service.nextPick = _picked();
      service.nextOutcome = UploadClean(stored('first', FileStatus.clean));
      await container.read(provider.notifier).pickAndUpload();

      service.nextPick = null;
      final state = await container.read(provider.notifier).pickAndUpload();

      expect(state.readyFileId, 'first');
      expect(service.deleted, isEmpty);
    });

    test('leaving the form with an unused file deletes it', () async {
      final sub = container.listen(provider, (_, _) {});
      service.nextPick = _picked();
      service.nextOutcome = UploadClean(stored('unused', FileStatus.clean));
      await container.read(provider.notifier).pickAndUpload();

      sub.close();
      await container.pump();
      await Future<void>.delayed(Duration.zero);

      expect(service.deleted, ['unused']);
    });

    test('leaving after the file was handed over deletes nothing', () async {
      final sub = container.listen(provider, (_, _) {});
      service.nextPick = _picked();
      service.nextOutcome = UploadClean(stored('saved', FileStatus.clean));
      await container.read(provider.notifier).pickAndUpload();
      container.read(provider.notifier).detachOwnership();

      sub.close();
      await container.pump();
      await Future<void>.delayed(Duration.zero);

      expect(service.deleted, isEmpty);
    });
  });

  test('detachOwnership resets without deleting the file', () async {
    service.nextPick = _picked();
    service.nextOutcome = UploadClean(_stored(FileStatus.clean));
    await container.read(provider.notifier).pickAndUpload();
    container.read(provider.notifier).detachOwnership();
    expect(container.read(provider).status, AttachmentStatus.idle);
    expect(service.deleted, isEmpty);
  });
}

PickedFile _picked({String mime = 'application/pdf'}) => PickedFile(
  name: 'a.pdf',
  mime: mime,
  sizeBytes: 3,
  readBytes: () async => Uint8List.fromList([1, 2, 3]),
);

StoredFile _stored(FileStatus status) => StoredFile(
  id: 'file-1',
  purpose: FileUploadPurpose.medicalDocument,
  originalName: 'a.pdf',
  mime: 'application/pdf',
  sizeBytes: 3,
  status: status,
  version: 1,
);

/// A scripted [FileUploadService] for controller and screen tests.
class FakeFileUploadService implements FileUploadService {
  PickedFile? nextPick;
  UploadOutcome? nextOutcome;
  Failure? nextError;
  FileUploadPurpose? lastPurpose;
  int uploads = 0;
  final List<String> awaitScanCalls = [];
  final List<String> deleted = [];

  @override
  Future<PickedFile?> pick(
    FileUploadPurpose purpose, {
    PickSource source = PickSource.files,
  }) async => nextPick;

  @override
  Future<UploadOutcome> upload(
    PickedFile file, {
    required FileUploadPurpose purpose,
    void Function(UploadProgress progress)? onProgress,
  }) async {
    uploads++;
    lastPurpose = purpose;
    onProgress?.call(
      const UploadProgress(phase: UploadPhase.uploading, fraction: 0.5),
    );
    if (nextError != null) throw nextError!;
    return nextOutcome!;
  }

  @override
  Future<UploadOutcome> awaitScan(String fileId) async {
    awaitScanCalls.add(fileId);
    if (nextError != null) throw nextError!;
    return nextOutcome!;
  }

  @override
  Future<StoredFile> file(String fileId) async => _stored(FileStatus.clean);

  @override
  Future<void> delete(String fileId, {int? version}) async =>
      deleted.add(fileId);
}
