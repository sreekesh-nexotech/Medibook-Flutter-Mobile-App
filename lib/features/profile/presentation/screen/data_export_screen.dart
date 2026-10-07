import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/external_url.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../common/cached/presentation/components/cached_status_bar.dart';
import '../../application/providers/data_export_provider.dart';
import '../../domain/entities/account.dart';

/// "Download my data" (`/profile/data-export`) — the patient's personal-data
/// export requests (§5.7).
///
/// `GET /patient/me/data-exports` lists them; "Request my data" posts a new
/// one (refused while another is being prepared); a finished request offers
/// "Download", which fetches the ten-minute signed link and hands it to the
/// browser. The file is prepared by Medibook, not instantly — the screen says
/// so, and the `dsr.export_ready` notification lands here.
class DataExportScreen extends ConsumerWidget {
  const DataExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dataExportsProvider);
    final open = ref.watch(openDataExportProvider);
    final actions = ref.watch(dataExportControllerProvider);
    Future<void> refresh() =>
        ref.read(dataExportsProvider.notifier).refresh(force: true);

    final requests = state.value ?? const <DataExportRequest>[];

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: 'Download My Data',
              onBack: () => _leave(context),
              backSemanticLabel: 'Back to profile',
            ),
            Expanded(
              child: state.isLoading
                  ? SingleChildScrollView(
                      child: AppSkeletonList(
                        count: 2,
                        tile: true,
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
                      headline: 'We could not load your data requests',
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
                          _IntroCard(
                            open: open,
                            isRequesting: actions.isRequesting,
                            disabled: actions.isBusy,
                            onRequest: () => _request(context, ref),
                          ),
                          SizedBox(height: AppSpacing.x5.h),
                          if (requests.isEmpty)
                            const AppInlineEmpty(
                              message:
                                  'You have not asked for a copy of your '
                                  'data yet.',
                            )
                          else ...[
                            Text(
                              'Your requests',
                              style: AppText.poppins(
                                size: AppFontSize.base,
                                weight: AppText.semibold,
                                color: AppColors.textStrong,
                              ),
                            ),
                            SizedBox(height: AppSpacing.x3.h),
                            for (final request in requests)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: AppSpacing.x3.h,
                                ),
                                child: _RequestCard(
                                  request: request,
                                  isLinking: actions.linkingId == request.id,
                                  disabled: actions.isBusy,
                                  onDownload: () =>
                                      _download(context, ref, request),
                                ),
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

  Future<void> _request(BuildContext context, WidgetRef ref) async {
    final failure = await ref
        .read(dataExportControllerProvider.notifier)
        .request();
    if (!context.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    if (failure == null) {
      toast.show('Request received — we will notify you when it is ready');
      return;
    }
    if (failure.apiCode == ApiErrorCodes.stateConflict) {
      // Another device asked first: show that request instead of an error.
      await ref.read(dataExportsProvider.notifier).refresh(force: true);
      toast.show('A copy of your data is already being prepared');
      return;
    }
    toast.show(failure.userMessage);
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    DataExportRequest request,
  ) async {
    final link = await ref
        .read(dataExportControllerProvider.notifier)
        .link(request.id);
    if (!context.mounted) return;
    final toast = ref.read(toastControllerProvider.notifier);
    if (link == null) {
      final failure = ref.read(dataExportControllerProvider).failure;
      toast.show(
        failure is NotFoundFailure
            ? 'This file is no longer available. Request a new copy.'
            : failure?.userMessage ?? 'Could not get the download link',
      );
      return;
    }
    final launched = await openExternalUrl(link.url);
    if (!launched && context.mounted) {
      toast.show('No app on this device could open the download');
    }
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.profile);
  }
}

/// What an export is, what it leaves out, and the request button.
class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.open,
    required this.isRequesting,
    required this.disabled,
    required this.onRequest,
  });

  /// The request still being prepared, or null.
  final DataExportRequest? open;
  final bool isRequesting;
  final bool disabled;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final pending = open;
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A copy of your Medibook data',
            style: AppText.poppins(
              size: AppFontSize.body,
              weight: AppText.bold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            'Ask for a file with your profile, family members, appointments '
            'and payments. We prepare it and notify you when it is ready; the '
            'file can then be downloaded for 7 days. Medical documents and '
            'insurance files are not part of it — download those from '
            'Records.',
            style: AppText.poppins(
              size: AppFontSize.xs,
              height: 1.55,
              color: AppColors.textBody,
            ),
          ),
          SizedBox(height: AppSpacing.x4.h),
          if (pending != null)
            Text(
              'Request ${pending.requestNo} is ${pending.status.label.toLowerCase()}. '
              'You can ask again once it is finished.',
              style: AppText.poppins(
                size: AppFontSize.xs,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            )
          else
            AppButton(
              label: 'Request My Data',
              fullWidth: true,
              leadingIcon: PhIcon.downloadSimple,
              loading: isRequesting,
              disabled: disabled && !isRequesting,
              onPressed: onRequest,
            ),
        ],
      ),
    );
  }
}

/// One request: its number, where it stands, and Download once it is ready.
class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.isLinking,
    required this.disabled,
    required this.onDownload,
  });

  final DataExportRequest request;
  final bool isLinking;
  final bool disabled;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final completed = request.completedAt;
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.requestNo,
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.x2.w),
              AppBadge(label: request.status.label, tone: _tone(request)),
            ],
          ),
          SizedBox(height: AppSpacing.x2.h),
          Text(
            [
              'Requested '
                  '${AppDates.dayMonthYear(request.requestedAt.toLocal())}',
              if (completed != null)
                'ready ${AppDates.dayMonthYear(completed.toLocal())}',
            ].join(' · '),
            style: AppText.poppins(
              size: AppFontSize.xs,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
          if (request.isReady) ...[
            SizedBox(height: AppSpacing.x3.h),
            Align(
              alignment: Alignment.centerLeft,
              child: AppButton(
                label: 'Download',
                variant: AppButtonVariant.soft,
                size: AppButtonSize.sm,
                leadingIcon: PhIcon.downloadSimple,
                loading: isLinking,
                disabled: disabled && !isLinking,
                semanticLabel:
                    'Download the data file for ${request.requestNo}',
                onPressed: onDownload,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static AppBadgeTone _tone(DataExportRequest request) =>
      switch (request.status) {
        DataExportStatus.completed => AppBadgeTone.success,
        DataExportStatus.rejected => AppBadgeTone.danger,
        DataExportStatus.noData ||
        DataExportStatus.withdrawn => AppBadgeTone.neutral,
        DataExportStatus.requested ||
        DataExportStatus.verifying ||
        DataExportStatus.processing => AppBadgeTone.brand,
      };
}
