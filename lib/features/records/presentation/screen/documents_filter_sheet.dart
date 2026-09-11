import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/medical_record.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/mock_data/stores/dependants_store.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_icon.dart';
import '../components/document_option_sheet.dart';
import '../components/document_picker_field.dart';
import '../components/document_type_icon.dart';
import '../controllers/documents_filter_controller.dart';
import '../controllers/linkable_appointments_provider.dart';

/// Open the documents filter (CM-34) as a bottom sheet.
///
/// A sheet rather than a pushed screen, for the same reason the appointments
/// filter is one: filtering narrows something you are looking at, and the list
/// with its active chips stays visible behind the scrim. Half-set filters are
/// abandoned with a swipe, which is what people do when they change their mind
/// mid-filter.
///
/// Writes straight to [documentsFilterProvider], which the Records list
/// watches, so it returns nothing.
Future<void> showDocumentsFilterSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    title: 'Filter documents',
    builder: (sheetContext) =>
        DocumentsFilterBody(onDone: () => Navigator.of(sheetContext).pop()),
  );
}

/// The filter form itself: document type (multi-select), patient, date range
/// and linked appointment.
///
/// Every facet is stored typed on [DocumentFilters] — a `Set<DocumentType>`, a
/// patient id, two real `DateTime` bounds, an appointment id — so matching runs
/// against `MedicalRecord.recordedAt` and `.type`, never against the rendered
/// date or type strings (audit §3.8.3).
class DocumentsFilterBody extends ConsumerWidget {
  const DocumentsFilterBody({super.key, required this.onDone});

