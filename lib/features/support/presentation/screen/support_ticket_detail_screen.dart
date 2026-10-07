import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/error_view.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../../core/widgets/states/app_not_found_view.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../common/cached/presentation/components/cached_status_bar.dart';
import '../../application/providers/support_provider.dart';
import '../../domain/entities/support_ticket.dart';
import '../../../../core/utils/external_url.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../common/attachments/application/providers/attachments_provider.dart';
import '../components/ticket_attachments_field.dart';
import '../../application/providers/ticket_attachments_controller.dart';
import 'support_tickets_screen.dart';

/// One request and its thread (`/support/tickets/:id`) —
/// `GET /patient/support/tickets/{id}` and `POST …/messages` (§13).
///
/// The original description opens the thread; replies from the team and from
/// the user follow in time order. The reply box is disabled on a `closed`
/// ticket (the server answers `409 STATE_CONFLICT`), and says so.
class SupportTicketDetailScreen extends ConsumerStatefulWidget {
  const SupportTicketDetailScreen({super.key, this.id});

  /// Overrides the `:id` path parameter.
  final String? id;

  @override
  ConsumerState<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState
    extends ConsumerState<SupportTicketDetailScreen> {
  final TextEditingController _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send(String id) async {
    final form = ticketReplyForm(id);
    final files = ref.read(ticketAttachmentsProvider(form));
    final toast = ref.read(toastControllerProvider.notifier);
    if (files.isBusy) {
      toast.show('Wait for the file to finish uploading');
      return;
    }
    if (files.hasProblem) {
      toast.show('A file could not be attached — remove it or try again');
      return;
    }
    final failure = await ref
        .read(ticketReplyControllerProvider(id).notifier)
        .send(_reply.text, attachmentFileIds: files.readyFileIds);
    if (!mounted) return;
    if (failure == null) {
      _reply.clear();
      handOverTicketAttachments(ref, form);
      toast.show('Reply sent');
      return;
    }
    toast.show(
      failure is ConflictFailure
          ? 'This request is closed. Raise a new one if you need more help.'
          : failure.userMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id ?? GoRouterState.of(context).pathParameters['id'];
    if (id == null || id.isEmpty) {
      return AppNotFoundView(
        headline: 'Request not found',
        body: 'This link does not point at one of your requests.',
        attemptedPath: AppRoutes.supportTickets,
        onGoHome: () => context.go(AppRoutes.home),
        onGoBack: context.canPop() ? () => context.pop() : null,
      );
    }

    final state = ref.watch(supportTicketDetailProvider(id));
    final reply = ref.watch(ticketReplyControllerProvider(id));
    Future<void> refresh() =>
        ref.read(supportTicketDetailProvider(id).notifier).refresh(force: true);

    if (state.isError && state.failure is NotFoundFailure) {
      return AppNotFoundView(
        headline: 'Request not found',
        body: 'This request is not on your account, or the link is old.',
        attemptedPath: AppRoutes.supportTicketPath(id),
        onGoHome: () => context.go(AppRoutes.home),
        onGoBack: context.canPop() ? () => context.pop() : null,
      );
    }

    final ticket = state.value;
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInnerHeader(
              title: ticket?.ticketNo ?? 'Request',
              onBack: () => _leave(context),
              backSemanticLabel: 'Back to my requests',
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
                      headline: 'We could not load this request',
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
                          _TicketHeader(ticket: ticket!),
                          SizedBox(height: AppSpacing.x4.h),
                          _MessageBubble(
                            authorName: 'You',
                            body: ticket.description,
                            occurredAt: ticket.createdAt,
                            isMine: true,
                          ),
                          for (final message in ticket.messages)
                            _MessageBubble(
                              authorName: message.isMine
                                  ? 'You'
                                  : message.authorName.isEmpty
                                  ? 'Support team'
                                  : message.authorName,
                              body: message.body,
                              occurredAt: message.occurredAt,
                              isMine: message.isMine,
                              attachmentFileIds: message.attachmentFileIds,
                            ),
                        ],
                      ),
                    ),
            ),
            if (ticket != null)
              _ReplyBar(
                controller: _reply,
                form: ticketReplyForm(id),
                enabled: ticket.canReply,
                isSending: reply.isBusy,
                onSend: () => _send(id),
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
    context.go(AppRoutes.supportTickets);
  }
}

