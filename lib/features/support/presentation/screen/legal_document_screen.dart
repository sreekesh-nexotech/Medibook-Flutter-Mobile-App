import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/route_arrival.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../common/cached/application/states/cached_state.dart';
import '../../../common/cached/presentation/components/cached_status_bar.dart';
import '../../application/providers/support_provider.dart';
import '../../domain/entities/legal_document.dart';
import '../components/legal_prose.dart';

/// Terms / Privacy Policy / Community Guidelines (`/legal/:slug`) — CM-02,
/// CM-52.
///
/// Reads `GET /patient/legal/{slug}` (§3.2) through the cache, via
/// [legalDocumentProvider]. A slug outside [AppRoutes.legalSlugs], or a slug
/// the server has nothing published for (`404 NOT_FOUND`), renders
/// [AppNotFoundView] rather than silently redirecting to Terms — a user who
/// asked for the refund policy and got the terms has been told something
/// false.
///
/// `body_md` is Markdown; [LegalProseParser] renders its headings, paragraphs,
/// bullets and bold with no markdown package.
///
/// [slug] is normally taken from the path; the constructor parameter exists so
/// the router can pass it explicitly and so the screen is testable without a
/// router. `?from=onboarding|signup` labels the footer button "Back to sign
/// up"; anything else gets a plain "Back".
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({super.key, this.slug, this.from});

  /// Overrides the `:slug` path parameter.
  final String? slug;

  /// Overrides the `from` query parameter.
  final String? from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeState = GoRouterState.of(context);
    final resolvedSlug = slug ?? routeState.pathParameters['slug'] ?? '';
    final resolvedFrom = from ?? routeState.uri.queryParameters['from'];
    final fromSignUp =
        resolvedFrom == AppRoutes.legalFromOnboarding ||
        resolvedFrom == AppRoutes.legalFromSignup;

    if (!AppRoutes.legalSlugs.contains(resolvedSlug)) {
      return _notFound(context, resolvedSlug);
    }

    final state = ref.watch(legalDocumentProvider(resolvedSlug));
    if (state.isError && state.failure is NotFoundFailure) {
      return _notFound(context, resolvedSlug);
    }

    return RouteArrival(
      onArrive: () => ref.invalidate(legalDocumentProvider(resolvedSlug)),
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SafeArea(
              bottom: false,
              child: _Header(
                title: state.value?.title ?? _fallbackTitle(resolvedSlug),
                onBack: () => _leave(context),
              ),
            ),
            Expanded(
              child: _body(
                context,
                state,
                onRetry: () => ref
                    .read(legalDocumentProvider(resolvedSlug).notifier)
                    .refresh(force: true),
              ),
            ),
            _Footer(
              child: AppButton(
                label: fromSignUp ? 'Back to sign up' : 'Back',
                pill: true,
                fullWidth: true,
                onPressed: () => _leave(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    CachedState<LegalDocument> state, {
    required VoidCallback onRetry,
  }) {
    if (state.isLoading) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.x6.w,
          AppSpacing.x5.h,
          AppSpacing.x6.w,
          28.h,
        ),
        child: const AppSkeletonCard(
          hasAvatar: false,
          lines: 8,
          hasFooter: false,
        ),
      );
    }
    if (state.isError) {
      return AppErrorView(
        failure: state.failure!,
        headline: 'We could not load this document',
        onRetry: onRetry,
      );
    }
    final document = state.value!;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x6.w,
        AppSpacing.x5.h,
        AppSpacing.x6.w,
        28.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CachedStatusBar(state: state, onRefresh: onRetry),
          Text(
            document.publishedAt == null
                ? 'Version ${document.version}'
                : 'Version ${document.version} · published '
                      '${AppDates.dayMonthLongYear(document.publishedAt!.toLocal())}',
            style: AppText.poppins(
              size: AppFontSize.xs,
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: AppSpacing.x5.h),
          LegalProse.fromBody(document.bodyMd),
        ],
      ),
    );
  }

  Widget _notFound(BuildContext context, String attempted) => AppNotFoundView(
    headline: 'Document not found',
    body:
        'We do not have a policy at this address. Terms, Privacy Policy '
        'and Community Guidelines are all in Help & Support.',
    attemptedPath: AppRoutes.legalPath(attempted),
    onGoHome: () => context.go(AppRoutes.home),
    onGoBack: context.canPop() ? () => context.pop() : null,
  );

  static String _fallbackTitle(String slug) => switch (slug) {
    AppRoutes.legalTerms => 'Terms of Service',
    AppRoutes.legalPrivacy => 'Privacy Policy',
    AppRoutes.legalGuidelines => 'Community Guidelines',
    _ => 'Policy',
  };

  /// Back goes where the user came from; a deep link that opened straight onto
  /// a policy has nothing to pop, so it falls back to Help & Support.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.support);
  }
}

/// Back button + left-aligned title over a hairline. Design: `padding 54px
/// 18px 10px` on the 844 frame, i.e. 10px under the status bar.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 10.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1.h),
        ),
      ),
      child: Row(
        children: [
          AppIconButton(
            icon: MedIcon.back,
            size: 46,
            semanticLabel: 'Back from $title',
            onPressed: onBack,
          ),
          SizedBox(width: AppSpacing.x1.w),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.poppins(
                  size: AppFontSize.h3,
                  weight: AppText.bold,
                  color: AppColors.textStrong,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sticky footer: `padding 12px 20px 20px`, hairline on top.
class _Footer extends StatelessWidget {
  const _Footer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.h),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          child: child,
        ),
      ),
    );
  }
}
