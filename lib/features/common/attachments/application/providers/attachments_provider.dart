import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/error/failure.dart';
import '../../../../../core/utils/logger.dart';
import '../../domain/entities/stored_file.dart';
import '../../domain/repositories/file_upload_service.dart';
import '../../domain/repositories/file_url_resolver.dart';
import '../states/attachment_upload_state.dart';

/// The shared upload service (§11.1). Records, insurance and support all
/// depend on this abstract type; tests override it with a fake.
final fileUploadServiceProvider = Provider<FileUploadService>(
  (ref) =>
      throw UnimplementedError('fileUploadServiceProvider is wired in app/di'),
);

/// `file_id` → signed URL, memoised in memory for under ten minutes (§11.4).
/// App-lifetime on purpose: the memo is the point. It holds no PHI, only
/// URLs that expire on their own.
final fileUrlResolverProvider = Provider<FileUrlResolver>(
  (ref) =>
      throw UnimplementedError('fileUrlResolverProvider is wired in app/di'),
);

/// Drives one attachment slot: pick → validate → upload → scan, with a
/// typed state the UI renders. Holds no `BuildContext`; the screen reads
/// [state] and shows its own toasts.
class AttachmentUploadController extends StateNotifier<AttachmentUploadState> {
  AttachmentUploadController({
    required FileUploadService service,
    required FileUploadPurpose purpose,
  }) : _service = service,
       _purpose = purpose,
       super(const AttachmentUploadState());

  final FileUploadService _service;
  final FileUploadPurpose _purpose;

  FileUploadPurpose get purpose => _purpose;

  /// Open the picker and, if a file is chosen, upload it straight away.
  /// Returns the resulting state so a caller can react without watching.
  Future<AttachmentUploadState> pickAndUpload({
    PickSource source = PickSource.files,
  }) async {
    if (state.isBusy) return state;
    // What the tile showed before the picker opened — restored as it was if
    // the patient cancels, failure message included (BL-REC-030: a cancel
    // used to swap "The file could not be sent…" for "Something went
    // wrong.").
    final before = state;
    state = state.copyWith(
      status: AttachmentStatus.picking,
      clearFailure: true,
    );
    final PickedFile? picked;
    try {
      picked = await _service.pick(_purpose, source: source);
    } catch (error, stackTrace) {
      if (!mounted) return state;
      state = before.copyWith(
        status: before.picked == null
            ? AttachmentStatus.failed
            : _statusFor(before),
        failure: error.asFailure(stackTrace),
      );
      return state;
    }
    if (!mounted) return state;
    if (picked == null) {
      // Cancelled: back to exactly what was there before.
      state = before;
      return state;
    }
    return _upload(picked);
  }

  /// Upload a file the caller already has (tests, drag-and-drop later).
  Future<AttachmentUploadState> uploadPicked(PickedFile picked) =>
      _upload(picked);

  /// Re-run the upload for the file already picked (after a network error).
  Future<AttachmentUploadState> retry() {
    final picked = state.picked;
    if (picked == null || state.isBusy) return Future.value(state);
    return _upload(picked);
  }

  /// Poll again after [AttachmentStatus.scanTimedOut].
  Future<AttachmentUploadState> waitForScan() async {
    final file = state.file;
    if (file == null || state.isBusy) return state;
    state = state.copyWith(
      status: AttachmentStatus.uploading,
      progress: const UploadProgress(phase: UploadPhase.scanning),
      clearFailure: true,
    );
    try {
      _apply(await _service.awaitScan(file.id));
    } catch (error, stackTrace) {
      if (!mounted) return state;
      state = state.copyWith(
        status: AttachmentStatus.failed,
        failure: error.asFailure(stackTrace),
        clearProgress: true,
      );
    }
    return state;
  }

  /// Forget the selection. A file already registered server-side is deleted
  /// best-effort so orphans do not pile up; failures are logged, not shown.
  Future<void> clear() async {
    final file = state.file;
    state = const AttachmentUploadState();
    await _discard(file);
  }

