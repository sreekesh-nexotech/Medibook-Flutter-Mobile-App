import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/document_form.dart';
import '../controllers/document_form_controller.dart';

/// `/documents/upload` — add a document to the library (CM-33).
///
/// The screen is the frame: header, the [DocumentForm] body, and the submit
/// button. Everything the form collects is real, typed data written to
/// `documentsStoreProvider` — type, patient, recorded date, notes and the
/// optional appointment link — so the document appears in the Records list and
/// on that appointment's detail immediately.
///
/// The **file** is the one thing that cannot be real: this build ships no
/// file-picker, storage or share package and none may be added, so the form's
/// "Choose file" control declares itself stubbed. A document saved here
/// correctly reports `hasFile == false`, and its preview / download controls
/// render disabled with that reason rather than offering a download that
/// cannot work.
///
/// Route constant: [AppRoutes.documentUpload].
class DocumentUploadScreen extends ConsumerWidget {
  const DocumentUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // null documentId == create mode.
    final state = ref.watch(documentFormProvider(null));

    return AppUnsavedChangesGuard(
      hasUnsavedChanges: state.isDirty && !state.isSaving,
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
                        SizedBox(height: 24.h),
                        AppButton(
                          label: 'Save to records',
                          size: AppButtonSize.lg,
                          pill: true,
                          fullWidth: true,
                          // Blocks the repeat tap that would otherwise write
                          // two documents (audit §3.5.6).
                          loading: state.isSaving,
                          semanticLabel: 'Save this document to my records',
                          onPressed: () => _submit(context, ref),
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
    final saved = await ref.read(documentFormProvider(null).notifier).save();
    if (!context.mounted) return;
    if (saved == null) {
      // The form revealed its own field errors; say why nothing was saved
      // rather than reporting a save that did not happen.
      ref
          .read(toastControllerProvider.notifier)
          .show('Check the highlighted fields and try again');
      return;
    }
    ref
        .read(toastControllerProvider.notifier)
        .show('“${saved.title}” added to your records');
    // Replace the form with the document it created, so back goes to the list
    // rather than to a form that has already been submitted.
    if (context.canPop()) context.pop();
    context.push(AppRoutes.documentPath(saved.id));
  }

  /// Leaves the form.
  ///
  /// `Navigator.maybePop`, **not** `context.pop()`: go_router's `pop` calls
  /// `NavigatorState.pop` directly and so bypasses the `PopScope` that
  /// [AppUnsavedChangesGuard] installs. Using it here would mean the system
  /// back gesture warns about unsaved work while this screen's own Back and
  /// Cancel silently discard it.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      Navigator.maybePop(context);
    } else {
      context.go(AppRoutes.records);
    }
  }
}
