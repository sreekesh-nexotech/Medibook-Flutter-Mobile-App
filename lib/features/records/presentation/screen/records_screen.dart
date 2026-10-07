import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../common/attachments/presentation/components/attachment_upload_tile.dart';
import '../../application/providers/records_provider.dart';
import '../../application/states/documents_list_state.dart';
import '../../domain/entities/medical_document.dart';
import '../components/document_type_icon.dart';
import '../components/records_search_field.dart';
import '../../application/providers/documents_filter_controller.dart';
import 'documents_filter_sheet.dart';

/// Records tab (`/records`), laid out as the design's Records screen: the
/// title with the brand "Add" pill, the title search, the "Filters" chip with the Newest /
/// Oldest sort pills, the "Recent Records · N records" heading, and the
/// record cards.
///
/// The list is `GET /patient/documents` through the three-layer cache
/// ([documentsListProvider]); filters and sort become query parameters. All
/// the HIVE affordances render from the state: skeletons on a cold start,
/// "updating…" while a cached page revalidates, the amber bar for a stale
/// page, an offline note while showing the saved copy, and an error view
/// with retry when there is nothing to show.
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(documentsListProvider);
    final filters = ref.watch(documentsFilterProvider);
    final sort = ref.watch(documentsSortProvider);
    final isOnline = ref.watch(isOnlineProvider).valueOrNull ?? true;

    final isSearching = state.query.search != null;

    final heading = isSearching
        ? 'Search results'
        : filters.type?.pluralLabel ?? sort.heading;

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
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Records',
                        style: AppText.poppins(
                          size: AppFontSize.h2,
                          weight: AppText.bold,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ),
                    _AddPill(
                      onTap: () => context.push(AppRoutes.documentUpload),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
                child: const RecordsSearchField(),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
                child: Row(
                  children: [
                    _FilterChip(
                      activeCount: filters.activeCount,
                      onTap: () => showDocumentsFilterSheet(context),
                    ),
                    const Spacer(),
                    for (var i = 0; i < kDocumentSorts.length; i++) ...[
                      if (i > 0) SizedBox(width: 8.w),
                      _SortPill(
                        label: kDocumentSorts[i].label,
                        on: kDocumentSorts[i] == sort,
                        onTap: () =>
                            ref.read(documentsSortProvider.notifier).state =
                                kDocumentSorts[i],
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _ListBody(
                  state: state,
                  heading: heading,
                  isOnline: isOnline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The scrolling body with its four states.
class _ListBody extends ConsumerWidget {
  const _ListBody({
    required this.state,
    required this.heading,
    required this.isOnline,
  });

  final DocumentsListState state;
  final String heading;
  final bool isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(documentsListProvider.notifier);

    if (state.isLoading && !state.hasData) {
      return SingleChildScrollView(
        child: AppSkeletonList(
          count: 3,
          padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 20.h),
        ),
      );
    }

    if (state.failure != null && !state.hasData && !state.isLoading) {
      return AppErrorView(
        failure: state.failure!,
        headline: 'We could not load your records',
        onRetry: controller.retry,
        secondaryLabel: 'Add record',
        onSecondary: () => context.push(AppRoutes.documentUpload),
      );
    }

    final documents = state.items;
    final names = ref.watch(documentPersonNamesProvider);
    final chips = ref.watch(documentFilterChipsProvider);
    final cachedAt = state.cachedAt;
    final failure = state.failure;
    final showsOfflineNote = !isOnline && state.fromCache;
    // Offline with the saved list on screen, the app-wide bar already says
    // so; a red "you appear to be offline" here adds nothing.
    final showsFailure =
        state.hasData && !(showsOfflineNote && failure is NetworkFailure);

    return AppRefreshIndicator(
      onRefresh: controller.refresh,
      child: SingleChildScrollView(
        physics: appRefreshPhysics,
        padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 20.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Offline is said once, by the app-wide OfflineBar (offline
            // audit, 6 Oct); the stale line is for online use.
            if (!showsOfflineNote && state.isStale && cachedAt != null) ...[
              AppErrorBanner(
                message:
                    'Data from ${AppDates.relativeAgo(cachedAt)} • '
                    'Tap to refresh',
                onTap: controller.refresh,
              ),
              SizedBox(height: 12.h),
            ],
            if (failure != null && showsFailure) ...[
              AppErrorBanner(
                message: failure.userMessage,
                tone: AppBannerTone.danger,
                iconName: PhIcon.xCircle,
                onTap: controller.retry,
              ),
              SizedBox(height: 12.h),
            ],
            if (state.revalidating) ...[
              const _UpdatingRow(),
              SizedBox(height: 8.h),
            ],
            if (chips.isNotEmpty) ...[
              _ActiveChips(chips: chips),
              SizedBox(height: 12.h),
            ],
            Padding(
              padding: EdgeInsets.fromLTRB(0, 4.h, 0, 16.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      heading,
                      style: AppText.poppins(
                        size: AppFontSize.h3,
                        weight: AppText.bold,
                        color: AppColors.textStrong,
                      ),
                    ),
                  ),
                  Text(
                    state.total == 1 ? '1 record' : '${state.total} records',
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (documents.isEmpty)
              _EmptyState(
                isFiltered: state.query.hasFilters,
                search: state.query.search,
                onClearSearch: ref.read(documentsSearchProvider.notifier).clear,
                onClearFilters: ref
                    .read(documentsFilterProvider.notifier)
                    .clearAll,
                onAdd: () => context.push(AppRoutes.documentUpload),
              )
            else ...[
              for (var i = 0; i < documents.length; i++) ...[
                if (i > 0) SizedBox(height: 16.h),
                _RecordCard(
                  record: documents[i],
                  patientName: names[documents[i].personId] ?? 'Family member',
                  onOpen: () =>
                      context.push(AppRoutes.documentPath(documents[i].id)),
                ),
              ],
              if (state.hasNext) ...[
                SizedBox(height: 16.h),
                AppButton(
                  label: 'Load more',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.md,
                  pill: true,
                  fullWidth: true,
                  loading: state.isLoadingMore,
                  semanticLabel: 'Load more records',
                  onPressed: state.isLoadingMore ? null : controller.loadMore,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// The non-intrusive "updating…" line for a warm start.
class _UpdatingRow extends StatelessWidget {
  const _UpdatingRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppInlineLoader(size: 14),
        SizedBox(width: 8.w),
        Text(
          'Updating…',
          style: AppText.poppins(
            size: AppFontSize.xs,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// The removable filter chips above the list (CM-34).
class _ActiveChips extends ConsumerWidget {
  const _ActiveChips({required this.chips});

  final List<DocumentFilterChip> chips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(documentsFilterProvider.notifier);
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (final chip in chips)
          Semantics(
            button: true,
            label: 'Remove filter ${chip.field.label}: ${chip.label}',
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => switch (chip.field) {
                  DocumentFilterField.type => controller.clearType(),
                  DocumentFilterField.patient => controller.setPerson(null),
                  DocumentFilterField.dateRange => controller.clearDateRange(),
                  DocumentFilterField.appointment => controller.setAppointment(
                    null,
                  ),
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceTint,
                    borderRadius: AppRadii.pill,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // A visit chip names the doctor, day and hospital; it
                      // wraps rather than running off the screen.
                      Flexible(
                        child: Text(
                          '${chip.field.label}: ${chip.label}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            size: AppFontSize.xs,
                            weight: AppText.medium,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      AppIcon(PhIcon.x, size: 12, color: AppColors.brand),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The brand "Add" pill.
class _AddPill extends StatelessWidget {
  const _AddPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add a record',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: AppRadii.pill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(PhIcon.plus, size: 16, color: AppColors.textOnBrand),
                SizedBox(width: 8.w),
                Text(
                  'Add',
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    weight: AppText.semibold,
                    color: AppColors.textOnBrand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Filters" chip; brand with "Filters · n" once anything is active.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = activeCount > 0;
    final fg = on ? AppColors.textOnBrand : AppColors.textBody;
    return Semantics(
      button: true,
      label: on ? 'Filter records, $activeCount active' : 'Filter records',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 46.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            decoration: BoxDecoration(
              color: on ? AppColors.brand : AppColors.surface,
              borderRadius: AppRadii.pill,
              border: Border.all(
                color: on ? AppColors.brand : AppColors.border,
                width: 1.w,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(PhIcon.funnelSimple, size: 16, color: fg),
                SizedBox(width: 8.w),
                Text(
                  on ? 'Filters · $activeCount' : 'Filters',
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    weight: AppText.medium,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: 'Sort by $label',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 46.h,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColors.brand : AppColors.surface,
              borderRadius: AppRadii.pill,
              border: Border.all(
                color: on ? AppColors.brand : AppColors.border,
                width: 1.w,
              ),
            ),
            child: Text(
              label,
              style: AppText.poppins(
                size: AppFontSize.sm,
                weight: AppText.medium,
                color: on ? AppColors.textOnBrand : AppColors.textBody,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One record: the tinted folder tile beside the title, "patient · kind",
/// "date · size", then a hairline footer with the file name and "Open".
class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.patientName,
    required this.onOpen,
  });

  final MedicalDocument record;
  final String patientName;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final file = record.file;
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52.w,
                height: 64.h,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint,
                  borderRadius: AppRadii.sm,
                ),
                // The document's own type, as on its detail screen and in the
                // filters — not one folder for every kind.
                child: AppIcon(
                  DocumentTypeIcon.of(record.docType),
                  size: 24,
                  color: AppColors.brand,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.title,
                      style: AppText.poppins(
                        size: AppFontSize.body,
                        weight: AppText.semibold,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '$patientName · ${record.docType.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(
                        size: AppFontSize.sm,
                        color: AppColors.textBody,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      '${AppDates.dayMonthYear(record.documentDate)} · '
                      '${formatFileSize(file.sizeBytes)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          Container(
            margin: EdgeInsets.only(top: 16.h),
            padding: EdgeInsets.only(top: 12.h),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle, width: 1.h),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    file.originalName.isEmpty
                        ? file.extension.toUpperCase()
                        : file.originalName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(
                      size: AppFontSize.xs,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                AppButton(
                  label: 'Open',
                  pill: true,
                  expandHitArea: false,
                  semanticLabel: 'Open ${record.title}',
                  onPressed: onOpen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "No records here" / "No records yet".
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isFiltered,
    required this.search,
    required this.onClearSearch,
    required this.onClearFilters,
    required this.onAdd,
  });

  final bool isFiltered;

  /// The title being searched for, or null when there is no search.
  final String? search;
  final VoidCallback onClearSearch;
  final VoidCallback onClearFilters;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 50.h),
      child: Column(
        children: [
          Container(
            width: 64.r,
            height: 64.r,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.surfaceTint,
              shape: BoxShape.circle,
            ),
            child: AppIcon(PhIcon.folder, size: 30, color: AppColors.brand),
          ),
          SizedBox(height: 12.h),
          Text(
            isFiltered ? 'No records here' : 'No records yet',
            textAlign: TextAlign.center,
            style: AppText.poppins(
              size: AppFontSize.body,
              weight: AppText.semibold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 12.h),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 250.w),
            child: Text(
              search != null
                  ? 'No record has “$search” in its title. Check the '
                        'spelling or clear the search.'
                  : isFiltered
                  ? 'Nothing matches this filter yet. Add a paper report or '
                        'clear the filters.'
                  : 'Upload a lab report, prescription or scan and it is '
                        'here whenever you need it.',
              textAlign: TextAlign.center,
              style: AppText.poppins(
                size: AppFontSize.sm,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFiltered) ...[
                AppButton(
                  label: search != null ? 'Clear search' : 'Clear filters',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  pill: true,
                  onPressed: search != null ? onClearSearch : onClearFilters,
                ),
                SizedBox(width: 12.w),
              ],
              AppButton(
                label: 'Add record',
                size: AppButtonSize.sm,
                pill: true,
                onPressed: onAdd,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
