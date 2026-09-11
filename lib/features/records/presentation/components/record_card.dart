import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/medical_record.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_tag.dart';
import 'document_type_icon.dart';

/// One document in the library (CM-32): type glyph + title + date + status,
/// the patient / facility / doctor meta rows, the linked appointment when there
/// is one, the file line, and the preview / download row.
///
/// Pure presentation — the owning screen supplies [record] and wires the
/// callbacks. Tapping the card itself opens the document detail.
///
/// ## The two file controls are honest (project rule on stubbed controls)
///
/// There is no PDF renderer and no storage package in this build, so:
///
/// * with a file on the record, both buttons render `stubbed: true` and their
///   callbacks say so via `showStubbedToast`;
/// * with **no** file — every document created in-app, since there is no
///   picker — they are `disabled: true` and their `semanticLabel` gives the
///   reason.
///
/// Neither shape ever reports a download that did not happen.
class RecordCard extends StatelessWidget {
  const RecordCard({
    super.key,
    required this.record,
    required this.onOpen,
    required this.onView,
    required this.onDownload,
    this.linkedAppointmentLabel,
  });

  final MedicalRecord record;

  /// Opens the document detail screen.
  final VoidCallback onOpen;

  /// Preview — stubbed; see the class doc.
  final VoidCallback onView;

  /// Download — stubbed; see the class doc.
  final VoidCallback onDownload;

  /// "Dr. Anil Kumar · 10 Jul 2026" when the document is attached to a visit.
  final String? linkedAppointmentLabel;

  bool get _isCompleted => record.status == RecordStatus.completed;

  @override
  Widget build(BuildContext context) {
    final hasFile = record.hasFile;
    final appointmentLabel = linkedAppointmentLabel;
    final notes = record.notes;

    return AppCard(
      padding: EdgeInsets.all(18.w),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Type glyph + title / date + status badge ----
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40.r,
                height: 40.r,
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint,
                  borderRadius: AppRadii.md,
                ),
                child: Center(
                  child: AppIcon(
                    DocumentTypeIcon.of(record.type),
                    size: 20,
                    color: AppColors.brand,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: AppText.poppins(
                        size: AppFontSize.body,
                        weight: AppText.bold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      record.date,
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10.w),
              AppBadge(
                label: record.status.label,
                tone: _isCompleted ? AppBadgeTone.success : AppBadgeTone.danger,
              ),
            ],
          ),

          SizedBox(height: 12.h),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppTag(label: record.type.label),
          ),

          // ---- Meta rows ----
          Padding(
            padding: EdgeInsets.only(top: 14.h, bottom: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetaRow(
                  icon: MedIcon.records,
                  label: 'Patient Name',
                  value: record.patient.isEmpty
                      ? 'Not recorded'
                      : record.patient,
                ),
                if (record.hospital.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  _MetaRow(
                    icon: MedIcon.hospital,
                    label: 'Center/Hospital',
                    value: record.hospital,
                  ),
                ],
                if (record.doctor.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  _MetaRow(
                    icon: MedIcon.records,
                    label: 'Consulted Doctor',
                    value: record.doctor,
                  ),
                ],
                if (appointmentLabel != null) ...[
                  SizedBox(height: 10.h),
                  _MetaRow(
                    icon: MedIcon.calendar,
                    label: 'Linked appointment',
                    value: appointmentLabel,
                  ),
                ],
                SizedBox(height: 10.h),
                _MetaRow(
                  icon: MedIcon.download,
                  label: 'File',
                  value: hasFile
                      ? '${record.fileName} · ${record.fileSizeLabel}'
                      : 'No file attached',
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  _MetaRow(icon: MedIcon.edit, label: 'Notes', value: notes),
                ],
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
                  stubbed: hasFile,
                  disabled: !hasFile,
                  semanticLabel: hasFile
                      ? 'Preview ${record.title} — stubbed in this demo'
                      : 'Preview unavailable — no file is attached to '
                            '${record.title}',
                  onPressed: hasFile ? onView : null,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: AppButton(
                  label: 'Download',
                  size: AppButtonSize.sm,
                  pill: true,
                  fullWidth: true,
                  leadingIcon: MedIcon.download,
                  stubbed: hasFile,
                  disabled: !hasFile,
                  semanticLabel: hasFile
                      ? 'Download ${record.title} — stubbed in this demo'
                      : 'Download unavailable — no file is attached to '
                            '${record.title}',
                  onPressed: hasFile ? onDownload : null,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2.h),
          child: AppIcon(icon, size: 18, color: AppColors.textMuted),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppText.poppins(
                  size: AppFontSize.xs,
                  color: AppColors.textMuted,
                  height: 1.2,
                ),
              ),
              Text(
                value,
                style: AppText.poppins(
                  size: AppFontSize.base,
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
