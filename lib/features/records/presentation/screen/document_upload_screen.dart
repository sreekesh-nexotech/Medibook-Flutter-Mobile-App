import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../common/attachments/application/providers/attachments_provider.dart';
import '../../../common/attachments/domain/entities/stored_file.dart';
import '../../application/providers/records_provider.dart';
import '../components/document_form.dart';

/// `/documents/upload` — add a document to the library (CM-33).
///
/// The screen is the frame: header, the [DocumentForm] body and the submit
/// button. The file goes up through the shared attachment slot (§11.1: pick
/// → upload → scan); once it is `clean` its id and the form's fields go to
/// `POST /patient/documents`. The button stays disabled while the scan is
/// running, so nothing is saved against a file the server would refuse.
///
/// Route constant: [AppRoutes.documentUpload].
class DocumentUploadScreen extends ConsumerWidget {
  const DocumentUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentFormProvider(null));
    final upload = ref.watch(
      attachmentUploadProvider(FileUploadPurpose.medicalDocument),
    );
    final hasUnsaved =
        (state.isDirty || upload.hasSelection) && !state.isSaving;

    // A different file answers the server's complaint about the last one.
    ref.listen(
      attachmentUploadProvider(
        FileUploadPurpose.medicalDocument,
      ).select((slot) => slot.readyFileId),
      (previous, next) {
        if (previous != next) {
          ref.read(documentFormProvider(null).notifier).fileChanged();
        }
      },
    );

    return AppUnsavedChangesGuard(
      hasUnsavedChanges: hasUnsaved,
      title: 'Discard this document?',
      consequence:
          'The details you have entered will not be saved to your records.',
      child: Scaffold(
        backgroundColor: AppColors.bgApp,
        body: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: AppConstants.screenIn,
          curve: Curves.easeOut,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 10.h),
              child: child,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                AppInnerHeader(
                  title: 'Upload document',
                  onBack: () => _leave(context),
                  backSemanticLabel: 'Back to records',
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.x5.w,
                      6.h,
                      AppSpacing.x5.w,
                      24.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const DocumentForm(),
                        if (state.failure != null &&
                            state.failure is! ValidationFailure) ...[
                          SizedBox(height: 16.h),
                          AppInlineError(
                            failure: state.failure!,
                            onRetry: () => _submit(context, ref),
                          ),
                        ],
                        SizedBox(height: 24.h),
                        AppButton(
                          label: upload.isBusy
                              ? 'Waiting for the file…'
                              : 'Save to records',
                          size: AppButtonSize.lg,
                          pill: true,
                          fullWidth: true,
                          loading: state.isSaving,
                          disabled: upload.isBusy,
                          semanticLabel: upload.isBusy
                              ? 'Save is available once the file has been '
                                    'checked'
                              : 'Save this document to my records',
                          onPressed: upload.isBusy
                              ? null
                              : () => _submit(context, ref),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final slot = ref.read(
      attachmentUploadProvider(FileUploadPurpose.medicalDocument),
    );
    final saved = await ref
        .read(documentFormProvider(null).notifier)
        .save(fileId: slot.readyFileId);
    if (!context.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    if (saved == null) {
      final failure = ref.read(documentFormProvider(null)).failure;
      toast.show(
        failure?.userMessage ?? 'Check the highlighted fields and try again',
      );
      return;
    }
    // The file now belongs to the document; the slot must not delete it.
    ref
        .read(
          attachmentUploadProvider(FileUploadPurpose.medicalDocument).notifier,
        )
        .detachOwnership();
    ref.invalidate(documentsListProvider);
    toast.show('“${saved.title}” added to your records');
    if (context.canPop()) context.pop();
    context.push(AppRoutes.documentPath(saved.id));
  }

  /// `Navigator.maybePop`, **not** `context.pop()`, so the unsaved-changes
  /// guard's `PopScope` gets its say.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      Navigator.maybePop(context);
    } else {
      context.go(AppRoutes.records);
    }
  }
}
