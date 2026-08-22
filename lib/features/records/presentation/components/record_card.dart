import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/medical_record.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';

/// A single lab/health record on the Records tab: title + date + status badge,
/// three meta rows (patient / center / doctor), and the View Report / Download
/// action row.
///
/// Pure presentation — the owning screen supplies the [record] and wires the two
/// callbacks (which fire toasts). No provider access here.
class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.record,
    required this.onView,
    required this.onDownload,
  });

  final MedicalRecord record;
  final VoidCallback onView;
  final VoidCallback onDownload;

  bool get _isCompleted => record.status == RecordStatus.completed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Title / date + status badge ----
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: AppText.poppins(
                        size: 16,
                        weight: AppText.bold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      record.date,
                      style: AppText.poppins(
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              AppBadge(
                label: record.status.label,
                tone: _isCompleted ? AppBadgeTone.success : AppBadgeTone.danger,
              ),
            ],
          ),

          // ---- Meta rows ----
          Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetaRow(
                  icon: MedIcon.records,
                  label: 'Patient Name',
                  value: record.patient,
                ),
                SizedBox(height: 10.h),
                _MetaRow(
                  icon: MedIcon.hospital,
                  label: 'Center/Hospital',
                  value: record.hospital,
                ),
                SizedBox(height: 10.h),
                _MetaRow(
                  icon: MedIcon.records,
                  label: 'Consulted Doctor',
                  value: record.doctor,
                ),
              ],
            ),
          ),

          // ---- Actions ----
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'View Report',
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  pill: true,
                  fullWidth: true,
                  leadingIcon: MedIcon.eye,
                  onPressed: onView,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: AppButton(
                  label: 'Download',
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.sm,
                  pill: true,
                  fullWidth: true,
                  leadingIcon: MedIcon.download,
                  onPressed: onDownload,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One labelled meta line: muted glyph + (caption over value).
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppIcon(icon, size: 18, color: AppColors.textMuted),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppText.poppins(
                  size: 12,
                  color: AppColors.textMuted,
                  height: 1.2,
                ),
              ),
              Text(
                value,
                style: AppText.poppins(
                  size: 14,
                  weight: AppText.semibold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
