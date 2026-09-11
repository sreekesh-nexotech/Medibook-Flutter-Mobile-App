import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_text_field.dart';

/// The allergies editor on the dependant form (CM-48).
///
/// ## Why chips and not a comma-separated string
///
/// `Patient.allergies` is a `List<String>`, and the doctor reading it needs the
/// items, not a sentence. A single text field would force this widget to split
/// on commas — which silently mangles "Sulfa drugs, incl. co-trimoxazole" and
/// makes removing the middle entry a text-editing exercise. One chip per
/// allergy keeps the stored shape and the shown shape identical, and removal is
/// a labelled 48px control rather than careful cursor work.
///
/// Nothing here has a fixed height: the chips wrap, so the field grows at 1.3x
/// text scale instead of clipping.
class AllergyChipsField extends StatefulWidget {
  const AllergyChipsField({
    super.key,
    required this.allergies,
    required this.onChanged,
    this.label = 'Allergies',
    this.helperText,
  });

  /// The current list, in the order it is stored.
  final List<String> allergies;

  /// Called with the whole new list on every add or remove.
  final ValueChanged<List<String>> onChanged;

  final String label;

  /// A quiet line under the control. Defaults to a note on why this matters.
  final String? helperText;

  @override
  State<AllergyChipsField> createState() => _AllergyChipsFieldState();
}

class _AllergyChipsFieldState extends State<AllergyChipsField> {
  /// The draft entry. Widget-local on purpose: it is not part of the patient
  /// record and must not survive the form being closed.
  final TextEditingController _draft = TextEditingController();

  /// Set when the typed entry cannot be added, so the reason is visible rather
  /// than the Add button just doing nothing.
  String? _error;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _add() {
    final value = _draft.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Type an allergy first');
      return;
    }
    final alreadyListed = widget.allergies.any(
      (a) => a.toLowerCase() == value.toLowerCase(),
    );
    if (alreadyListed) {
      setState(() => _error = '"$value" is already listed');
      return;
    }
    widget.onChanged([...widget.allergies, value]);
    _draft.clear();
    setState(() => _error = null);
  }

  void _remove(String allergy) {
    widget.onChanged(widget.allergies.where((a) => a != allergy).toList());
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: AppText.poppins(
            size: AppFontSize.base,
            weight: AppText.medium,
            color: AppColors.textStrong,
          ),
        ),
        SizedBox(height: AppSpacing.x2.h),
        if (widget.allergies.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.x2.h),
            child: Text(
              'None recorded',
              style: AppText.poppins(
                size: AppFontSize.sm,
                color: AppColors.textMuted,
              ),
            ),
          )
        else
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.x3.h),
            child: Wrap(
              spacing: AppSpacing.x2.w,
              runSpacing: AppSpacing.x2.h,
              children: [
                for (final allergy in widget.allergies)
                  _AllergyChip(
                    label: allergy,
                    onRemove: () => _remove(allergy),
                  ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                controller: _draft,
                hintText: 'Penicillin',
                maxLength: 60,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                semanticLabel: 'Add an allergy',
                errorText: _error,
                onSubmitted: (_) => _add(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ),
            SizedBox(width: AppSpacing.x2.w),
            Padding(
              // Aligns the button with the field box, not with its label row.
              padding: EdgeInsets.only(top: 2.h),
              child: AppButton(
                label: 'Add',
                variant: AppButtonVariant.soft,
                size: AppButtonSize.md,
                semanticLabel: 'Add this allergy to the list',
                onPressed: _add,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          widget.helperText ??
              'Shown to the doctor with the appointment. Add one at a time.',
          style: AppText.poppins(
            size: AppFontSize.xs,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// One allergy, with its own labelled remove control.
class _AllergyChip extends StatelessWidget {
  const _AllergyChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 36.h),
      padding: EdgeInsets.only(
        left: AppSpacing.x3.w,
        right: 6.w,
        top: 6.h,
        bottom: 6.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: AppRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The chip can be long ("Sulfa drugs"), so it must be able to
          // shrink rather than push the row past the screen edge.
          Flexible(
            child: Text(
              label,
              style: AppText.poppins(
                size: AppFontSize.sm,
                weight: AppText.medium,
                color: AppColors.dangerText,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Semantics(
            button: true,
            label: 'Remove $label from allergies',
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Padding(
                  // Pads the 14px glyph out to a comfortable target inside the
                  // chip without making the chip itself huge.
                  padding: EdgeInsets.all(6.w),
                  child: AppIcon(
                    MedIcon.close,
                    size: 12,
                    color: AppColors.dangerText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
