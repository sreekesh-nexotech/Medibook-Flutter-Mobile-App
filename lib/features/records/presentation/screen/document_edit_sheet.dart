import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/error/error_view.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../application/providers/records_provider.dart';
import '../components/document_form.dart';

/// Edit a document's details (CM-35), as a sheet over its detail screen.
///
/// Returns true when the edit was saved, so the caller can confirm it — and
/// **only** then, because a dismissed sheet must not report a save.
///
/// Not closed by a swipe: Flutter closes a swiped sheet without asking, and
/// unsaved changes must be asked about (the close button, a tap outside and
/// back all ask).
Future<bool?> showDocumentEditSheet(BuildContext context, String documentId) {
  return showAppSheet<bool>(
    context,
    title: 'Edit document',
    enableDrag: false,
    builder: (sheetContext) => DocumentEditBody(documentId: documentId),
  );
}

/// The edit form plus its save button. `PATCH /patient/documents/{id}` with
/// `If-Match` on the row's version; a stale version is a
/// `CONFLICT_VERSION` the user is told to reload for.
class DocumentEditBody extends ConsumerWidget {
  const DocumentEditBody({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentFormProvider(documentId));
    final failure = state.failure;

    // Closing with changes not saved asks first, as the upload screen does;
    // the sheet used to drop them without a word.
    return AppUnsavedChangesGuard(
      hasUnsavedChanges: state.isDirty && !state.isSaving,
      consequence: 'Your changes to this document will not be saved.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DocumentForm(documentId: documentId),
          if (failure != null && failure is! ValidationFailure) ...[
            SizedBox(height: 16.h),
            AppInlineError(failure: failure),
          ],
          SizedBox(height: 22.h),
          AppButton(
            label: 'Save changes',
            size: AppButtonSize.lg,
            pill: true,
            fullWidth: true,
            loading: state.isSaving,
            disabled: !state.isDirty && !state.isSaving,
            semanticLabel: state.isDirty
                ? 'Save changes to this document'
                : 'Save changes — nothing has been changed yet',
            onPressed: state.isDirty ? () => _submit(context, ref) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final saved = await ref
        .read(documentFormProvider(documentId).notifier)
        .save();
    if (!context.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    if (saved == null) {
      final failure = ref.read(documentFormProvider(documentId)).failure;
      if (failure is ConflictFailure) {
        // Changed on another device: show the server's version now rather
        // than leave the patient on a copy that can never be saved
        // (BL-REC-018).
        ref.invalidate(documentProvider(documentId));
        ref.invalidate(documentsListProvider);
        toast.show(
          'This document was changed on another device, so it has been '
          'reloaded. Make your change again.',
        );
        Navigator.of(context).pop(false);
        return;
      }
      toast.show(
        failure?.userMessage ?? 'Check the highlighted fields and try again',
      );
      return;
    }
    ref.invalidate(documentProvider(documentId));
    ref.invalidate(documentsListProvider);
    toast.show('Document updated');
    Navigator.of(context).pop(true);
  }
}
