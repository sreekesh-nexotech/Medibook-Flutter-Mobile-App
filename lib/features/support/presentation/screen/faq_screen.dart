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
import '../../../common/cached/application/states/cached_state.dart';
import '../../../common/cached/presentation/components/cached_status_bar.dart';
import '../../application/providers/support_provider.dart';
import '../../domain/entities/faq.dart';
import '../components/faq_entry_tile.dart';
import '../../application/providers/faq_controller.dart';

/// Frequently asked questions (`/faq`) — CM-52.
///
/// Content is `GET /patient/faqs` (§3.3) through the three-layer cache, so a
/// returning user sees the saved copy instantly and an offline one sees it at
/// all. Grouped by the server's categories, searchable across question,
/// answer and category, with each entry expandable. Every list state is here:
///
/// * **loading** — [AppSkeletonList] on a cold start;
/// * **error** — [AppErrorView] with a retry when there is nothing cached;
/// * **stale / offline / updating** — [CachedStatusBar] over the content;
/// * **empty** — a search that matched nothing, with "Clear search" *and*
///   "Contact support" as the ways out;
/// * **content** — the grouped list, refreshable by pulling.
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

  Future<void> _refresh() =>
      ref.read(supportFaqsProvider.notifier).refresh(force: true);

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(faqControllerProvider);
    final content = ref.watch(supportFaqsProvider);
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
                suffix: search.hasQuery
                    ? AppIconButton(
                        icon: PhIcon.x,
                        size: 24,
                        hitAreaSize: 40,
                        semanticLabel: 'Clear search',
                        onPressed: _clearSearch,
                      )
                    : null,
              ),
            ),
            if (search.hasQuery && content.hasValue)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.x5.w,
                  AppSpacing.x3.h,
                  AppSpacing.x5.w,
                  0,
                ),
                child: Text(
                  matches == 1
                      ? '1 answer matched'
                      : '$matches answers matched',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            Expanded(child: _body(search, content, sections)),
          ],
        ),
      ),
    );
  }

  Widget _body(
    FaqState search,
    CachedState<List<FaqCategory>> content,
    List<FaqSection> sections,
  ) {
    if (content.isLoading) {
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

    if (content.isError) {
      return AppErrorView(
        failure: content.failure!,
        headline: 'We could not load the FAQ',
        onRetry: _refresh,
        secondaryLabel: 'Contact Support',
        onSecondary: () => context.push(AppRoutes.support),
      );
    }

    return AppRefreshIndicator(
      onRefresh: _refresh,
      child: sections.isEmpty
          ? _emptyState(search, content)
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.x5.w,
                AppSpacing.x4.h,
                AppSpacing.x5.w,
                AppSpacing.x8.h,
              ),
              children: [
                CachedStatusBar(state: content, onRefresh: _refresh),
                for (final section in sections) ...[
                  _SectionHeader(
                    label: section.title,
                    count: section.entries.length,
                  ),
                  for (final entry in section.entries)
                    Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.x3.h),
                      child: FaqEntryTile(
                        entry: entry,
                        isExpanded: search.isExpanded(entry.id),
                        onToggle: () => ref
                            .read(faqControllerProvider.notifier)
                            .toggle(entry.id),
                      ),
                    ),
                  SizedBox(height: AppSpacing.x3.h),
                ],
                _StillStuckCard(
                  onContact: () => context.push(AppRoutes.support),
                ),
              ],
            ),
    );
  }

  /// Empty means "your search matched nothing", or the server has published
  /// no articles yet — both offer a way to a person.
  Widget _emptyState(FaqState search, CachedState<List<FaqCategory>> content) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.x5.w),
      children: [
        SizedBox(height: AppSpacing.x4.h),
        CachedStatusBar(state: content, onRefresh: _refresh),
        AppEmptyView(
          iconName: PhIcon.magnifyingGlass,
          headline: search.hasQuery ? 'No answers matched' : 'No articles yet',
          body: search.hasQuery
              ? 'Nothing matched "${search.query.trim()}". Try a shorter '
                    'phrase, or ask us directly.'
              : 'There are no help articles published yet. Our team can '
                    'still answer you directly.',
          actionLabel: search.hasQuery ? 'Clear Search' : 'Contact Support',
          onAction: search.hasQuery
              ? _clearSearch
              : () => context.push(AppRoutes.support),
          secondaryLabel: search.hasQuery ? 'Contact Support' : null,
          onSecondary: search.hasQuery
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
      message: 'Still stuck? Raise a request and our support team will reply.',
      iconName: PhIcon.firstAid,
      actionLabel: 'Contact Support',
      onAction: onContact,
    );
  }
}
