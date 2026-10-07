import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../common/cached/presentation/components/cached_status_bar.dart';
import '../../application/providers/support_provider.dart';
import '../../domain/entities/support_ticket.dart';

/// My requests (`/support/tickets`) — `GET /patient/support/tickets` (§13).
///
/// Newest first, each row showing the ticket number the user quotes, the
/// subject, the status and when it last moved. Tapping opens the thread.
class SupportTicketsScreen extends ConsumerWidget {
  const SupportTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supportTicketsProvider);
    Future<void> refresh() =>
        ref.read(supportTicketsProvider.notifier).refresh(force: true);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: 'My Requests',
              onBack: () => _leave(context),
              backSemanticLabel: 'Back to help and support',
            ),
            Expanded(
              child: state.isLoading
                  ? SingleChildScrollView(
                      child: AppSkeletonList(
                        count: 3,
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.x5.w,
                          AppSpacing.x4.h,
                          AppSpacing.x5.w,
                          AppSpacing.x6.h,
                        ),
                      ),
                    )
                  : state.isError
                  ? AppErrorView(
                      failure: state.failure!,
                      headline: 'We could not load your requests',
                      onRetry: refresh,
                    )
                  : AppRefreshIndicator(
                      onRefresh: refresh,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.x5.w,
                          AppSpacing.x4.h,
                          AppSpacing.x5.w,
                          AppSpacing.x8.h,
                        ),
                        children: [
                          CachedStatusBar(state: state, onRefresh: refresh),
                          if (state.value!.isEmpty)
                            AppEmptyView(
                              iconName: PhIcon.folder,
                              headline: 'No requests yet',
                              body:
                                  'When you raise a request, it appears here '
                                  'with its ticket number and every reply.',
                              actionLabel: 'Raise a Request',
                              onAction: () => _leave(context),
                            )
                          else ...[
                            for (final ticket in state.value!)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: AppSpacing.x3.h,
                                ),
                                child: _TicketCard(
                                  ticket: ticket,
                                  onOpen: () => context.push(
                                    AppRoutes.supportTicketPath(ticket.id),
                                  ),
                                ),
                              ),
                            SizedBox(height: AppSpacing.x2.h),
                            AppButton(
                              label: 'Raise a New Request',
                              variant: AppButtonVariant.secondary,
                              fullWidth: true,
                              leadingIcon: PhIcon.plus,
                              onPressed: () => _leave(context),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
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

/// One request row: number, subject, status pill, last activity.
class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onOpen});

  final SupportTicket ticket;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.ticketNo,
                  style: AppText.inter(
                    size: AppFontSize.xs,
                    weight: AppText.medium,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.x2.w),
              TicketStatusBadge(status: ticket.status),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            ticket.subject,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.poppins(
              size: AppFontSize.body,
              weight: AppText.semibold,
              color: AppColors.textStrong,
              height: 1.4,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${ticket.category.label} · updated '
            '${AppDates.relativeAgo(ticket.updatedAt.toLocal())}',
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

/// The status pill shared by the list and the detail.
class TicketStatusBadge extends StatelessWidget {
  const TicketStatusBadge({super.key, required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: status.label,
      tone: switch (status) {
        TicketStatus.open => AppBadgeTone.brand,
        TicketStatus.inProgress => AppBadgeTone.brand,
        TicketStatus.waitingOnRequester => AppBadgeTone.warning,
        TicketStatus.resolved => AppBadgeTone.success,
        TicketStatus.closed => AppBadgeTone.neutral,
      },
    );
  }
}
