import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/network/network_exceptions.dart';
import '../../../../../core/utils/logger.dart';
import '../../domain/entities/stored_file.dart';
import '../../domain/entities/upload_policy.dart';
import '../../domain/repositories/file_upload_service.dart';
import '../data_sources/local/file_picker_ds.dart';
import '../data_sources/remote/files_api.dart';
import '../data_sources/remote/storage_uploader.dart';
import 'file_mappers.dart';

/// How long [FileUploadServiceImpl] waits for a scan verdict, and how.
///
/// Bounded backoff: 1 s, 2 s, 3 s, 4 s, 5 s, then 5 s steps until [total]
/// is spent — "usually a few seconds" per §11.1, with a ceiling so a stuck
/// scanner turns into a typed [UploadScanTimedOut] rather than a spinner.
class ScanPollPolicy {
  const ScanPollPolicy({
    this.total = const Duration(seconds: 30),
    this.maxStep = const Duration(seconds: 5),
  });

  final Duration total;
  final Duration maxStep;

  /// Delay before poll number [attempt] (1-based).
  Duration delayFor(int attempt) {
    final seconds = attempt.clamp(1, maxStep.inSeconds);
    return Duration(seconds: seconds);
  }
}

/// [FileUploadService] over [FilesApi] + [StorageUploader] +
/// [FilePickerDataSource].
///
/// Keeps the two promises the contract makes: every throw is a `Failure`,
/// and the scan verdict is a typed outcome, never an exception.
class FileUploadServiceImpl implements FileUploadService {
  FileUploadServiceImpl({
    required FilesApi api,
    required StorageUploader storage,
    required FilePickerDataSource picker,
    ScanPollPolicy pollPolicy = const ScanPollPolicy(),
    bool computeSha256 = true,
    Future<void> Function(Duration delay)? sleep,
    int Function()? limitBytes,
  }) : _api = api,
       _storage = storage,
       _picker = picker,
       _poll = pollPolicy,
       _computeSha256 = computeSha256,
       _sleep = sleep ?? ((delay) => Future<void>.delayed(delay)),
       _limitBytes = limitBytes ?? (() => UploadPolicy.maxBytes);

  final FilesApi _api;
  final StorageUploader _storage;
  final FilePickerDataSource _picker;

  /// The server's current upload cap, read at upload time (app-config's
  /// `upload_max_bytes`, which can change while the app runs).
  final int Function() _limitBytes;
  final ScanPollPolicy _poll;
  final bool _computeSha256;
  final Future<void> Function(Duration delay) _sleep;