  /// Closes the surface hosting this body.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(documentsFilterProvider);
    final controller = ref.read(documentsFilterProvider.notifier);
    final patientId = filters.patientId;
    final patient = patientId == null
        ? null
        : ref.watch(patientByIdProvider(patientId));
    final appointmentId = filters.appointmentId;
    final appointment = appointmentId == null
        ? null
        : ref.watch(linkableAppointmentByIdProvider(appointmentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel('Document type'),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final type in DocumentType.values)
              _TypeToggle(
                type: type,
                isSelected: filters.types.contains(type),
                onTap: () => controller.toggleType(type),
              ),
          ],
        ),
        SizedBox(height: 18.h),
        DocumentPickerField(
          label: 'Patient',
          value: patient?.name,
          placeholder: 'Everyone',
          iconName: MedIcon.records,
          helperText: 'Only documents filed under one person',
          semanticLabel: 'Filter by patient: ${patient?.name ?? 'everyone'}',
          onTap: () => _pickPatient(context, ref, patientId),
        ),
        SizedBox(height: 16.h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DocumentPickerField(
                label: 'From',
                value: filters.from == null
                    ? null
                    : AppDates.dayMonthYear(filters.from!),
                placeholder: 'Any',
                semanticLabel:
                    'Filter documents from '
                    '${filters.from == null ? 'any date' : AppDates.dayMonthYear(filters.from!)}',
                onTap: () => _pickBound(context, ref, isStart: true),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: DocumentPickerField(
                label: 'To',
                value: filters.to == null
                    ? null
                    : AppDates.dayMonthYear(filters.to!),
                placeholder: 'Any',
                semanticLabel:
                    'Filter documents up to '
                    '${filters.to == null ? 'any date' : AppDates.dayMonthYear(filters.to!)}',
                onTap: () => _pickBound(context, ref, isStart: false),
              ),
            ),
          ],
        ),
        if (filters.hasDateRange) ...[
          SizedBox(height: 8.h),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppButton(
              label: 'Clear dates',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              semanticLabel: 'Clear the document date range',
              onPressed: controller.clearDateRange,
            ),
          ),
        ],
        SizedBox(height: 16.h),
        DocumentPickerField(
          label: 'Linked appointment',
          value: appointment?.label,
          placeholder: 'Any visit',
          iconName: MedIcon.calendar,
          helperText: 'Only documents attached to one visit',
          semanticLabel:
              'Filter by linked appointment: '
              '${appointment?.label ?? 'any visit'}',
          onTap: () => _pickAppointment(context, ref, appointmentId),
        ),
        SizedBox(height: 22.h),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Clear all',
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.md,
                pill: true,
                fullWidth: true,
                disabled: !filters.isActive,
                semanticLabel: filters.isActive
                    ? 'Clear all document filters'
                    : 'Clear all filters — nothing is filtered',
                onPressed: filters.isActive ? controller.clearAll : null,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: AppButton(
                label: 'Show results',
                size: AppButtonSize.md,
                pill: true,
                fullWidth: true,
                onPressed: onDone,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickPatient(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final patients = ref.read(patientsProvider);
    final picked = await showDocumentOptionSheet<String>(
      context,
      title: 'Filter by patient',
      selected: current ?? _anyValue,
      options: [
        const DocumentOption(
          value: _anyValue,
          label: 'Everyone',
          subtitle: 'Documents for every person on the account',
        ),
        for (final patient in patients)
          DocumentOption(
            value: patient.id,
            label: patient.name,
            subtitle: '${patient.relation} · ${patient.meta}',
            iconName: MedIcon.records,
          ),
      ],
    );
    if (picked == null) return;
    ref
        .read(documentsFilterProvider.notifier)
        .setPatient(picked == _anyValue ? null : picked);
  }

  Future<void> _pickAppointment(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final appointments = ref.read(linkableAppointmentsProvider);
    final picked = await showDocumentOptionSheet<String>(
      context,
      title: 'Filter by appointment',
      selected: current ?? _anyValue,
      options: [
        const DocumentOption(
          value: _anyValue,
          label: 'Any visit',
          subtitle: 'Linked or not',
        ),
        for (final appointment in appointments)
          DocumentOption(
            value: appointment.id,
            label: appointment.doctorName,
            subtitle: AppDates.dayMonthYear(appointment.scheduledAt),
            iconName: MedIcon.calendar,
          ),
      ],
    );
    if (picked == null) return;
    ref
        .read(documentsFilterProvider.notifier)
        .setAppointment(picked == _anyValue ? null : picked);
  }

  Future<void> _pickBound(
    BuildContext context,
    WidgetRef ref, {
    required bool isStart,
  }) async {
    final filters = ref.read(documentsFilterProvider);
    final now = DateTime.now();
    final picked = await showAppDatePickerSheet(
      context,
      title: isStart ? 'From which date?' : 'Up to which date?',
      initialDay: (isStart ? filters.from : filters.to) ?? now,
      firstDay: DateTime(now.year - 10, now.month, now.day),
      // Documents are never recorded in the future, so neither bound can be.
      lastDay: now,
    );
    if (picked == null) return;
    final controller = ref.read(documentsFilterProvider.notifier);
    // Keep the range ordered whichever bound the user set second.
    var from = isStart ? picked : filters.from;
    var to = isStart ? filters.to : picked;
    if (from != null && to != null && from.isAfter(to)) {
      if (isStart) {
        to = picked;
      } else {
        from = picked;
      }
    }
    controller.setDateRange(from: from, to: to);
  }

  /// Sentinel for the "no constraint" row — a dismissed sheet returns null, so
  /// "everyone" / "any visit" needs a value of its own.
  static const String _anyValue = '__any__';
}

/// One multi-select document-type chip.
class _TypeToggle extends StatelessWidget {
  const _TypeToggle({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final DocumentType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${type.label} documents',
      child: ExcludeSemantics(
        child: Material(
          color: isSelected ? AppColors.brand : AppColors.surfaceAlt,
          borderRadius: AppRadii.pill,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.pill,
            child: Container(
              constraints: BoxConstraints(minHeight: 38.h),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                borderRadius: AppRadii.pill,
                border: Border.all(
                  color: isSelected ? AppColors.brand : AppColors.border,
                  width: 1.w,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    DocumentTypeIcon.of(type),
                    size: 16,
                    color: isSelected
                        ? AppColors.textOnBrand
                        : AppColors.textMuted,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    type.label,
                    style: AppText.poppins(
                      size: AppFontSize.xs,
                      weight: AppText.medium,
                      color: isSelected
                          ? AppColors.textOnBrand
                          : AppColors.textBody,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small group heading inside the sheet.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.poppins(
        size: AppFontSize.base,
        weight: AppText.semibold,
        color: AppColors.textStrong,
      ),
    );
  }
}
