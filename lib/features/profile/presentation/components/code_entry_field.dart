import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_countdown.dart';
import '../../../../core/widgets/app_text_field.dart';

/// A one-time-code entry block for the profile feature's OTP steps (phone
/// change §5.3, release §5.8): the destination line, a digits-only field
/// sized to the challenge's `code_length`, the attempts-remaining note, and a
/// Resend control gated by `resend_after_seconds`.
///
/// Widget-local state is the text only; the code is handed up on submit and
/// never stored anywhere else. The auth feature has its own boxed OTP entry;
/// this deliberately does not import across features.
class CodeEntryField extends StatefulWidget {
  const CodeEntryField({
    super.key,
    required this.codeLength,
    required this.onSubmit,
    required this.onResend,
    this.destinationMasked,
    this.resendAfter,
    this.errorText,
    this.attemptsRemaining,
    this.isBusy = false,
    this.submitLabel = 'Verify',
  });

  final int codeLength;
  final ValueChanged<String> onSubmit;
  final VoidCallback onResend;

  /// `+91******10`, or null when it must not be revealed.
  final String? destinationMasked;

  /// When Resend may be tapped; null enables it immediately.
  final DateTime? resendAfter;
  final String? errorText;
  final int? attemptsRemaining;
  final bool isBusy;
  final String submitLabel;

  @override
  State<CodeEntryField> createState() => _CodeEntryFieldState();
}

class _CodeEntryFieldState extends State<CodeEntryField> {
  final TextEditingController _code = TextEditingController();
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _canResend = _resendOpen();
  }

  @override
  void didUpdateWidget(CodeEntryField old) {
    super.didUpdateWidget(old);
    if (old.resendAfter != widget.resendAfter) {
      _canResend = _resendOpen();
      _code.clear();
    }
  }

  bool _resendOpen() {
    final after = widget.resendAfter;
    return after == null || !after.isAfter(DateTime.now());
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.isBusy) return;
    widget.onSubmit(_code.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destinationMasked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (destination != null)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.x3.h),
            child: Text(
              'We sent a ${widget.codeLength}-digit code to $destination.',
              style: AppText.poppins(
                size: AppFontSize.sm,
                height: 1.5,
                color: AppColors.textBody,
              ),
            ),
          ),
        AppTextField(
          label: 'Code',
          controller: _code,
          hintText: '0' * widget.codeLength,
          keyboardType: TextInputType.number,
          maxLength: widget.codeLength,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          semanticLabel: 'One-time code',
          errorText: widget.errorText,
          helperText: widget.attemptsRemaining == null
              ? null
              : widget.attemptsRemaining == 1
              ? '1 attempt left'
              : '${widget.attemptsRemaining} attempts left',
          enabled: !widget.isBusy,
          onSubmitted: (_) => _submit(),
        ),
        SizedBox(height: AppSpacing.x4.h),
        AppButton(
          label: widget.submitLabel,
          fullWidth: true,
          loading: widget.isBusy,
          onPressed: _submit,
        ),
        SizedBox(height: AppSpacing.x2.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_canResend && widget.resendAfter != null) ...[
              Text(
                'Resend in ',
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  color: AppColors.textMuted,
                ),
              ),
              AppCountdown(
                deadline: widget.resendAfter!,
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  color: AppColors.textMuted,
                ),
                onExpired: () {
                  if (mounted) setState(() => _canResend = true);
                },
              ),
            ] else
              AppButton(
                label: 'Resend code',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                disabled: widget.isBusy,
                onPressed: widget.onResend,
              ),
          ],
        ),
      ],
    );
  }
}
