import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/external_url.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/route_arrival.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_tag.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../common/attachments/domain/entities/stored_file.dart';
import '../../../common/attachments/presentation/components/attachment_upload_tile.dart';
import '../../application/providers/records_provider.dart';
import '../../domain/entities/medical_document.dart';
import '../components/document_type_icon.dart';
import '../../../appointments/application/providers/appointments_provider.dart'
    show appointmentLinkLabelProvider;
import '../../application/providers/documents_filter_controller.dart';
import 'document_edit_sheet.dart';

/// `/documents/:id` — one document in full (CM-34 … CM-36).
///
/// Reads `GET /patient/documents/{id}` through [documentProvider] and renders
/// its four states: skeleton, not-found (a stale deep link or a document
/// deleted elsewhere), error with retry, and the document.
///
/// **Open file** fetches a fresh ten-minute URL from
/// `GET …/download-url` every time (§11.3 — never cached) and hands it to
/// the platform with `url_launcher`. There is deliberately **no Share**:
/// medical documents are visible to the patient only (§11).
///
/// Route constant: [AppRoutes.documentPath].
class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(documentProvider(documentId));

    return RouteArrival(
      onArrive: () => ref.invalidate(documentProvider(documentId)),
      child: document.when(
        loading: () => _Frame(
          onBack: () => _leave(context),
          child: SingleChildScrollView(
            child: AppSkeletonList(
              count: 2,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x5.w,
                AppSpacing.x3.h,
                AppSpacing.x5.w,
                AppSpacing.x6.h,
              ),
            ),
          ),
        ),
        error: (error, _) {
          if (error is NotFoundFailure) {
            return AppNotFoundView(
              headline: 'Document not found',
              body: 'It may have been deleted from your records.',
              attemptedPath: AppRoutes.documentPath(documentId),
              onGoBack: context.canPop() ? () => context.pop() : null,
              onGoHome: () => context.go(AppRoutes.records),
              // It goes to Records, so it must not say "Go to Home".
              homeLabel: 'Go to Records',
              iconName: PhIcon.folder,
            );
          }
          return _Frame(
            onBack: () => _leave(context),
            child: AppErrorView(
              failure: error is Failure ? error : error.asFailure(),
              headline: 'We could not load this document',
              onRetry: () => ref.invalidate(documentProvider(documentId)),
            ),
          );
        },
        data: (doc) => _Frame(
          onBack: () => _leave(context),
          child: _Body(document: doc),
        ),
      ),
    );
  }

  static void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.records);
    }
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                title: 'Document',
                onBack: onBack,
                backSemanticLabel: 'Back to records',
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.document});

  final MedicalDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentId = document.appointmentId;
    // One `GET /patient/appointments/{id}` names the linked visit; loading
    // every appointment list to label one link was the old way.
    final linkedLabel = appointmentId == null
        ? null
        : ref.watch(appointmentLinkLabelProvider(appointmentId));
    final names = ref.watch(documentPersonNamesProvider);
    final actions = ref.watch(documentActionsProvider(document.id));
    final notes = document.notes;
    final createdAt = document.createdAt;
    final editedAt = document.lastEditedAt;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(AppSpacing.x5.w, 6.h, AppSpacing.x5.w, 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(document: document),
          SizedBox(height: 16.h),
          AppCard(
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(
                  icon: PhIcon.folder,
                  label: 'Patient',
                  value: names[document.personId] ?? 'A family member',
                ),
                _DetailRow(
                  icon: PhIcon.calendarBlank,
                  label: 'Date on the document',
                  value: AppDates.dayMonthYear(document.documentDate),
                ),
                if (createdAt != null)
                  _DetailRow(
                    icon: PhIcon.clock,
                    label: 'Added to your records',
                    value: AppDates.dayMonthYear(createdAt.toLocal()),
                  ),
                if (editedAt != null)
                  _DetailRow(
                    icon: PhIcon.pencilSimple,
                    label: 'Last edited',
                    value: AppDates.dayMonthYear(editedAt.toLocal()),
                  ),
                _DetailRow(
                  icon: PhIcon.calendarBlank,
                  label: 'Linked appointment',
                  value: appointmentId == null
                      ? 'Not linked to a visit'
                      : linkedLabel ?? 'A visit',
                  onTap: appointmentId == null
                      ? null
                      : () => context.push(
                          AppRoutes.appointmentDetailPath(appointmentId),
                        ),
                ),
                _DetailRow(
                  icon: PhIcon.downloadSimple,
                  label: 'File',
                  value: document.file.originalName.isEmpty
                      ? formatFileSize(document.file.sizeBytes)
                      : '${document.file.originalName} · '
                            '${formatFileSize(document.file.sizeBytes)}',
                ),
                if (notes != null && notes.isNotEmpty)
                  _DetailRow(
                    icon: PhIcon.pencilSimple,
                    label: 'Notes',
                    value: notes,
                    isLast: true,
                  ),
              ],
            ),
          ),
          SizedBox(height: 18.h),
          if (actions.failure != null) ...[
            AppInlineError(
              failure: actions.failure!,
              onRetry: ref
                  .read(documentActionsProvider(document.id).notifier)
                  .clearFailure,
              retryLabel: 'Dismiss',
            ),
            SizedBox(height: 12.h),
          ],
          _FileActions(document: document),
          SizedBox(height: 18.h),
          AppButton(
            label: 'Edit details',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.md,
            pill: true,
            fullWidth: true,
            leadingIcon: MedIcon.edit,
            disabled: actions.isBusy,
            semanticLabel: 'Edit the details of ${document.title}',
            onPressed: actions.isBusy
                ? null
                : () => showDocumentEditSheet(context, document.id),
          ),
          SizedBox(height: 12.h),
          AppButton(
            label: 'Delete document',
            variant: AppButtonVariant.danger,
            size: AppButtonSize.md,
            pill: true,
            fullWidth: true,
            loading: actions.isDeleting,
            disabled: actions.isResolvingUrl,
            semanticLabel: 'Delete ${document.title} from my records',
            onPressed: actions.isBusy ? null : () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete “${document.title}”?',
      consequence:
          'It is removed from your records and from any appointment it is '
          'attached to. This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep it',
      iconName: PhIcon.xCircle,
    );
    if (confirmed != true || !context.mounted) return;

    final failure = await ref
        .read(documentActionsProvider(document.id).notifier)
        .delete(document);
    if (!context.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    if (failure != null) {
      toast.show(
        failure is NotFoundFailure
            ? 'That document was already removed'
            : failure.userMessage,
      );
      if (failure is! NotFoundFailure) return;
    } else {
      toast.show('“${document.title}” deleted');
    }
    ref.invalidate(documentsListProvider);
    DocumentDetailScreen._leave(context);
  }
}

