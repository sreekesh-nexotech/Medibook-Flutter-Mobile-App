import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/medical_record.dart';
import '../../../../core/mock_data/stores/documents_store.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../notifications/presentation/components/notification_bell.dart';
import '../components/document_filter_chips_row.dart';
import '../components/record_card.dart';
import '../controllers/documents_filter_controller.dart';
import '../controllers/linkable_appointments_provider.dart';
import 'documents_filter_sheet.dart';

/// Records tab (`/records`) — the documents library (CM-32 … CM-36).
///
/// Lives inside the bottom-nav shell, so it renders no nav bar of its own.
/// What it adds over the three fixed report cards the audit found:
///
/// * the real list from `documentsStoreProvider`, newest first on
///   `recordedAt` (never on the rendered date string — audit §3.8.3);
/// * **Upload** (`/documents/upload`) from the header *and* from the empty
///   state, because a fresh account has zero documents and that empty state is
///   the first thing a real user sees (§3.2.2 — an empty state must offer the
///   one thing the user came to do);
/// * **Filters** by type / patient / date range / linked appointment, with
///   every active facet as a removable chip plus "Clear all";
/// * a tap on a card opens the document detail (`/documents/:id`);
/// * **pull-to-refresh** (§3.9.4 names Records as one of the three feeds users
///   will try to pull).
///
/// The preview and download controls stay honestly stubbed: this build ships
/// no PDF renderer, storage or share package. See [RecordCard].
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(filteredDocumentsProvider);
    final total = ref.watch(sortedDocumentsProvider).length;
    final chips = ref.watch(documentFilterChipsProvider);
    final isFiltered = chips.isNotEmpty;

    return ColoredBox(
      color: AppColors.bgApp,
      child: SafeArea(
        bottom: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: AppConstants.fadeIn,
          curve: Curves.easeOut,
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTabHeader(
                title: 'Records',
                trailing: NotificationBellButton(
                  onPressed: () => context.push(AppRoutes.notifications),
                ),
              ),
              _ActionRow(
                shown: documents.length,
                total: total,
                isFiltered: isFiltered,
                onFilter: () => showDocumentsFilterSheet(context),
                onUpload: () => context.push(AppRoutes.documentUpload),
              ),
              DocumentFilterChipsRow(
                chips: chips,
                onRemove: (field, {type}) =>
                    _removeFacet(ref, field, type: type),
                onClearAll: ref.read(documentsFilterProvider.notifier).clearAll,
              ),
              Expanded(
                child: AppRefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 24.h),
                    child: documents.isEmpty
                        ? _EmptyState(
                            isFiltered: isFiltered,
                            onUpload: () =>
                                context.push(AppRoutes.documentUpload),
                            onClearFilters: ref
                                .read(documentsFilterProvider.notifier)
                                .clearAll,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final document in documents)
                                Padding(
                                  padding: EdgeInsets.only(bottom: 16.h),
                                  child: _DocumentCard(document: document),
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Drop one filter facet — the chip carries which, so removing the patient
  /// leaves the date range alone.
  void _removeFacet(
    WidgetRef ref,
    DocumentFilterField field, {
    DocumentType? type,
  }) {
    final controller = ref.read(documentsFilterProvider.notifier);
    switch (field) {
      case DocumentFilterField.type:
        if (type != null) controller.removeType(type);
      case DocumentFilterField.patient:
        controller.setPatient(null);
      case DocumentFilterField.dateRange:
        controller.clearDateRange();
      case DocumentFilterField.appointment:
        controller.setAppointment(null);
    }
  }

  /// Re-derives the list from `documentsStoreProvider`, which is the source of
  /// truth in this build.
  ///
  /// Deliberately does **not** invalidate the store: that would reset it to the
  /// seed and throw away everything the user uploaded. There is no network
  /// layer yet, so the gesture re-reads rather than re-fetches; when the
  /// repository lands this awaits its reload and nothing else changes.
  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(filteredDocumentsProvider);
    // Hold the spinner long enough for the pull to read as completing.
    await Future<void>.delayed(AppConstants.fadeIn);
  }
}

/// The count + Filter + Upload row under the tab header.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.shown,
    required this.total,
    required this.isFiltered,
    required this.onFilter,
    required this.onUpload,
  });

  final int shown;
  final int total;
  final bool isFiltered;
  final VoidCallback onFilter;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final label = isFiltered
        ? '$shown of $total documents'
        : total == 1
        ? '1 document'
        : '$total documents';

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My documents',
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  label,
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          AppButton(
            label: 'Filter',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            pill: true,
            semanticLabel: isFiltered
                ? 'Filter documents, filters active'
                : 'Filter documents',
            onPressed: onFilter,
          ),
          SizedBox(width: 8.w),
          AppButton(
            label: 'Upload',
            size: AppButtonSize.sm,
            pill: true,
            semanticLabel: 'Upload a document',
            onPressed: onUpload,
          ),
        ],
      ),
    );
  }
}

/// One card, with its linked appointment label resolved.
class _DocumentCard extends ConsumerWidget {
  const _DocumentCard({required this.document});

  final MedicalRecord document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentId = document.appointmentId;
    final linked = appointmentId == null
        ? null
        : ref.watch(linkableAppointmentByIdProvider(appointmentId));

    return RecordCard(
      record: document,
      linkedAppointmentLabel: linked?.label,
      onOpen: () => context.push(AppRoutes.documentPath(document.id)),
      onView: () => showStubbedToast(context, ref, 'Preview'),
      onDownload: () => showStubbedToast(context, ref, 'Download'),
    );
  }
}

/// Two different empties, because they need two different ways out: a fresh
/// account has nothing to show and should be pointed at Upload, while a
/// filtered-to-nothing list should be pointed at clearing the filters.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isFiltered,
    required this.onUpload,
    required this.onClearFilters,
  });

  final bool isFiltered;
  final VoidCallback onUpload;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (isFiltered) {
      return AppEmptyView(
        iconName: MedIcon.records,
        headline: 'No documents match these filters',
        body:
            'Widen the date range or clear the filters to see everything '
            'on the account.',
        actionLabel: 'Clear filters',
        onAction: onClearFilters,
        secondaryLabel: 'Upload a document',
        onSecondary: onUpload,
      );
    }
    return AppEmptyView(
      iconName: MedIcon.records,
      headline: 'No documents yet',
      body:
          'Keep lab reports, prescriptions, scans and invoices in one '
          'place so you have them at your next visit.',
      actionLabel: 'Upload a document',
      onAction: onUpload,
    );
  }
}
