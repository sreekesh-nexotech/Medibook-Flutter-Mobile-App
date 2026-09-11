import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/medical_record.dart';
import '../../../../core/mock_data/stores/documents_store.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/app_tag.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/document_type_icon.dart';
import '../controllers/linkable_appointments_provider.dart';
import 'document_edit_sheet.dart';

/// `/documents/:id` — one document in full (CM-34 … CM-36).
///
/// Shows every field the library actually stores — type, patient, facility,
/// consulting doctor, recorded date, upload date, the linked appointment and
/// the notes — plus **Edit** and **Delete**.
///
/// Three honesty rules hold here, because this build ships no PDF renderer, no
/// storage and no share package:
///
/// * **View / Download / Share** are stubbed or disabled with a reason. None
///   of them ever reports a file that did not move.
/// * **Delete** is destructive, so it goes through [showAppConfirmDialog], and
///   `DocumentsStore.remove` returns a `bool` — this screen reports success
///   only on `true`.
/// * An unknown id renders [AppNotFoundView] rather than an empty shell, which
///   is what a stale deep link or a document deleted on another screen hits.
///
/// Route constant: [AppRoutes.documentPath] (`AppRoutes.documentPath(id)`).
class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({super.key, required this.documentId});

  /// The `MedicalRecord.id` to show.
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(documentByIdProvider(documentId));

    if (document == null) {
      return AppNotFoundView(
        headline: 'Document not found',
        body: 'It may have been deleted from your records.',
        attemptedPath: AppRoutes.documentPath(documentId),
        onGoBack: context.canPop() ? () => context.pop() : null,
        onGoHome: () => context.go(AppRoutes.records),
        iconName: MedIcon.records,
      );
    }

    final appointmentId = document.appointmentId;
    final linked = appointmentId == null
        ? null
        : ref.watch(linkableAppointmentByIdProvider(appointmentId));
    final notes = document.notes;

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
                      _Heading(document: document),
                      SizedBox(height: 16.h),
                      AppCard(
                        padding: EdgeInsets.all(18.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailRow(
                              icon: MedIcon.records,
                              label: 'Patient',
                              value: document.patient.isEmpty
                                  ? 'Not recorded'
                                  : document.patient,
                            ),
                            _DetailRow(
                              icon: MedIcon.calendar,
                              label: 'Date on the document',
                              value: document.date,
                            ),
                            _DetailRow(
                              icon: MedIcon.clock,
                              label: 'Added to your records',
                              value: document.uploadedLabel,
                            ),
                            if (document.hospital.isNotEmpty)
                              _DetailRow(
                                icon: MedIcon.hospital,
                                label: 'Center / hospital',
                                value: document.hospital,
                              ),
                            if (document.doctor.isNotEmpty)
                              _DetailRow(
                                icon: MedIcon.records,
                                label: 'Consulted doctor',
                                value: document.doctor,
                              ),
                            _DetailRow(
                              icon: MedIcon.calendar,
                              label: 'Linked appointment',
                              value: linked?.label ?? 'Not linked to a visit',
                              onTap: appointmentId == null
                                  ? null
                                  : () => context.push(
                                      AppRoutes.appointmentDetailPath(
                                        appointmentId,
                                      ),
                                    ),
                            ),
                            _DetailRow(
                              icon: MedIcon.download,
                              label: 'File',
                              value: document.hasFile
                                  ? '${document.fileName} · '
                                        '${document.fileSizeLabel}'
                                  : 'No file attached',
                            ),
                            if (notes != null && notes.isNotEmpty)
                              _DetailRow(
                                icon: MedIcon.edit,
                                label: 'Notes',
                                value: notes,
                                isLast: true,
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 18.h),
                      _FileActions(document: document),
                      SizedBox(height: 18.h),
                      AppButton(
                        label: 'Edit details',
                        variant: AppButtonVariant.secondary,
                        size: AppButtonSize.md,
                        pill: true,
                        fullWidth: true,
                        leadingIcon: MedIcon.edit,
                        semanticLabel:
                            'Edit the details of '
                            '${document.title}',
                        onPressed: () =>
                            showDocumentEditSheet(context, document.id),
                      ),
                      SizedBox(height: 12.h),
                      AppButton(
                        label: 'Delete document',
                        variant: AppButtonVariant.danger,
                        size: AppButtonSize.md,
                        pill: true,
                        fullWidth: true,
                        semanticLabel:
                            'Delete ${document.title} from my '
                            'records',
                        onPressed: () => _delete(context, ref, document),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirms, then removes. `remove` returns false for an id that is already
  /// gone (deleted on another surface, or a stale deep link), and that case
  /// reports the truth instead of a deletion that did not happen.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MedicalRecord document,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Delete “${document.title}”?',
      consequence:
          'It is removed from your records and from any appointment it is '
          'attached to. This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep it',
      iconName: MedIcon.closeCircle,
    );
    if (confirmed != true || !context.mounted) return;

    final removed = ref
        .read(documentsStoreProvider.notifier)
        .remove(document.id);
    if (!context.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    if (!removed) {
      toast.show('That document was already removed');
      return;
    }
    toast.show('“${document.title}” deleted');
    _leave(context);
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.records);
    }
  }
}

/// Type glyph, title, type tag and status badge.
class _Heading extends StatelessWidget {
  const _Heading({required this.document});

  final MedicalRecord document;

  @override
  Widget build(BuildContext context) {
    final isCompleted = document.status == RecordStatus.completed;

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
              DocumentTypeIcon.of(document.type),
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
                  AppTag(label: document.type.label),
                  AppBadge(
                    label: document.status.label,
                    tone: isCompleted
                        ? AppBadgeTone.success
                        : AppBadgeTone.warning,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The three file controls, each honest about what this build can do.
///
/// With a file on the record they are `stubbed` and say so; with no file — the
/// state of every document created in-app, since there is no picker — they are
/// `disabled` and their `semanticLabel` gives the reason.
class _FileActions extends ConsumerWidget {
  const _FileActions({required this.document});

  final MedicalRecord document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFile = document.hasFile;
    final title = document.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'View',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.md,
                pill: true,
                fullWidth: true,
                leadingIcon: MedIcon.eye,
                stubbed: hasFile,
                disabled: !hasFile,
                semanticLabel: hasFile
                    ? 'Preview $title — stubbed in this demo'
                    : 'Preview unavailable — no file is attached to $title',
                onPressed: hasFile
                    ? () => showStubbedToast(context, ref, 'Preview')
                    : null,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: AppButton(
                label: 'Download',
                size: AppButtonSize.md,
                pill: true,
                fullWidth: true,
                leadingIcon: MedIcon.download,
                stubbed: hasFile,
                disabled: !hasFile,
                semanticLabel: hasFile
                    ? 'Download $title — stubbed in this demo'
                    : 'Download unavailable — no file is attached to $title',
                onPressed: hasFile
                    ? () => showStubbedToast(context, ref, 'Download')
                    : null,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        AppButton(
          label: 'Share',
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.md,
          pill: true,
          fullWidth: true,
          stubbed: hasFile,
          disabled: !hasFile,
          semanticLabel: hasFile
              ? 'Share $title — stubbed in this demo'
              : 'Sharing unavailable — no file is attached to $title',
          onPressed: hasFile
              ? () => showStubbedToast(context, ref, 'Share')
              : null,
        ),
      ],
    );
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
      // No fixed height: every row grows with the OS text scale.
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
