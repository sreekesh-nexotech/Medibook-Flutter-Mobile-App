import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../components/legal_prose.dart';

/// Terms / Privacy Policy / User Guidelines (`/legal/:slug`) — CM-02, CM-52.
///
/// Reads [legalDocumentProvider], which returns **null for a slug that is not
/// in [AppRoutes.legalSlugs]** — a deep link to `/legal/refunds`, a typo, a
/// stale link in an old email. That case renders [AppNotFoundView] rather than
/// silently redirecting to Terms, because a user who asked for the refund
/// policy and got the terms of service has been told something false.
///
/// The body is the seed's hard-wrapped "markdownish" prose; [LegalProseParser]
/// turns it into headings, paragraphs and bullets with no markdown package (see
/// its doc comment for why the model's own line-based getter is not enough).
///
/// [slug] is normally taken from the path; the constructor parameter exists so
/// the router can pass it explicitly and so the screen is testable without a
/// router.
class LegalDocumentScreen extends ConsumerWidget {
  const LegalDocumentScreen({super.key, this.slug});

  /// Overrides the `:slug` path parameter.
  final String? slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedSlug =
        slug ?? GoRouterState.of(context).pathParameters['slug'] ?? '';
    final document = ref.watch(legalDocumentProvider(resolvedSlug));

    if (document == null) {
      return AppNotFoundView(
        headline: 'Document not found',
        body:
            'We do not have a policy at this address. Terms, Privacy Policy '
            'and User Guidelines are all in Help & Support.',
        attemptedPath: AppRoutes.legalPath(resolvedSlug),
        onGoHome: () => context.go(AppRoutes.home),
        onGoBack: context.canPop() ? () => context.pop() : null,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: document.title,
              onBack: () => _leave(context),
              backSemanticLabel: 'Back from ${document.title}',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.x5.w,
                  AppSpacing.x1.h,
                  AppSpacing.x5.w,
                  AppSpacing.x8.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LegalProseMeta(
                      version: document.version,
                      updated: AppDates.dayMonthYear(document.lastUpdated),
                    ),
                    SizedBox(height: AppSpacing.x3.h),
                    // The seed says so itself: this is readable, structurally
                    // complete placeholder prose, not counsel-approved copy.
                    // Presenting it as binding terms would be the same class of
                    // lie as a fake success toast.
                    AppStubBanner(
                      title: 'Draft copy',
                      body:
                          'This text is written for design review. The final '
                          'wording is supplied by the client before release.',
                    ),
                    SizedBox(height: AppSpacing.x4.h),
                    AppCard(
                      padding: EdgeInsets.all(AppSpacing.x5.w),
                      child: LegalProse.fromBody(document.bodyMarkdownish),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
