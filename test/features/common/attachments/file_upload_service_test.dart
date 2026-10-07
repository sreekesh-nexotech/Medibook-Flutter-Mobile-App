import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/core/error/failure.dart';
import 'package:medibook/core/network/network_exceptions.dart';
import 'package:medibook/features/common/attachments/domain/entities/stored_file.dart';
import 'package:medibook/features/common/attachments/domain/entities/upload_policy.dart';
import 'package:medibook/features/common/attachments/domain/repositories/file_upload_service.dart';
import 'package:medibook/features/common/attachments/infrastructure/data_sources/local/file_picker_ds.dart';
import 'package:medibook/features/common/attachments/infrastructure/data_sources/remote/files_api.dart';
import 'package:medibook/features/common/attachments/infrastructure/data_sources/remote/storage_uploader.dart';
import 'package:medibook/features/common/attachments/infrastructure/repositories/file_upload_service_impl.dart';

/// The three-step upload of §11.1 against scripted seams: the client-side
/// allowlist and size cap fire before any request; the PUT goes to the
/// ticket's URL with exactly its headers; `complete` is called once; the
/// scan is polled with a bounded backoff and ends in a typed outcome.
void main() {
  late _ScriptedFilesApi api;
  late _RecordingStorage storage;
  late List<Duration> sleeps;

  FileUploadServiceImpl service({bool sha = true, int? limitBytes}) =>
      FileUploadServiceImpl(
        api: api,
        storage: storage,
        picker: _NoPicker(),
        computeSha256: sha,
        sleep: (delay) async => sleeps.add(delay),
        limitBytes: limitBytes == null ? null : () => limitBytes,
      );

  PickedFile pdf({int size = 4, String mime = 'application/pdf'}) => PickedFile(
    name: 'test.pdf',
    mime: mime,
    sizeBytes: size,
    readBytes: () async => Uint8List.fromList(List.filled(size, 0x25)),
  );

  setUp(() {
    api = _ScriptedFilesApi();
    storage = _RecordingStorage();
    sleeps = <Duration>[];
  });

  group('UploadPolicy', () {
    test('mirrors the §11.1 allowlist table', () {
      expect(UploadPolicy.allowedMimes[FileUploadPurpose.medicalDocument], {
        'application/pdf',
        'image/jpeg',
        'image/png',
        'image/heic',
      });
      expect(UploadPolicy.allowedMimes[FileUploadPurpose.ticketAttachment], {
        'application/pdf',
        'image/jpeg',
        'image/png',
      });
      expect(UploadPolicy.allowedMimes[FileUploadPurpose.avatar], {
        'image/jpeg',
        'image/png',
        'image/heic',
      });
      expect(UploadPolicy.maxBytes, 10485760);
    });

    test('derives a MIME type from the extension, hint first', () {
      expect(UploadPolicy.mimeFor('scan.JPG'), 'image/jpeg');
      expect(UploadPolicy.mimeFor('x.heif'), 'image/heic');
      expect(UploadPolicy.mimeFor('report.docx'), isNull);
      expect(UploadPolicy.mimeFor('photo', hint: 'image/png'), 'image/png');
    });
  });

  test('a disallowed type is refused before any request', () async {
    await expectLater(
      service().upload(
        pdf(mime: 'text/plain'),
        purpose: FileUploadPurpose.medicalDocument,
      ),
      throwsA(
        isA<ValidationFailure>().having(
          (f) => f.apiCode,
          'apiCode',
          'FILE_TYPE_NOT_ALLOWED',
        ),
      ),
    );
    expect(api.createCalls, 0);
    expect(storage.puts, isEmpty);
  });

  test('a PDF is refused for an avatar', () async {
    await expectLater(
      service().upload(pdf(), purpose: FileUploadPurpose.avatar),
      throwsA(isA<ValidationFailure>()),
    );
    expect(api.createCalls, 0);
  });

  test('a file over 10 MB is refused before any request', () async {
    await expectLater(
      service().upload(
        pdf(size: UploadPolicy.maxBytes + 1),
        purpose: FileUploadPurpose.insurance,
      ),
      throwsA(
        isA<ValidationFailure>()
            .having((f) => f.apiCode, 'apiCode', 'FILE_TOO_LARGE')
            .having((f) => f.meta['max_bytes'], 'max_bytes', 10485760),
      ),
    );
    expect(api.createCalls, 0);
  });

  // BB-38: the cap is the server's setting, so a different one from
  // app-config is the one enforced and named.
  test('the limit app-config gives is the one enforced', () async {
    const fiveMb = 5 * 1024 * 1024;
    await expectLater(
      service(limitBytes: fiveMb).upload(
        pdf(size: fiveMb + 1),
        purpose: FileUploadPurpose.medicalDocument,
      ),
      throwsA(
        isA<ValidationFailure>()
            .having((f) => f.meta['max_bytes'], 'max_bytes', fiveMb)
            .having(
              (f) => f.userMessage,
              'userMessage',
              'That file is too large. The limit is 5 MB.',
            ),
      ),
    );
    expect(api.createCalls, 0);

    // A larger cap lets through a file the old fixed 10 MB refused.
    final raised = UploadPolicy.validate(
      pdf(size: UploadPolicy.maxBytes + 1),
      FileUploadPurpose.medicalDocument,
      limitBytes: 20 * 1024 * 1024,
    );
    expect(raised, isNull);
  });

  test('runs the three steps in order with the exact ticket headers', () async {
    api.statuses = ['scanning', 'clean'];
    final progress = <UploadPhase>[];

    final outcome = await service().upload(
      pdf(),
      purpose: FileUploadPurpose.medicalDocument,
      onProgress: (p) => progress.add(p.phase),
    );

    expect(outcome, isA<UploadClean>());
    expect(outcome.file.id, 'file-1');
    expect(api.createCalls, 1);
    expect(api.lastCreateBody['purpose'], 'medical_document');
    expect(api.lastCreateBody['mime'], 'application/pdf');
    expect(api.lastCreateBody['size_bytes'], 4);
    expect(api.lastCreateBody['original_name'], 'test.pdf');
    expect(
      api.lastCreateBody['sha256'],
      sha256.convert(List.filled(4, 0x25)).toString(),
    );

    expect(storage.puts, hasLength(1));
    final put = storage.puts.single;
    expect(put.url, 'https://storage.example/bucket/key?X-Op=put');
    expect(put.method, 'PUT');
    expect(put.headers, {'Content-Type': 'application/pdf', 'x-amz-acl': 'x'});
    expect(
      put.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('authorization')),
    );
    expect(put.bytes, hasLength(4));

    expect(api.completeCalls, ['file-1']);
    expect(api.getCalls, ['file-1']);
    expect(progress.first, UploadPhase.preparing);
    expect(progress, contains(UploadPhase.uploading));
    expect(progress.last, UploadPhase.scanning);
    expect(sleeps, [const Duration(seconds: 1)]);
  });

  test('omits sha256 when not computed', () async {
    api.statuses = ['clean'];
    await service(
      sha: false,
    ).upload(pdf(), purpose: FileUploadPurpose.medicalDocument);
    expect(api.lastCreateBody.containsKey('sha256'), isFalse);
  });

  test(
    'polls with 1s, 2s, 3s… and returns clean when the scan finishes',
    () async {
      api.statuses = ['scanning', 'scanning', 'scanning', 'clean'];
      final outcome = await service().upload(
        pdf(),
        purpose: FileUploadPurpose.insurance,
      );
      expect(outcome, isA<UploadClean>());
      expect(sleeps, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
        const Duration(seconds: 3),
      ]);
    },
  );

  test('infected is a typed rejection, not an error', () async {
    api.statuses = ['scanning', 'infected'];
    final outcome = await service().upload(
      pdf(),
      purpose: FileUploadPurpose.medicalDocument,
    );
    expect(outcome, isA<UploadRejected>());
    expect(outcome.file.status, FileStatus.infected);
  });

  test('scan_failed is a typed rejection', () async {
    api.statuses = ['scanning', 'scan_failed'];
    final outcome = await service().upload(
      pdf(),
      purpose: FileUploadPurpose.medicalDocument,
    );
    expect(outcome, isA<UploadRejected>());
  });

  test('gives up after ~30 s of polling with a typed timeout', () async {
    api.statuses = List.filled(40, 'scanning');
    final outcome = await service().upload(
      pdf(),
      purpose: FileUploadPurpose.medicalDocument,
    );
    expect(outcome, isA<UploadScanTimedOut>());
    final total = sleeps.fold(Duration.zero, (a, b) => a + b);
    expect(total.inSeconds, lessThanOrEqualTo(30));
    expect(total.inSeconds, greaterThanOrEqualTo(25));
    expect(sleeps.every((d) => d.inSeconds <= 5), isTrue);
  });

  test('awaitScan re-polls a timed-out file', () async {
    api.statuses = ['scanning', 'clean'];
    final outcome = await service().awaitScan('file-1');
    expect(outcome, isA<UploadClean>());
  });

  test('a storage failure surfaces as a Failure after step 1', () async {
    storage.failWith = const NoConnectionException(message: 'down');
    await expectLater(
      service().upload(pdf(), purpose: FileUploadPurpose.medicalDocument),
      throwsA(
        isA<NetworkFailure>().having(
          // The API just answered step 1: this is the storage host, and the
          // message must not claim the patient is offline.
          (f) => f.userMessage,
          'userMessage',
          allOf(contains('storage'), isNot(contains('offline'))),
        ),
      ),
    );
    expect(api.createCalls, 1);
    expect(api.completeCalls, isEmpty);
    // BL-REC-031: the slot registered in step 1 is not left behind.
    await Future<void>.delayed(Duration.zero);
    expect(api.deleteCalls, ['file-1']);
  });

  test('a successful upload deletes nothing', () async {
    await service().upload(pdf(), purpose: FileUploadPurpose.medicalDocument);
    await Future<void>.delayed(Duration.zero);
    expect(api.deleteCalls, isEmpty);
  });

  test('a clean-up that fails does not hide the upload failure', () async {
    storage.failWith = const NoConnectionException(message: 'down');
    api.deleteError = const NoConnectionException(message: 'down');
    await expectLater(
      service().upload(pdf(), purpose: FileUploadPurpose.medicalDocument),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('a 415 from the server maps to a ValidationFailure with meta', () async {
    api.createError = const HttpStatusException(
      statusCode: 415,
      code: 'FILE_TYPE_NOT_ALLOWED',
      meta: {
        'allowed': ['application/pdf'],
      },
    );
    await expectLater(
      service().upload(pdf(), purpose: FileUploadPurpose.medicalDocument),
      throwsA(
        isA<Failure>().having(
          (f) => f.apiCode,
          'apiCode',
          'FILE_TYPE_NOT_ALLOWED',
        ),
      ),
    );
  });

  test('FILE_IN_USE on delete is a ConflictFailure', () async {
    api.deleteError = const HttpStatusException(
      statusCode: 409,
      code: 'FILE_IN_USE',
      meta: {'referenced_by': 'document'},
    );
    await expectLater(
      service().delete('file-1'),
      throwsA(
        isA<ConflictFailure>().having(
          (f) => f.apiCode,
          'apiCode',
          'FILE_IN_USE',
        ),
      ),
    );
  });
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _ScriptedFilesApi implements FilesApi {
  int createCalls = 0;
  Map<String, Object?> lastCreateBody = const {};
  final List<String> completeCalls = [];
  final List<String> getCalls = [];
  final List<String> deleteCalls = [];
  List<String> statuses = ['clean'];
  Object? createError;
  Object? deleteError;
  int _poll = 0;

  Map<String, Object?> _file(String status) => {
    'id': 'file-1',
    'purpose': 'medical_document',
    'owner_kind': 'patient',
    'original_name': 'test.pdf',
    'mime': 'application/pdf',
    'size_bytes': 4,
    'sha256': null,
    'status': status,
    'uploaded_at': null,
    'scanned_at': null,
    'created_at': '2026-09-30T08:09:03.376569Z',
    'version': 1,
  };

  @override
  Future<Map<String, Object?>> createUpload({
    required String purpose,
    required String mime,
    required int sizeBytes,
    String? sha256,
    String? originalName,
  }) async {
    createCalls++;
    if (createError != null) throw createError!;
    lastCreateBody = {
      'purpose': purpose,
      'mime': mime,
      'size_bytes': sizeBytes,
      'sha256': ?sha256,
      'original_name': ?originalName,
    };
    return {
      'file_id': 'file-1',
      'upload_url': 'https://storage.example/bucket/key?X-Op=put',
      'method': 'PUT',
      'headers': {'Content-Type': 'application/pdf', 'x-amz-acl': 'x'},
      'expires_at': '2026-09-30T08:14:03.415298+00:00',
      'file': _file('pending'),
    };
  }

  @override
  Future<Map<String, Object?>> complete(String fileId) async {
    completeCalls.add(fileId);
    return _file(statuses.isEmpty ? 'scanning' : statuses.first);
  }

  @override
  Future<Map<String, Object?>> file(String fileId) async {
    getCalls.add(fileId);
    _poll++;
    final index = _poll.clamp(0, statuses.length - 1);
    return _file(statuses[index]);
  }

  @override
  Future<Map<String, Object?>> url(String fileId) async => {
    'url': 'https://signed.example/$fileId',
    'expires_at': DateTime.now()
        .toUtc()
        .add(const Duration(minutes: 10))
        .toIso8601String(),
  };

  @override
  Future<void> delete(String fileId, {int? version}) async {
    deleteCalls.add(fileId);
    if (deleteError != null) throw deleteError!;
  }
}

class _Put {
  _Put(this.url, this.method, this.headers, this.bytes);

  final String url;
  final String method;
  final Map<String, String> headers;
  final Uint8List bytes;
}

class _RecordingStorage implements StorageUploader {
  final List<_Put> puts = [];
  Object? failWith;

  @override
  Future<void> put({
    required String uploadUrl,
    required String method,
    required Map<String, String> headers,
    required Uint8List bytes,
    void Function(int sent, int total)? onProgress,
  }) async {
    if (failWith != null) throw failWith!;
    puts.add(_Put(uploadUrl, method, headers, bytes));
    onProgress?.call(bytes.length, bytes.length);
  }
}

class _NoPicker implements FilePickerDataSource {
  @override
  Future<PickedFile?> pick(
    FileUploadPurpose purpose,
    PickSource source,
  ) async => null;
}
