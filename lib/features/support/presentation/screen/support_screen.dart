import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/external_url.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/route_arrival.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_select.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_unsaved_changes_guard.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../application/providers/app_config_provider.dart';
import '../../application/providers/faq_controller.dart';
import '../../application/providers/support_provider.dart';
import '../../application/states/ticket_form_state.dart';
import '../../domain/entities/support_ticket.dart';
import '../components/support_tiles.dart';
import '../components/ticket_attachments_field.dart';
import '../../application/providers/ticket_attachments_controller.dart';

/// Help & Support (`/support`, and `/help` — the same screen) — CM-52.
///
/// The hub: self-serve links, the contact channel the backend publishes
/// (`app-config.support_contacts`, §3.1), the emergency line, a real
/// "raise a request" form (`POST /patient/support/tickets`, §13) and the
/// user's open requests, plus the three policy documents.
///
/// ## Honest controls
///
/// * **Copy** genuinely copies to the clipboard, so the toast it shows is
///   true. There is still no dialler in this build, so the support phone
///   number is shown and copyable rather than behind a "Call" button.
/// * **Send request** creates a ticket on the server and opens it. A server
///   `VALIDATION_ERROR` lands on the matching field; anything else is shown
///   as a toast with the form left intact.
/// * The emergency row points at the ambulance directory and names 108.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  /// The national emergency number — real, and deliberately not a button.
  static const String _emergencyNumber = '108';

  late final TextEditingController _subject;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final form = ref.read(ticketFormControllerProvider);
    _subject = TextEditingController(text: form.subject);
    _description = TextEditingController(text: form.description);
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _copy(String value, String what) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ref.read(toastControllerProvider.notifier).show('$what copied');
  }

  /// Hands a `tel:` / `mailto:` link to the OS; says so when nothing can
  /// take it (no dialler on a tablet, no mail app).
  Future<void> _open(String url) async {
    if (await openExternalUrl(url)) return;
    if (!mounted) return;
    ref
        .read(toastControllerProvider.notifier)
        .show('No app on this phone can open that. Use Copy instead.');
  }

  Future<void> _submit() async {
    final files = ref.read(ticketAttachmentsProvider(newTicketForm));
    final toast = ref.read(toastControllerProvider.notifier);
    // The button already waits while a file uploads; this covers a tap that
    // lands first, and a file that failed and was never removed.
    if (files.isBusy) {
      toast.show('Wait for the file to finish uploading');
      return;
    }
    if (files.hasProblem) {
      toast.show('A file could not be attached — remove it or try again');
      return;
    }
    final failure = await ref
        .read(ticketFormControllerProvider.notifier)
        .submit(attachmentFileIds: files.readyFileIds);
    if (!mounted) return;
    if (failure == null) {
      final created = ref.read(ticketFormControllerProvider).created;
      if (created == null) return;
      handOverTicketAttachments(ref, newTicketForm);
      toast.show('Request ${created.ticketNo} raised');
      // A fresh form, not just empty boxes: the old subject and description
      // stayed in the form and a second Send raised a duplicate
      // (BL-SUP-005).
      ref.invalidate(ticketFormControllerProvider);
      _subject.clear();
      _description.clear();
      context.push(AppRoutes.supportTicketPath(created.id));
      return;
    }
    toast.show(
      failure is ValidationFailure
          ? 'Fix the highlighted fields first'
          : failure.userMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(isAuthenticatedProvider);
    final contacts = ref.watch(supportContactsProvider);
    final faqTopics = ref.watch(faqTopicsProvider);
    final form = ref.watch(ticketFormControllerProvider);
    final controller = ref.read(ticketFormControllerProvider.notifier);
    final tickets = ref.watch(supportTicketsProvider.select((s) => s.value));
    final openCount = tickets?.where((t) => t.status.isOpen).length;

    return RouteArrival(
      onArrive: () {
        // The ticket list only; what is typed in the form is left alone.
        ref.invalidate(supportTicketsProvider);
      },
      child: AppUnsavedChangesGuard(
        hasUnsavedChanges:
            form.isDirty && !form.isSending && form.created == null,
        title: 'Discard your request?',
        consequence: 'What you have typed will not be sent.',
        child: Scaffold(
          backgroundColor: AppColors.bgApp,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppInnerHeader(
                  title: 'Help & Support',
                  onBack: () => _leave(context),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.x5.w,
                      AppSpacing.x1.h,
                      AppSpacing.x5.w,
                      AppSpacing.x8.h,
                    ),
                    children: [
                      // ---- Self-serve first: most questions are answered.
                      AppCard(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.x4.w,
                          AppSpacing.x4.h,
                          AppSpacing.x4.w,
                          AppSpacing.x2.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // The FAQ's live categories, not a fixed list of
                            // topics the server may not have.
                            SupportCardTitle(
                              title: 'Find an answer',
                              subtitle: faqTopics == null
                                  ? 'Common questions, answered.'
                                  : '$faqTopics questions, answered.',
                            ),
                            SupportLinkTile(
                              iconName: PhIcon.magnifyingGlass,
                              label: 'Browse FAQs',
                              subtitle: 'The questions we are asked most',
                              semanticLabel:
                                  'Browse frequently asked questions',
                              onTap: () => context.push(AppRoutes.faq),
                            ),
                            if (isSignedIn) ...[
                              SupportLinkTile(
                                iconName: PhIcon.folder,
                                label: 'My requests',
                                subtitle: openCount == null
                                    ? 'Track the requests you have raised'
                                    : openCount == 0
                                    ? 'No open requests'
                                    : openCount == 1
                                    ? '1 open request'
                                    : '$openCount open requests',
                                onTap: () =>
                                    context.push(AppRoutes.supportTickets),
                              ),
                              SupportLinkTile(
                                iconName: PhIcon.calendarBlank,
                                label: 'My appointments',
                                subtitle: 'Cancel, rebook or find a receipt',
                                onTap: () => context.go(AppRoutes.appointments),
                                showDivider: false,
                              ),
                            ] else
                              SupportLinkTile(
                                iconName: PhIcon.eye,
                                label: 'Sign in',
                                subtitle: 'Raise and track support requests',
                                onTap: () => context.go(AppRoutes.login),
                                showDivider: false,
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSpacing.x4.h),

                      // ---- Contact channels — from app-config.
                      AppCard(
                        padding: EdgeInsets.all(AppSpacing.x4.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SupportCardTitle(
                              title: 'Talk to us',
                              subtitle:
                                  'Raise a request below and we reply on the '
                                  'ticket. For anything urgent, ring us.',
                            ),
                            if (contacts.phoneE164 != null)
                              SupportContactTile(
                                iconName: PhIcon.bell,
                                title: 'Support line',
                                value: contacts.phoneE164!,
                                description:
                                    'Bookings, payments, refunds and records.',
                                actionLabel: 'Copy number',
                                actionSemanticLabel:
                                    'Copy the support phone number',
                                onAction: () => _copy(
                                  contacts.phoneE164!,
                                  'Support number',
                                ),
                                openSemanticLabel: 'Call support',
                                onOpen: () =>
                                    _open('tel:${contacts.phoneE164!}'),
                              ),
                            if (contacts.email != null)
                              SupportContactTile(
                                iconName: PhIcon.folder,
                                title: 'Support email',
                                value: contacts.email!,
                                description: 'Answered within one working day.',
                                actionLabel: 'Copy address',
                                actionSemanticLabel:
                                    'Copy the support email address',
                                onAction: () =>
                                    _copy(contacts.email!, 'Support email'),
                                openSemanticLabel: 'Email support',
                                onOpen: () =>
                                    _open('mailto:${contacts.email!}'),
                              ),
                            if (contacts.isEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: AppSpacing.x2.h),
                                child: Text(
                                  'No phone line is published right now. '
                                  'Raising a request below is the way to reach '
                                  'the team.',
                                  style: AppText.poppins(
                                    size: AppFontSize.xs,
                                    height: 1.45,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSpacing.x4.h),

                      // ---- Emergency: never a fake call button.
                      _EmergencyCard(
                        number: _emergencyNumber,
                        onOpenAmbulance: () =>
                            context.push(AppRoutes.ambulance),
                        onCopy: () => _copy(
                          _emergencyNumber,
                          'Emergency number $_emergencyNumber',
                        ),
                      ),
                      SizedBox(height: AppSpacing.x4.h),

                      // ---- Raise a request (signed-in only: the endpoint
                      // needs a token).
                      if (isSignedIn)
                        _RequestForm(
                          form: form,
                          subject: _subject,
                          description: _description,
                          onCategory: controller.setCategory,
                          onPriority: controller.setPriority,
                          onSubject: controller.setSubject,
                          onDescription: controller.setDescription,
                          onSubmit: _submit,
                        )
                      else
                        AppCard(
                          padding: EdgeInsets.all(AppSpacing.x4.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SupportCardTitle(
                                title: 'Raise a request',
                                subtitle:
                                    'Sign in to raise a request and follow its '
                                    'replies here.',
                              ),
                              SizedBox(height: AppSpacing.x2.h),
                              AppButton(
                                label: 'Sign In',
                                fullWidth: true,
                                onPressed: () => context.go(AppRoutes.login),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: AppSpacing.x4.h),

                      // ---- Policies (CM-02: the same slugs sign-up links to).
                      AppCard(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.x4.w,
                          AppSpacing.x4.h,
                          AppSpacing.x4.w,
                          AppSpacing.x2.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SupportCardTitle(title: 'Policies'),
                            for (var i = 0; i < _policies.length; i++)
                              SupportLinkTile(
                                iconName: PhIcon.folder,
                                label: _policies[i].title,
                                semanticLabel: 'Read the ${_policies[i].title}',
                                showDivider: i < _policies.length - 1,
                                onTap: () => context.push(
                                  AppRoutes.legalPath(_policies[i].slug),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The three documents the backend publishes (§3.2). Titles come from the
  /// document itself once opened; these are the link labels.
  static const List<({String slug, String title})> _policies = [
    (slug: AppRoutes.legalTerms, title: 'Terms of Service'),
    (slug: AppRoutes.legalPrivacy, title: 'Privacy Policy'),
    (slug: AppRoutes.legalGuidelines, title: 'Community Guidelines'),
  ];

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.profile);
  }
}

/// The "raise a request" card — category, priority, subject, description.
class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.form,
    required this.subject,
    required this.description,
    required this.onCategory,
    required this.onPriority,
    required this.onSubject,
    required this.onDescription,
    required this.onSubmit,
  });

  final TicketFormState form;
  final TextEditingController subject;
  final TextEditingController description;
  final ValueChanged<TicketCategory> onCategory;
  final ValueChanged<TicketPriority?> onPriority;
  final ValueChanged<String> onSubject;
  final ValueChanged<String> onDescription;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SupportCardTitle(
            title: 'Raise a request',
            subtitle:
                'Tell us what happened. You will get a ticket number and the '
                'replies appear under My requests.',
          ),
          SizedBox(height: AppSpacing.x3.h),
          AppSelect<TicketCategory>(
            label: 'What is this about?',
            value: form.category,
            options: [
              for (final category in TicketCategory.values)
                AppSelectOption<TicketCategory>(category, category.label),
            ],
            onChanged: (value) {
              if (value != null) onCategory(value);
            },
          ),
          if (form.errorFor(TicketFormField.category) != null)
            Padding(
              padding: EdgeInsets.only(top: 6.h),
              child: Text(
                form.errorFor(TicketFormField.category)!,
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  color: AppColors.dangerText,
                ),
              ),
            ),
          SizedBox(height: AppSpacing.x4.h),
          AppSelect<TicketPriority?>(
            label: 'How urgent is it?',
            value: form.priority,
            placeholder: 'Normal',
            options: [
              for (final priority in TicketPriority.values)
                AppSelectOption<TicketPriority?>(priority, priority.label),
            ],
            onChanged: onPriority,
          ),
          SizedBox(height: AppSpacing.x4.h),
          AppTextField(
            label: 'Subject',
            controller: subject,
            hintText: 'Refund not received',
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            errorText: form.errorFor(TicketFormField.subject),
            onChanged: onSubject,
          ),
          SizedBox(height: AppSpacing.x4.h),
          AppTextField(
            label: 'What happened?',
            controller: description,
            hintText: 'Include the booking reference if you have one',
            maxLines: 5,
            maxLength: 5000,
            textCapitalization: TextCapitalization.sentences,
            errorText: form.errorFor(TicketFormField.description),
            helperText: 'At least 20 characters',
            onChanged: onDescription,
          ),
          SizedBox(height: AppSpacing.x4.h),
          TicketAttachmentsField(form: newTicketForm, enabled: !form.isSending),
          if (form.failure != null) ...[
            SizedBox(height: AppSpacing.x3.h),
            Container(
              padding: EdgeInsets.all(AppSpacing.x3.w),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: AppRadii.md,
              ),
              child: Text(
                form.failure!.userMessage,
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  height: 1.45,
                  color: AppColors.dangerText,
                ),
              ),
            ),
          ],
          SizedBox(height: AppSpacing.x5.h),
          Consumer(
            builder: (context, ref, _) {
              final waiting = ref.watch(
                ticketAttachmentsProvider(
                  newTicketForm,
                ).select((files) => files.isBusy),
              );
              return AppButton(
                label: waiting ? 'Waiting for the file…' : 'Send Request',
                fullWidth: true,
                loading: form.isSending,
                disabled: waiting,
                onPressed: onSubmit,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The emergency row. Deliberately not a dial button: this build has no
/// telephony, and a control that looks like it calls an ambulance and does
/// nothing is the most dangerous possible version of a fake success.
class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({
    required this.number,
    required this.onOpenAmbulance,
    required this.onCopy,
  });

  final String number;
  final VoidCallback onOpenAmbulance;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(AppSpacing.x4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SupportCardTitle(
            title: 'Medical emergency',
            subtitle:
                'Support cannot help with an emergency. Do not wait for a '
                'reply.',
          ),
          SizedBox(height: AppSpacing.x2.h),
          Container(
            padding: EdgeInsets.all(AppSpacing.x4.w),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: AppRadii.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dial $number from your phone',
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    weight: AppText.bold,
                    color: AppColors.dangerText,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'The national ambulance line, free and open 24 hours.',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    height: 1.45,
                    color: AppColors.dangerText,
                  ),
                ),
                SizedBox(height: AppSpacing.x3.h),
                Row(
                  children: [
                    AppButton(
                      label: 'Copy $number',
                      variant: AppButtonVariant.soft,
                      size: AppButtonSize.sm,
                      semanticLabel: 'Copy the emergency number $number',
                      onPressed: onCopy,
                    ),
                    SizedBox(width: AppSpacing.x2.w),
                    AppButton(
                      label: 'Ambulance',
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.sm,
                      semanticLabel: 'Open the ambulance directory',
                      onPressed: onOpenAmbulance,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
