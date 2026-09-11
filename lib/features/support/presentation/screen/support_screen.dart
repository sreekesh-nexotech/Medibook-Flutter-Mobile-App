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
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_select.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/support_tiles.dart';
import '../controllers/support_request_controller.dart';

/// Help & Support (`/support`, and `/help` — the same screen) — CM-52.
///
/// The audit found *"no help, FAQ, support or legal screen reachable from
/// anywhere in the app"*. This is the hub: the contact channels, a request
/// form, and links to the FAQ and the three policy documents (whose slugs come
/// from `legalDocumentsProvider`, so they cannot drift from
/// [AppRoutes.legalSlugs] and the sign-up policy links).
///
/// ## Honest controls
///
/// * **Copy** genuinely copies to the clipboard, so the toast it shows is
///   true.
/// * **Send request** is marked `stubbed` and, once the form validates, says
///   so — there is no support backend in this build, and a "We have received
///   your request" toast for a request nobody received is exactly the lie THE
///   LAW forbids. The form still validates, so the flow is reviewable.
/// * There is **no "Call support" button**: no telephony plugin exists. The
///   emergency row points at the ambulance screen and names 108 instead of
///   pretending to dial.
class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  /// The addresses the seeded policy documents themselves publish.
  static const String _supportEmail = 'support@medibook.app';
  static const String _privacyEmail = 'privacy@medibook.app';

  /// The national emergency number — real, and deliberately not a button.
  static const String _emergencyNumber = '108';

  late final TextEditingController _subject;
  late final TextEditingController _details;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final state = ref.read(supportRequestControllerProvider);
    _subject = TextEditingController(text: state.subject);
    _details = TextEditingController(text: state.details);
    _email = TextEditingController(text: state.email);
  }

  @override
  void dispose() {
    _subject.dispose();
    _details.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _copy(String value, String what) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ref.read(toastControllerProvider.notifier).show('$what copied');
  }

  void _submit() {
    final valid = ref
        .read(supportRequestControllerProvider.notifier)
        .validate();
    if (!valid) return;
    // Validated, and now the truth: nothing can be sent from this build.
    showStubbedToast(context, ref, 'Sending a support request');
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(legalDocumentsProvider);
    final request = ref.watch(supportRequestControllerProvider);
    final controller = ref.read(supportRequestControllerProvider.notifier);

    return Scaffold(
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
                  // ---- Self-serve first: most questions are already answered.
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
                        const SupportCardTitle(
                          title: 'Find an answer',
                          subtitle:
                              'Booking, payments, records and account '
                              'questions, answered.',
                        ),
                        SupportLinkTile(
                          iconName: MedIcon.search,
                          label: 'Browse FAQs',
                          subtitle: 'The ten questions we are asked most',
                          semanticLabel: 'Browse frequently asked questions',
                          onTap: () => context.push(AppRoutes.faq),
                        ),
                        SupportLinkTile(
                          iconName: MedIcon.calendar,
                          label: 'My appointments',
                          subtitle: 'Reschedule, cancel or find a receipt',
                          onTap: () => context.go(AppRoutes.appointments),
                        ),
                        SupportLinkTile(
                          iconName: MedIcon.records,
                          label: 'My health records',
                          subtitle: 'Reports, prescriptions and uploads',
                          onTap: () => context.go(AppRoutes.records),
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.x4.h),

                  // ---- Contact channels.
                  AppCard(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.x4.w,
                      AppSpacing.x4.h,
                      AppSpacing.x4.w,
                      AppSpacing.x4.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SupportCardTitle(
                          title: 'Talk to us',
                          subtitle:
                              'Email is the fastest way to reach the support '
                              'team.',
                        ),
                        SupportContactTile(
                          iconName: MedIcon.records,
                          title: 'Support team',
                          value: _supportEmail,
                          description:
                              'Bookings, payments, refunds and records. '
                              'Answered within one working day.',
                          actionLabel: 'Copy address',
                          actionSemanticLabel: 'Copy the support email address',
                          onAction: () =>
                              _copy(_supportEmail, 'Support email address'),
                        ),
                        SupportContactTile(
                          iconName: MedIcon.eye,
                          title: 'Data and privacy',
                          value: _privacyEmail,
                          description:
                              'See, correct, export or delete your data. '
                              'Answered within 30 days.',
                          actionLabel: 'Copy address',
                          actionSemanticLabel: 'Copy the privacy email address',
                          onAction: () =>
                              _copy(_privacyEmail, 'Privacy email address'),
                        ),
                        SupportFactRow(
                          label: 'Support hours',
                          value: 'Mon–Sat, 9 AM – 7 PM IST',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.x4.h),

                  // ---- Emergency: never a fake call button.
                  _EmergencyCard(
                    number: _emergencyNumber,
                    onOpenAmbulance: () => context.push(AppRoutes.ambulance),
                    onCopy: () => _copy(
                      _emergencyNumber,
                      'Emergency number $_emergencyNumber',
                    ),
                  ),
                  SizedBox(height: AppSpacing.x4.h),

                  // ---- Raise a request.
                  AppCard(
                    padding: EdgeInsets.all(AppSpacing.x4.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SupportCardTitle(
                          title: 'Raise a request',
                          subtitle:
                              'Tell us what happened and we will reply by '
                              'email.',
                        ),
                        SizedBox(height: AppSpacing.x3.h),
                        AppSelect<String>(
                          label: 'What is this about?',
                          value: request.category,
                          options: [
                            for (final category in SupportRequestCategories.all)
                              AppSelectOption<String>(category, category),
                          ],
                          onChanged: (value) {
                            if (value != null) controller.setCategory(value);
                          },
                        ),
                        SizedBox(height: AppSpacing.x4.h),
                        AppTextField(
                          label: 'Subject',
                          controller: _subject,
                          hintText: 'Refund not received',
                          maxLength: 80,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          errorText: request.errorFor(
                            SupportRequestField.subject,
                          ),
                          onChanged: controller.setSubject,
                        ),
                        SizedBox(height: AppSpacing.x4.h),
                        AppTextField(
                          label: 'What happened?',
                          controller: _details,
                          hintText:
                              'Include the booking reference if you have one',
                          maxLines: 4,
                          maxLength: 600,
                          textCapitalization: TextCapitalization.sentences,
                          errorText: request.errorFor(
                            SupportRequestField.details,
                          ),
                          helperText: 'At least 20 characters',
                          onChanged: controller.setDetails,
                        ),
                        SizedBox(height: AppSpacing.x4.h),
                        AppTextField(
                          label: 'Reply to',
                          controller: _email,
                          hintText: 'you@example.com',
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.done,
                          errorText: request.errorFor(
                            SupportRequestField.email,
                          ),
                          onChanged: controller.setEmail,
                          onSubmitted: (_) => _submit(),
                        ),
                        SizedBox(height: AppSpacing.x5.h),
                        AppButton(
                          label: 'Send Request',
                          fullWidth: true,
                          // No support backend exists in this build, so the
                          // control says so rather than faking a ticket.
                          stubbed: true,
                          onPressed: _submit,
                        ),
                        SizedBox(height: AppSpacing.x3.h),
                        AppStubBanner(
                          title: 'Not connected yet',
                          body:
                              'Sending is not wired up in this build. Until it '
                              'is, email $_supportEmail — the form checks your '
                              'request is complete either way.',
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
                        for (var i = 0; i < documents.length; i++)
                          SupportLinkTile(
                            iconName: MedIcon.records,
                            label: documents[i].title,
                            subtitle: 'Version ${documents[i].version}',
                            semanticLabel: 'Read the ${documents[i].title}',
                            showDivider: i < documents.length - 1,
                            onTap: () => context.push(
                              AppRoutes.legalPath(documents[i].slug),
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
    );
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.profile);
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
                      semanticLabel: 'Open the ambulance screen',
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