  /// Delete a file this slot no longer wants. Best-effort: a file something
  /// already references is refused by the server (`FILE_IN_USE`), and any
  /// failure is logged, never shown.
  Future<void> _discard(StoredFile? file) async {
    if (file == null) return;
    try {
      await _service.delete(file.id);
    } catch (error) {
      AppLogger.debug(
        'Orphan file ${file.id} not deleted: $error',
        name: 'files',
      );
    }
  }

  @override
  void dispose() {
    // The form was left with a file it never used (BL-REC-031). A file that
    // was handed over is no longer on the state — see [detachOwnership].
    unawaited(_discard(state.file));
    super.dispose();
  }

  /// The slot is being handed to a document / policy; keep the file, stop
  /// owning it (so [clear] afterwards does not delete it).
  void detachOwnership() {
    state = state.copyWith(clearFile: true, clearPicked: true);
    state = const AttachmentUploadState();
  }

  Future<AttachmentUploadState> _upload(PickedFile picked) async {
    // Replacing a file, or choosing another after a rejected scan: the one
    // being given up must not stay on the server (BL-REC-031).
    final replaced = state.file;
    state = AttachmentUploadState(
      status: AttachmentStatus.uploading,
      picked: picked,
      progress: const UploadProgress(phase: UploadPhase.preparing),
    );
    unawaited(_discard(replaced));
    try {
      final outcome = await _service.upload(
        picked,
        purpose: _purpose,
        onProgress: (progress) {
          if (!mounted) return;
          state = state.copyWith(progress: progress);
        },
      );
      if (!mounted) {
        // The form was left mid-upload; nothing will ever use this file.
        unawaited(_discard(outcome.file));
        return const AttachmentUploadState();
      }
      _apply(outcome);
    } catch (error, stackTrace) {
      if (!mounted) return state;
      state = state.copyWith(
        status: AttachmentStatus.failed,
        failure: error.asFailure(stackTrace),
        clearProgress: true,
      );
    }
    return state;
  }

  void _apply(UploadOutcome outcome) {
    if (!mounted) return;
    state = switch (outcome) {
      UploadClean(:final file) => state.copyWith(
        status: AttachmentStatus.ready,
        file: file,
        clearProgress: true,
        clearFailure: true,
      ),
      UploadRejected(:final file) => state.copyWith(
        status: AttachmentStatus.rejected,
        file: file,
        clearProgress: true,
        clearFailure: true,
      ),
      UploadScanTimedOut(:final file) => state.copyWith(
        status: AttachmentStatus.scanTimedOut,
        file: file,
        clearProgress: true,
        clearFailure: true,
      ),
    };
  }

  static AttachmentStatus _statusFor(AttachmentUploadState previous) {
    if (previous.picked == null) return AttachmentStatus.idle;
    if (previous.file?.status == FileStatus.clean) {
      return AttachmentStatus.ready;
    }
    if (previous.file?.status.isRejected ?? false) {
      return AttachmentStatus.rejected;
    }
    if (previous.file != null) return AttachmentStatus.scanTimedOut;
    return AttachmentStatus.failed;
  }
}

/// One attachment slot per purpose. `autoDispose`: the slot belongs to the
/// form that opened it; leaving the form drops the selection.
///
/// A screen that needs several slots of the same purpose uses
/// [attachmentSlotProvider]; records and insurance each need one.
final attachmentUploadProvider = StateNotifierProvider.autoDispose
    .family<
      AttachmentUploadController,
      AttachmentUploadState,
      FileUploadPurpose
    >(
      (ref, purpose) => AttachmentUploadController(
        service: ref.watch(fileUploadServiceProvider),
        purpose: purpose,
      ),
    );

/// One of several numbered slots on one form — support requests and replies
/// take up to five files (§13, `attachment_file_ids` ≤ 5).
///
/// [form] keeps two forms' slots apart (the new-request form and a ticket's
/// reply box). `autoDispose` like [attachmentUploadProvider]: leaving the
/// form drops — and deletes — whatever it never sent.
typedef AttachmentSlot = ({FileUploadPurpose purpose, String form, int index});

final attachmentSlotProvider = StateNotifierProvider.autoDispose
    .family<AttachmentUploadController, AttachmentUploadState, AttachmentSlot>(
      (ref, slot) => AttachmentUploadController(
        service: ref.watch(fileUploadServiceProvider),
        purpose: slot.purpose,
      ),
    );
