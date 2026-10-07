import '../../../../../core/error/failure.dart';
import '../../domain/entities/stored_file.dart';

/// Where one attachment slot is in its life.
enum AttachmentStatus {
  /// Nothing chosen yet.
  idle,

  /// The platform picker is open.
  picking,

  /// Registering / sending bytes / waiting for the scan — see
  /// [AttachmentUploadState.progress].
  uploading,

  /// Scanned clean; [AttachmentUploadState.file] may be attached.
  ready,

  /// The scanner rejected it (`infected` / `scan_failed`).
  rejected,

  /// The scan did not answer in time; the user can wait again or discard.
  scanTimedOut,

  /// Validation or transport failed; [AttachmentUploadState.failure] says
  /// why.
  failed,
}

/// Immutable state of one attachment slot (a document's file, a policy's
/// PDF). Owned by `AttachmentUploadController`.
class AttachmentUploadState {
  const AttachmentUploadState({
    this.status = AttachmentStatus.idle,
    this.picked,
    this.file,
    this.progress,
    this.failure,
  });

  final AttachmentStatus status;

  /// The device file the user chose, kept so a retry does not re-open the
  /// picker.
  final PickedFile? picked;

  /// The server-side file, once step 1 has answered.
  final StoredFile? file;

  final UploadProgress? progress;
  final Failure? failure;

  bool get isBusy =>
      status == AttachmentStatus.picking ||
      status == AttachmentStatus.uploading;

  /// A `clean` file id that may be sent as `file_id`.
  String? get readyFileId => status == AttachmentStatus.ready ? file?.id : null;

  bool get hasSelection => picked != null;

  AttachmentUploadState copyWith({
    AttachmentStatus? status,
    PickedFile? picked,
    bool clearPicked = false,
    StoredFile? file,
    bool clearFile = false,
    UploadProgress? progress,
    bool clearProgress = false,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return AttachmentUploadState(
      status: status ?? this.status,
      picked: clearPicked ? null : (picked ?? this.picked),
      file: clearFile ? null : (file ?? this.file),
      progress: clearProgress ? null : (progress ?? this.progress),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}
