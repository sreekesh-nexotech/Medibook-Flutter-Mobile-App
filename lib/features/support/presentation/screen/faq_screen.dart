import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../components/faq_entry_tile.dart';
import '../controllers/faq_controller.dart';

/// Frequently asked questions (`/faq`) — CM-52.
///
/// Grouped by `faqCategoriesProvider` (Booking / Payments / Records /
/// Account), searchable across question, answer and category, with each entry
/// expandable. Every one of the four list states is here:
///
/// * **loading** — [AppSkeletonList] on first mount;
/// * **error** — [AppErrorView] with a retry that re-runs the load;
/// * **empty** — a search that matched nothing, with "Clear search" *and*
///   "Contact support" as the ways out (audit §3.2.2: an empty state must
///   offer an action);
/// * **content** — the grouped list, refreshable by pulling (audit §3.9.4).
class FaqScreen extends ConsumerStatefulWidget {
  const FaqScreen({super.key});

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    ref.read(faqControllerProvider.notifier).clearQuery();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(faqControllerProvider);
    final sections = ref.watch(faqSectionsProvider);
    final matches = ref.watch(faqMatchCountProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: 'FAQs',
              onBack: () => _leave(context),
              bottomGap: 10,
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.x5.w),
              child: AppTextField(
                controller: _search,
                hintText: 'Search questions and answers',
                iconName: MedIcon.search,
                semanticLabel: 'Search the FAQ',
                textInputAction: TextInputAction.search,
                onChanged: ref.read(faqControllerProvider.notifier).setQuery,
                suffix: state.hasQuery
                    ? AppIconButton(
                        icon: MedIcon.close,
                        size: 24,
                        hitAreaSize: 40,
                        semanticLabel: 'Clear search',
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
            ),
            if (state.hasQuery)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.x5.w,
                  AppSpacing.x3.h,
                  AppSpacing.x5.w,
                  0,
                ),
                child: Text(
                  matches == 1 ? '1 answer matched' : '$matches answers matched',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            Expanded(child: _body(state, sections)),
          ],
        ),
      ),
    );
  }

  Widget _body(FaqState state, List<FaqSection> sections) {
    if (state.isLoading) {
      return SingleChildScrollView(
        child: AppSkeletonList(
          count: 5,
          tile: true,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.x5.w,
            AppSpacing.x4.h,
            AppSpacing.x5.w,
            AppSpacing.x6.h,
          ),
        ),
      );
    }

    if (state.failure != null && sections.isEmpty) {
      return AppErrorView(
        failure: state.failure!,
        headline: 'We could not load the FAQ',
        onRetry: () => ref.read(faqControllerProvider.notifier).refresh(),
        secondaryLabel: 'Contact Support',
        onSecondary: () => context.push(AppRoutes.support),
      );
    }

    return AppRefreshIndicator(
      onRefresh: () => ref.read(faqControllerProvider.notifier).refresh(),
      child: sections.isEmpty
          ? _emptyState(state)
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x5.w,
                AppSpacing.x4.h,
                AppSpacing.x5.w,
                AppSpacing.x8.h,
              ),
              children: [
                if (state.failure != null) ...[
                  AppErrorBanner(
                    message: state.failure!.userMessage,
                    onTap: () =>
                        ref.read(faqControllerProvider.notifier).refresh(),
                  ),
                  SizedBox(height: AppSpacing.x4.h),
                ],
                for (final section in sections) ...[
                  _SectionHeader(
                    label: section.category,
                    count: section.entries.length,
                  ),
                  for (final entry in section.entries)
                    Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.x3.h),
                      child: FaqEntryTile(
                        entry: entry,
                        isExpanded: state.isExpanded(entry.question),
                        onToggle: () => ref
                            .read(faqControllerProvider.notifier)
                            .toggle(entry.question),
                      ),
                    ),
                  SizedBox(height: AppSpacing.x3.h),
                ],
                _StillStuckCard(onContact: () => context.push(AppRoutes.support)),
              ],
            ),
    );
  }

  /// Empty means "your search matched nothing" — the seed always has entries —
  /// so both actions lead somewhere useful.
  Widget _emptyState(FaqState state) {
    return ListView(
      children: [
        AppEmptyView(
          iconName: MedIcon.search,
          headline: 'No answers matched',
          body: state.hasQuery
              ? 'Nothing matched "${state.query.trim()}". Try a shorter phrase, '
                    'or ask us directly.'
              : 'There are no help articles yet. Our team can still answer you '
                    'directly.',
          actionLabel: state.hasQuery ? 'Clear Search' : 'Contact Support',
          onAction: state.hasQuery
              ? _clearSearch
              : () => context.push(AppRoutes.support),
          secondaryLabel: state.hasQuery ? 'Contact Support' : null,
          onSecondary: state.hasQuery
              ? () => context.push(AppRoutes.support)
              : null,
        ),
      ],
    );
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.support);
  }
}

/// A category heading with its match count.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.x3.h),
      child: Row(
        children: [
          Semantics(
            header: true,
            child: Text(
              label,
              style: AppText.poppins(
                size: AppFontSize.body,
                weight: AppText.bold,
                color: AppColors.textStrong,
              ),
            ),
          ),
          SizedBox(width: AppSpacing.x2.w),
          Text(
            '$count',
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// The tail of the list: the way out for a question the FAQ does not answer.
class _StillStuckCard extends StatelessWidget {
  const _StillStuckCard({required this.onContact});

  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return AppInlineEmpty(
      message: 'Still stuck? Our support team answers within one working day.',
      iconName: MedIcon.hospital,
      actionLabel: 'Contact Support',
      onAction: onContact,
    );
  }
}
