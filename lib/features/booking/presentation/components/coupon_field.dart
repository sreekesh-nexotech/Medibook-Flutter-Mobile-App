import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/config/feature_flags.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/fee_breakdown.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Coupon entry for the booking summary and the payment screen (CM-19).
///
/// The audit found no coupon entry anywhere, which is why the fee could be a
/// single string: with nothing able to change the price, nothing had to be
/// recomputed. This is the control that changes it, and it is deliberately
/// honest about failure — an unknown code says so inline and the price does
/// not move. It never silently ignores a code.
///
/// Applied state shows the code, the money it actually took off, and a Remove
/// control, because a discount you cannot remove is a trap if the patient
/// mistypes a better one.
///
/// The owning screen holds the applied code and the error (they live in the
/// booking draft); this widget owns only the text being typed.
class CouponField extends StatefulWidget {
  const CouponField({
    super.key,
    required this.appliedCode,
    required this.discount,
    required this.onApply,
    required this.onRemove,
    this.errorText,
    this.enabled = true,
  });

  /// The code currently applied, or null.
  final String? appliedCode;

  /// What [appliedCode] took off — shown so the saving is verifiable.
  final Money discount;

  /// Fires with the trimmed, upper-cased code the patient typed.
  final ValueChanged<String> onApply;

  final VoidCallback onRemove;

  /// Why the last attempt failed, or null.
  final String? errorText;

  /// False while a payment is in flight — the price must not change under a
  /// gateway call.
  final bool enabled;

  @override
  State<CouponField> createState() => _CouponFieldState();
}

class _CouponFieldState extends State<CouponField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) return;
    widget.onApply(code);
  }

  void _remove() {
    _controller.clear();
    widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    final applied = widget.appliedCode;

    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: applied == null ? _entry() : _applied(applied),
    );
  }

  Widget _entry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Have a coupon?',
          style: AppText.poppins(
            size: AppFontSize.base,
            weight: AppText.semibold,
            color: AppColors.textStrong,
          ),
        ),
        SizedBox(height: AppSpacing.x3.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _controller,
                hintText: 'Enter code',
                errorText: widget.errorText,
                enabled: widget.enabled,
                semanticLabel: 'Coupon code',
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(16),
                ],
                onSubmitted: (_) => _submit(),
                helperText: FeatureFlags.demoMode
                    ? 'Demo codes: ${DemoCoupons.percentOff.keys.join(', ')}'
                    : null,
              ),
            ),
            SizedBox(width: AppSpacing.x3.w),
            Padding(
              // Aligns the button with the 52px field, whose label sits above.
              padding: EdgeInsets.only(top: 2.h),
              child: AppButton(
                label: 'Apply',
                variant: AppButtonVariant.secondary,
                disabled: !widget.enabled,
                semanticLabel: 'Apply coupon code',
                onPressed: _submit,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _applied(String code) {
    return Row(
      children: [
        Container(
          width: 34.w,
          height: 34.w,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.successSoft,
            shape: BoxShape.circle,
          ),
          child: AppIcon(MedIcon.bag, size: 17, color: AppColors.successText),
        ),
        SizedBox(width: AppSpacing.x3.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$code applied',
                style: AppText.poppins(
                  size: AppFontSize.base,
                  weight: AppText.semibold,
                  color: AppColors.textStrong,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                '${widget.discount.format()} off the consultation fee',
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.x2.w),
        AppButton(
          label: 'Remove',
          variant: AppButtonVariant.ghost,
          size: AppButtonSize.sm,
          disabled: !widget.enabled,
          semanticLabel: 'Remove coupon $code',
          onPressed: _remove,
        ),
      ],
    );
  }
}