/// Subject, category, priority and status.
class _TicketHeader extends StatelessWidget {
  const _TicketHeader({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.subject,
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    weight: AppText.bold,
                    color: AppColors.textStrong,
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.x2.w),
              TicketStatusBadge(status: ticket.status),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            '${ticket.category.label} · ${ticket.priority.label} priority · '
            'raised ${AppDates.dayMonthYear(ticket.createdAt.toLocal())}',
            style: AppText.poppins(
              size: AppFontSize.xs,
              height: 1.45,
              color: AppColors.textMuted,
            ),
          ),
          if (ticket.status == TicketStatus.waitingOnRequester) ...[
            SizedBox(height: AppSpacing.x3.h),
            const AppErrorBanner(
              message: 'The team is waiting for your reply.',
              tone: AppBannerTone.warning,
            ),
          ],
        ],
      ),
    );
  }
}

/// One message in the thread. Mine on the right in the brand tint; the
/// team's on the left.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.authorName,
    required this.body,
    required this.occurredAt,
    required this.isMine,
    this.attachmentFileIds = const <String>[],
  });

  final String authorName;
  final String body;
  final DateTime occurredAt;
  final bool isMine;

  /// The message's files, each opened with a fresh link (§11.4).
  final List<String> attachmentFileIds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.x3.h),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 0.82.sw),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.x3.w),
            decoration: BoxDecoration(
              color: isMine ? AppColors.surfaceTint : AppColors.surface,
              borderRadius: AppRadii.md,
              border: Border.all(color: AppColors.borderSubtle, width: 1.w),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  authorName,
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    weight: AppText.semibold,
                    color: isMine ? AppColors.brand : AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 4.h),
                SelectableText(
                  body,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    height: 1.5,
                    color: AppColors.textBody,
                  ),
                ),
                for (var i = 0; i < attachmentFileIds.length; i++)
                  _AttachmentLink(
                    fileId: attachmentFileIds[i],
                    label: attachmentFileIds.length == 1
                        ? 'Attachment'
                        : 'Attachment ${i + 1}',
                  ),
                SizedBox(height: 4.h),
                Text(
                  AppDates.dayAndTime(occurredAt.toLocal()),
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
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

/// One file on a message: asks the server for a fresh link and hands it to
/// the browser or a viewer, like a record's Open file.
class _AttachmentLink extends ConsumerWidget {
  const _AttachmentLink({required this.fileId, required this.label});

  final String fileId;
  final String label;

  Future<void> _open(WidgetRef ref) async {
    final toast = ref.read(toastControllerProvider.notifier);
    try {
      final signed = await ref.read(fileUrlResolverProvider).resolve(fileId);
      if (!await openExternalUrl(signed.url)) {
        toast.show('No app on this device could open the file');
      }
    } catch (error, stackTrace) {
      toast.show(error.asFailure(stackTrace).userMessage);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: AppButton(
        label: label,
        variant: AppButtonVariant.ghost,
        size: AppButtonSize.sm,
        leadingIcon: MedIcon.download,
        semanticLabel: '$label — opens in your browser',
        onPressed: () => _open(ref),
      ),
    );
  }
}

/// The reply composer, pinned under the thread.
class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.controller,
    required this.form,
    required this.enabled,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;

  /// The reply box's attachment slots ([ticketReplyForm]).
  final String form;
  final bool enabled;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.x5.w,
        AppSpacing.x3.h,
        AppSpacing.x5.w,
        AppSpacing.x3.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.h),
        ),
      ),
      child: enabled
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pinned under the thread: the files scroll on their own so
                // five of them cannot push the text box off the screen.
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 240.h),
                  child: SingleChildScrollView(
                    child: TicketAttachmentsField(
                      form: form,
                      enabled: !isSending,
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.x2.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: controller,
                        hintText: 'Write a reply',
                        maxLines: 3,
                        maxLength: 5000,
                        textCapitalization: TextCapitalization.sentences,
                        semanticLabel: 'Reply to the support team',
                        enabled: !isSending,
                      ),
                    ),
                    SizedBox(width: AppSpacing.x2.w),
                    Consumer(
                      builder: (context, ref, _) {
                        final waiting = ref.watch(
                          ticketAttachmentsProvider(
                            form,
                          ).select((files) => files.isBusy),
                        );
                        return AppButton(
                          label: 'Send',
                          size: AppButtonSize.md,
                          loading: isSending,
                          disabled: waiting,
                          semanticLabel: waiting
                              ? 'Send — waiting for the file to finish uploading'
                              : null,
                          onPressed: onSend,
                        );
                      },
                    ),
                  ],
                ),
              ],
            )
          : Text(
              'This request is closed. Raise a new request if you need more '
              'help.',
              textAlign: TextAlign.center,
              style: AppText.poppins(
                size: AppFontSize.xs,
                height: 1.45,
                color: AppColors.textMuted,
              ),
            ),
    );
  }
}
