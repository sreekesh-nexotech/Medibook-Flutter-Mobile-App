import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/document_form.dart';
import '../controllers/document_form_controller.dart';

/// Edit a document's details (CM-35), as a sheet over its detail screen.
///
/// A sheet keeps the document you are editing visible behind the scrim, which
/// is the same reasoning as the filter sheet: the thing being changed is the
/// context for the change.
///
/// Returns true when the edit was saved, so the caller can confirm it — and
/// **only** then, because a dismissed sheet must not report a save.
Future<bool?> showDocumentEditSheet(BuildContext context, String documentId) {
  return showAppSheet<bool>(
    context,
    title: 'Edit document',
    builder: (sheetContext) => DocumentEditBody(documentId: documentId),
  );
}

/// The edit form plus its save button.
///
/// `DocumentsStore.patch` covers title / type / patient / notes, so the form
/// renders the recorded date and the appointment link disabled with that
/// reason — an honest disabled control rather than two fields that silently
/// discard what you type into them.
class DocumentEditBody extends ConsumerWidget {
  const DocumentEditBody({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentFormProvider(documentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DocumentForm(documentId: documentId),
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
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final saved = await ref
        .read(documentFormProvider(documentId).notifier)
        .save();
    if (!context.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    if (saved == null) {
      toast.show('Check the highlighted fields and try again');
      return;
    }
    toast.show('Document updated');
    Navigator.of(context).pop(true);
  }
}