  @override
  Future<PickedFile?> pick(
    FileUploadPurpose purpose, {
    PickSource source = PickSource.files,
  }) async {
    try {
      return await _picker.pick(purpose, source);
    } catch (error, stackTrace) {
      // A platform picker failure (permission denied, no camera) must not
      // surface as a crash; it is an UnknownFailure with a next step.
      AppLogger.warning('File pick failed', name: 'files', error: error);
      throw UnknownFailure(
        userMessage:
            'We could not open the file picker. Check the app has '
            'permission to access your files and try again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<UploadOutcome> upload(
    PickedFile file, {
    required FileUploadPurpose purpose,
    void Function(UploadProgress progress)? onProgress,
  }) async {
    // Client-side allowlist and size cap, before any request (§11.1).
    final rejected = UploadPolicy.validate(
      file,
      purpose,
      limitBytes: _limitBytes(),
    );
    if (rejected != null) throw rejected;

    onProgress?.call(const UploadProgress(phase: UploadPhase.preparing));

    final Uint8List bytes;
    try {
      bytes = await file.readBytes();
    } catch (error, stackTrace) {
      throw UnknownFailure(
        userMessage: 'We could not read that file. Choose it again.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (bytes.length != file.sizeBytes) {
      // The picker's size and the bytes disagree — the server checks the
      // declared size, so declare what we will actually send.
      AppLogger.debug(
        'Picked size ${file.sizeBytes} != read ${bytes.length}; using read',
        name: 'files',
      );
    }
    final digest = _computeSha256 ? sha256.convert(bytes).toString() : null;

    // ---- Step 1: register ----
    final ticket = await _run(
      () async => FileMappers.ticket(
        await _api.createUpload(
          purpose: purpose.wire,
          mime: file.mime,
          sizeBytes: bytes.length,
          sha256: digest,
          originalName: _originalName(file.name),
        ),
      ),
    );

    try {
      return await _sendAndScan(ticket, bytes, onProgress);
    } catch (_) {
      // The slot registered in step 1 will never be used: a retry registers
      // a new one. Remove it so failed attempts do not pile up (BL-REC-031).
      // Not awaited — the patient must not wait on the clean-up to be told.
      unawaited(_abandon(ticket.file.id));
      rethrow;
    }
  }

  /// Steps 2 and 3 for a registered [ticket].
  Future<UploadOutcome> _sendAndScan(
    UploadTicket ticket,
    Uint8List bytes,
    void Function(UploadProgress progress)? onProgress,
  ) async {
    // ---- Step 2: PUT to storage, exactly the ticket's headers ----
    onProgress?.call(const UploadProgress(phase: UploadPhase.uploading));
    await _runStorage(
      () => _storage.put(
        uploadUrl: ticket.uploadUrl,
        method: ticket.method,
        headers: ticket.headers,
        bytes: bytes,
        onProgress: (sent, total) {
          if (total <= 0) return;
          onProgress?.call(
            UploadProgress(
              phase: UploadPhase.uploading,
              fraction: (sent / total).clamp(0, 1),
            ),
          );
        },
      ),
    );

    // ---- Step 3: complete, then poll the scan ----
    onProgress?.call(const UploadProgress(phase: UploadPhase.scanning));
    final completed = await _run(
      () async => FileMappers.storedFile(await _api.complete(ticket.file.id)),
    );
    if (completed.status.isTerminal) return _outcome(completed);
    return _pollScan(completed);
  }

  /// Best-effort delete of a slot whose upload failed; never throws.
  Future<void> _abandon(String fileId) async {
    try {
      await _api.delete(fileId);
    } catch (error) {
      AppLogger.debug(
        'Abandoned upload $fileId not deleted: $error',
        name: 'files',
      );
    }
  }

  @override
  Future<UploadOutcome> awaitScan(String fileId) async {
    final current = await file(fileId);
    if (current.status.isTerminal) return _outcome(current);
    return _pollScan(current);
  }

  @override
  Future<StoredFile> file(String fileId) =>
      _run(() async => FileMappers.storedFile(await _api.file(fileId)));

  @override
  Future<void> delete(String fileId, {int? version}) =>
      _run(() => _api.delete(fileId, version: version));

  Future<UploadOutcome> _pollScan(StoredFile start) async {
    var latest = start;
    var waited = Duration.zero;
    for (var attempt = 1; ; attempt++) {
      final delay = _poll.delayFor(attempt);
      if (waited + delay > _poll.total) {
        AppLogger.warning(
          'Scan of ${latest.id} not finished after ${waited.inSeconds}s',
          name: 'files',
        );
        return UploadScanTimedOut(latest);
      }
      await _sleep(delay);
      waited += delay;
      latest = await file(latest.id);
      if (latest.status.isTerminal) return _outcome(latest);
    }
  }

  UploadOutcome _outcome(StoredFile file) {
    if (file.status == FileStatus.clean) return UploadClean(file);
    if (file.status.isRejected) return UploadRejected(file);
    // `sealed` cannot be attached to anything new; treat as not usable.
    return UploadRejected(file);
  }

  /// `original_name` is capped at 200 characters (§11.1).
  static String? _originalName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length <= 200 ? trimmed : trimmed.substring(0, 200);
  }

  Future<T> _run<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (error, stackTrace) {
      throw NetworkExceptions.toFailure(error, stackTrace);
    }
  }

  /// Step 2 talks to the storage host, not the API. The API answered step 1
  /// a moment ago, so a connection failure here is the storage host being
  /// unreachable — telling the patient *they* are offline would be wrong.
  Future<T> _runStorage<T>(Future<T> Function() request) async {
    try {
      return await request();
    } catch (error, stackTrace) {
      final failure = NetworkExceptions.toFailure(error, stackTrace);
      if (failure is NetworkFailure) {
        throw NetworkFailure(
          userMessage:
              'The file could not be sent to our storage. Check your '
              'connection and try again in a moment.',
          debugMessage: failure.debugMessage,
          cause: failure.cause,
          stackTrace: stackTrace,
        );
      }
      throw failure;
    }
  }
}
