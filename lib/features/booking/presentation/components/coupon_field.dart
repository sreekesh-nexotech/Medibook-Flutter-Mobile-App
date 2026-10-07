import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Coupon entry for the booking summary (CM-19).
///
/// "Apply" is a fee-quote call with `coupon_code` (§8.3): the backend prices
/// the coupon and says whether it is valid. This widget shows that verdict
/// honestly — an unknown code says so inline and the price does not move.
/// There is no local coupon table.
///
/// Applied state shows the code, the money it actually took off, and a Remove
/// control. The owning screen holds the typed code and the quote; this widget
/// owns only the text being typed.
class CouponField extends StatefulWidget {
  const CouponField({
    super.key,
    required this.appliedCode,
    required this.discountPaise,
    required this.onApply,
    required this.onRemove,
    this.rejectionCode,
    this.enabled = true,
    this.checking = false,
  });

  /// The code the quote accepted, or null.
  final String? appliedCode;

  /// What [appliedCode] took off (paise) — shown so the saving is verifiable.
  final int discountPaise;

  /// Fires with the trimmed, upper-cased code the patient typed.
  final ValueChanged<String> onApply;

  final VoidCallback onRemove;

  /// The backend's `coupon.reason` for a refused code, or null.
  final String? rejectionCode;

  /// False while a booking is in flight — the price must not change under it.
  final bool enabled;

  /// True while the quote with the coupon is loading.
  final bool checking;

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

  /// House wording for the four coupon rejections (§8.3).
  static String? _reasonText(String? code) => switch (code) {
    null => null,
    ApiErrorCodes.couponInvalid => 'That coupon code is not valid.',
    ApiErrorCodes.couponExpired => 'That coupon has expired.',
    ApiErrorCodes.couponMinOrder =>
      'The order is below the minimum for that coupon.',
    ApiErrorCodes.couponUsageCap => 'That coupon has been used up.',
    _ => 'That coupon could not be applied.',
  };

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
                errorText: _reasonText(widget.rejectionCode),
                enabled: widget.enabled && !widget.checking,
                semanticLabel: 'Coupon code',
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  LengthLimitingTextInputFormatter(64),
                ],
                onSubmitted: (_) => _submit(),
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
                loading: widget.checking,
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
                '${Money.inr(widget.discountPaise)} off',
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
