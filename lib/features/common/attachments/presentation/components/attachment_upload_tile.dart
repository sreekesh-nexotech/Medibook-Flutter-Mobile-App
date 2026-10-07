import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../app/theme/colors.dart';
import '../../../../../app/theme/theme.dart';
import '../../../../../app/theme/typography.dart';
import '../../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_icon.dart';
import '../../../../../core/error/failure.dart';
import '../../../../../core/network/network_exceptions.dart';
import '../../../../../core/utils/file_size.dart';
import '../../../../../core/widgets/states/app_loading_view.dart';
import '../../../../support/application/providers/app_config_provider.dart';
import '../../application/providers/attachments_provider.dart';
import '../../application/states/attachment_upload_state.dart';
import '../../domain/entities/stored_file.dart';
import '../../domain/repositories/file_upload_service.dart';

/// "1.2 MB" / "420 KB" / "—".
String formatFileSize(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// The one attachment control shared by the document form and the policy
/// screens: choose a file (files / photo library / camera), then show the
/// upload as it really is — progress while the bytes move, a skeleton while
/// the scanner works, a rejected state in words, a retry after a failure.
///
/// Reads and drives [attachmentUploadProvider] for [purpose]. It never claims
/// a file is attached until the server says `clean`.
class AttachmentUploadTile extends ConsumerWidget {
  const AttachmentUploadTile({
    super.key,
    required this.purpose,
    this.title = 'File',
    this.helper,
    this.enabled = true,
    this.errorText,
    this.slot,
  });

  final FileUploadPurpose purpose;

  /// One of several numbered slots ([attachmentSlotProvider]) instead of the
  /// purpose's single slot.
  final AttachmentSlot? slot;

  /// Label above the tile.
  final String title;

  /// A quiet line when nothing is chosen. Defaults to the accepted types and
  /// the server's current size limit ("PDF, JPEG, PNG or HEIC, up to 10 MB").
  final String? helper;

  final bool enabled;

  /// A form-level error ("Choose a file first"), shown under the tile.
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = slot == null
        ? attachmentUploadProvider(purpose)
        : attachmentSlotProvider(slot!);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final limit = formatSizeLimit(ref.watch(uploadMaxBytesProvider));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppText.poppins(
            size: AppFontSize.base,
            weight: AppText.medium,
            color: AppColors.textStrong,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadii.md,
            border: Border.all(
              color: errorText != null
                  ? AppColors.danger
                  : state.status == AttachmentStatus.rejected
                  ? AppColors.danger
                  : AppColors.border,
              width: 1.w,
            ),
          ),
          child: switch (state.status) {
            AttachmentStatus.idle => _IdleBody(
              helper: helper ?? 'PDF, JPEG, PNG or HEIC, up to $limit',
              enabled: enabled,
              onChoose: () => _choose(context, controller),
            ),
            AttachmentStatus.picking => const _ScanningBody(
              label: 'Opening picker…',
            ),
            AttachmentStatus.uploading => _UploadingBody(state: state),
            AttachmentStatus.ready => _ReadyBody(
              state: state,
              enabled: enabled,
              onReplace: () => _choose(context, controller),
              onRemove: controller.clear,
            ),
            AttachmentStatus.rejected => _RejectedBody(
              state: state,
              onChooseAnother: () => _choose(context, controller),
            ),
            AttachmentStatus.scanTimedOut => _TimedOutBody(
              state: state,
              onWait: controller.waitForScan,
              onDiscard: controller.clear,
            ),
            AttachmentStatus.failed => _FailedBody(
              state: state,
              onRetry: state.picked == null
                  ? () => _choose(context, controller)
                  : controller.retry,
              onChooseAnother: () => _choose(context, controller),
            ),
          },
        ),
        if (errorText != null) ...[
          SizedBox(height: 6.h),
          Text(
            errorText!,
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.dangerText,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _choose(
    BuildContext context,
    AttachmentUploadController controller,
  ) async {
    final source = await showAppSheet<PickSource>(
      context,
      title: 'Add a file',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SourceRow(
            icon: PhIcon.folder,
            label: 'Choose a file',
            subtitle: 'A PDF or an image from your files',
            onTap: () => Navigator.of(sheetContext).pop(PickSource.files),
          ),
          _SourceRow(
            icon: PhIcon.eye,
            label: 'Photo library',
            subtitle: 'A photo of the document',
            onTap: () => Navigator.of(sheetContext).pop(PickSource.gallery),
          ),
          _SourceRow(
            icon: MedIcon.video,
            label: 'Take a photo',
            subtitle: 'Use the camera now',
            onTap: () => Navigator.of(sheetContext).pop(PickSource.camera),
          ),
        ],
      ),
    );
    if (source == null) return;
    await controller.pickAndUpload(source: source);
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: 48.h),
          margin: EdgeInsets.only(bottom: 8.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: AppRadii.md,
            border: Border.all(color: AppColors.border, width: 1.w),
          ),
          child: Row(
            children: [
              AppIcon(icon, size: 20, color: AppColors.brand),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.poppins(
                        size: AppFontSize.base,
                        weight: AppText.medium,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileLine extends StatelessWidget {
  const _FileLine({
    required this.name,
    required this.detail,
    this.iconColor = AppColors.textMuted,
    this.detailColor = AppColors.textMuted,
  });

  final String name;
  final String detail;
  final Color iconColor;
  final Color detailColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(PhIcon.folder, size: 20, color: iconColor),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.poppins(
                  size: AppFontSize.base,
                  weight: AppText.medium,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                detail,
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  color: detailColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdleBody extends StatelessWidget {
  const _IdleBody({
    required this.helper,
    required this.enabled,
    required this.onChoose,
  });

  final String helper;
  final bool enabled;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FileLine(name: 'No file chosen', detail: helper),
        SizedBox(height: 12.h),
        AppButton(
          label: 'Choose file',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.sm,
          pill: true,
          fullWidth: true,
          disabled: !enabled,
          semanticLabel: 'Choose a file to upload',
          onPressed: enabled ? onChoose : null,
        ),
      ],
    );
  }
}

class _UploadingBody extends StatelessWidget {
  const _UploadingBody({required this.state});

  final AttachmentUploadState state;

  @override
  Widget build(BuildContext context) {
    final picked = state.picked;
    final progress = state.progress;
    final phase = progress?.phase ?? UploadPhase.preparing;
    final label = switch (phase) {
      UploadPhase.preparing => 'Preparing…',
      UploadPhase.uploading =>
        'Uploading ${((progress?.fraction ?? 0) * 100).round()}%',
      UploadPhase.scanning => 'Checking the file for viruses…',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FileLine(
          name: picked?.name ?? 'File',
          detail: '${formatFileSize(picked?.sizeBytes ?? 0)} · $label',
          iconColor: AppColors.brand,
        ),
        SizedBox(height: 12.h),
        if (phase == UploadPhase.scanning)
          // Skeleton while the scanner works: nothing to measure, so no bar.
          const _ScanningBody(label: 'This usually takes a few seconds')
        else
          Semantics(
            label: label,
            child: ClipRRect(
              borderRadius: AppRadii.pill,
              child: LinearProgressIndicator(
                minHeight: 6.h,
                value: phase == UploadPhase.uploading
                    ? (progress?.fraction ?? 0)
                    : null,
                backgroundColor: AppColors.border,
                color: AppColors.brand,
              ),
            ),
          ),
      ],
    );
  }
}

class _ScanningBody extends StatelessWidget {
  const _ScanningBody({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSkeletonLine(height: 12),
        SizedBox(height: 8.h),
        const AppSkeletonLine(width: 160, height: 12),
        SizedBox(height: 8.h),
        Text(
          label,
          style: AppText.poppins(
            size: AppFontSize.xs,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.state,
    required this.enabled,
    required this.onReplace,
    required this.onRemove,
  });

  final AttachmentUploadState state;
  final bool enabled;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final file = state.file;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FileLine(
          name: file?.originalName ?? state.picked?.name ?? 'File',
          detail: '${formatFileSize(file?.sizeBytes ?? 0)} · Scanned, ready',
          iconColor: AppColors.success,
          detailColor: AppColors.successText,
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Replace',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                pill: true,
                fullWidth: true,
                disabled: !enabled,
                onPressed: enabled ? onReplace : null,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: AppButton(
                label: 'Remove',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                pill: true,
                fullWidth: true,
                disabled: !enabled,
                onPressed: enabled ? onRemove : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RejectedBody extends StatelessWidget {
  const _RejectedBody({required this.state, required this.onChooseAnother});

  final AttachmentUploadState state;
  final VoidCallback onChooseAnother;

  @override
  Widget build(BuildContext context) {
    final failed = state.file?.status == FileStatus.scanFailed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FileLine(
          name: state.picked?.name ?? 'File',
          detail: failed
              ? 'The virus check could not be completed, so this file was '
                    'rejected. Try a different file.'
              : 'This file was rejected by the virus check and cannot be '
                    'stored.',
          iconColor: AppColors.danger,
          detailColor: AppColors.dangerText,
        ),
        SizedBox(height: 12.h),
        AppButton(
          label: 'Choose another file',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.sm,
          pill: true,
          fullWidth: true,
          onPressed: onChooseAnother,
        ),
      ],
    );
  }
}

class _TimedOutBody extends StatelessWidget {
  const _TimedOutBody({
    required this.state,
    required this.onWait,
    required this.onDiscard,
  });

  final AttachmentUploadState state;
  final VoidCallback onWait;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FileLine(
          name: state.picked?.name ?? 'File',
          detail:
              'Uploaded, but the virus check is taking longer than usual. '
              'It cannot be attached until it passes.',
          iconColor: AppColors.warning,
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Keep waiting',
                size: AppButtonSize.sm,
                pill: true,
                fullWidth: true,
                onPressed: onWait,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: AppButton(
                label: 'Discard',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                pill: true,
                fullWidth: true,
                onPressed: onDiscard,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FailedBody extends StatelessWidget {
  const _FailedBody({
    required this.state,
    required this.onRetry,
    required this.onChooseAnother,
  });

  final AttachmentUploadState state;
  final VoidCallback onRetry;
  final VoidCallback onChooseAnother;

  /// The file itself was refused — too large, a type not accepted, or
  /// empty — so sending it again cannot work; only another file can.
  static bool _isFileRefused(Failure? failure) =>
      failure != null &&
      (failure.apiCode == ApiErrorCodes.fileTooLarge ||
          failure.apiCode == ApiErrorCodes.fileTypeNotAllowed ||
          (failure is ValidationFailure &&
              failure.fieldErrors.containsKey('file')));

  @override
  Widget build(BuildContext context) {
    final hasPick = state.picked != null;
    final canRetry = hasPick && !_isFileRefused(state.failure);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FileLine(
          name: state.picked?.name ?? 'Upload failed',
          detail: state.failure?.userMessage ?? 'Something went wrong.',
          iconColor: AppColors.danger,
          detailColor: AppColors.dangerText,
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            if (canRetry) ...[
              Expanded(
                child: AppButton(
                  label: 'Try again',
                  size: AppButtonSize.sm,
                  pill: true,
                  fullWidth: true,
                  onPressed: onRetry,
                ),
              ),
              SizedBox(width: 10.w),
            ],
            Expanded(
              child: AppButton(
                label: hasPick ? 'Choose another' : 'Choose file',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.sm,
                pill: true,
                fullWidth: true,
                onPressed: onChooseAnother,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