/// Type glyph, title, type tag and file status.
class _Heading extends StatelessWidget {
  const _Heading({required this.document});

  final MedicalDocument document;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48.r,
          height: 48.r,
          decoration: BoxDecoration(
            color: AppColors.surfaceTint,
            borderRadius: AppRadii.md,
          ),
          child: Center(
            child: AppIcon(
              DocumentTypeIcon.of(document.docType),
              size: 24,
              color: AppColors.brand,
            ),
          ),
        ),
        SizedBox(width: 14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                document.title,
                style: AppText.poppins(
                  size: AppFontSize.h3,
                  weight: AppText.bold,
                  color: AppColors.textStrong,
                ),
              ),
              SizedBox(height: 8.h),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  AppTag(label: document.docType.label),
                  if (document.file.status != FileStatus.clean)
                    AppTag(label: 'File: ${document.file.status.label}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The one file action: a fresh signed URL handed to the platform. View and
/// Download did exactly this, so they are a single "Open file" (BL-REC-034).
/// No Share (§11).
class _FileActions extends ConsumerWidget {
  const _FileActions({required this.document});

  final MedicalDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(documentActionsProvider(document.id));
    final ready = document.file.status == FileStatus.clean;
    final title = document.title;

    return AppButton(
      label: 'Open file',
      size: AppButtonSize.md,
      pill: true,
      fullWidth: true,
      leadingIcon: MedIcon.eye,
      loading: actions.isResolvingUrl,
      disabled: !ready || actions.isDeleting,
      semanticLabel: ready
          ? 'Open $title — opens in your browser, where you can view or '
                'save it'
          : 'File unavailable — the file is not ready',
      onPressed: ready && !actions.isBusy ? () => _open(context, ref) : null,
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final signed = await ref
        .read(documentActionsProvider(document.id).notifier)
        .downloadUrl(document.id);
    if (signed == null || !context.mounted) return;
    final launched = await openExternalUrl(signed.url);
    if (!launched && context.mounted) {
      ref
          .read(toastControllerProvider.notifier)
          .show('No app on this device could open the file');
    }
  }
}

/// One labelled detail line, optionally tappable (the linked appointment).
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.isLast = false,
  });

  final String icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: AppIcon(icon, size: 18, color: AppColors.textMuted),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  color: AppColors.textMuted,
                  height: 1.2,
                ),
              ),
              Text(
                value,
                style: AppText.poppins(
                  size: AppFontSize.base,
                  weight: AppText.semibold,
                  color: onTap == null
                      ? AppColors.textPrimary
                      : AppColors.textLink,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
      child: onTap == null
          ? row
          : Semantics(
              button: true,
              label: '$label: $value. Opens the appointment.',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: row,
              ),
            ),
    );
  }
}
