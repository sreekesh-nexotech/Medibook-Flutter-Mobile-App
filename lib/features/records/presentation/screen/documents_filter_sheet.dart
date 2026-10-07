import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../common/persons/application/providers/persons_read_provider.dart';
import '../../application/providers/records_provider.dart';
import '../../domain/entities/medical_document.dart';
import '../components/document_option_sheet.dart';
import '../components/document_picker_field.dart';
import '../components/document_type_icon.dart';
import '../../application/providers/documents_filter_controller.dart';
import '../../../appointments/application/providers/appointments_provider.dart'
    show appointmentsForLinkingProvider;
import '../../application/providers/linkable_appointments_provider.dart';

/// Open the documents filter (CM-34) as a bottom sheet.
///
/// Writes straight to [documentsFilterProvider], which the list's query is
/// built from, so it returns nothing. Every facet maps to one `GET
/// /patient/documents` parameter (§11.2): `doc_type` (one value — the
/// backend does not take a set), `person_id`, `date_from` / `date_to`,
/// `appointment_id`.
Future<void> showDocumentsFilterSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    title: 'Filter documents',
    builder: (sheetContext) =>
        DocumentsFilterBody(onDone: () => Navigator.of(sheetContext).pop()),
  );
}

class DocumentsFilterBody extends ConsumerWidget {
  const DocumentsFilterBody({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kept alive and loading while the sheet is open, for its picker.
    ref.watch(linkableAppointmentsProvider);
    final filters = ref.watch(documentsFilterProvider);
    final sort = ref.watch(documentsSortProvider);
    final controller = ref.read(documentsFilterProvider.notifier);
    final names = ref.watch(documentPersonNamesProvider);
    final personId = filters.personId;
    final personName = personId == null ? null : names[personId];
    final appointmentId = filters.appointmentId;
    final appointment = appointmentId == null
        ? null
        : ref.watch(linkableAppointmentByIdProvider(appointmentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Document type'),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final type in DocumentType.values)
              _ChoiceToggle(
                label: type.label,
                iconName: DocumentTypeIcon.of(type),
                semanticLabel: '${type.label} documents',
                isSelected: filters.type == type,
                onTap: () => controller.toggleType(type),
              ),
          ],
        ),
        SizedBox(height: 18.h),
        DocumentPickerField(
          label: 'Patient',
          value: personName ?? (personId == null ? null : 'One person'),
          placeholder: 'Everyone',
          iconName: PhIcon.folder,
          helperText: 'Only documents filed under one person',
          semanticLabel: 'Filter by patient: ${personName ?? 'everyone'}',
          onTap: () => _pickPerson(context, ref, personId),
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
          value: appointment?.fullLabel,
          placeholder: 'Any visit',
          iconName: PhIcon.calendarBlank,
          helperText: 'Only documents attached to one visit',
          semanticLabel:
              'Filter by linked appointment: '
              '${appointment?.fullLabel ?? 'any visit'}',
          onTap: () => _pickAppointment(context, ref, appointmentId),
        ),
        SizedBox(height: 18.h),
        // Every order the server offers (§11.2); the list's two pills are
        // the shortcuts for the first two.
        const _SectionLabel('Sort by'),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: [
            for (final option in DocumentSort.values)
              _ChoiceToggle(
                label: option.label,
                semanticLabel: 'Sort by ${option.label}',
                isSelected: sort == option,
                onTap: () => ref
                    .read(documentsSortProvider.notifier)
                    .update((_) => option),
              ),
          ],
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

  Future<void> _pickPerson(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final persons = ref.read(personSummariesProvider).valueOrNull ?? const [];
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
        for (final person in persons)
          DocumentOption(
            value: person.id,
            label: person.fullName,
            subtitle: person.relationLabel,
            iconName: PhIcon.folder,
          ),
      ],
    );
    if (picked == null) return;
    ref
        .read(documentsFilterProvider.notifier)
        .setPerson(picked == _anyValue ? null : picked);
  }

  Future<void> _pickAppointment(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    // Watched in build, so normally loaded; wait for it if not
    // (BL-REC-022).
    try {
      await ref
          .read(appointmentsForLinkingProvider.future)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Offline or slow: offer what there is.
    }
    if (!context.mounted) return;
    // Every visit, cancelled ones too — a document may already be linked to
    // one — each with its time, patient, booking reference and status.
    final appointments = ref.read(linkableAppointmentsProvider);
    final names = ref.read(documentPersonNamesProvider);
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
            subtitle: linkableAppointmentDetail(
              appointment,
              patientName: names[appointment.personId],
            ),
            iconName: PhIcon.calendarBlank,
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
      firstDay: earliestDocumentDate(now),
      lastDay: now,
    );
    if (picked == null) return;
    final controller = ref.read(documentsFilterProvider.notifier);
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

  static const String _anyValue = '__any__';
}

/// One single-select document-type chip.
/// One single-select chip — a document type or a sort order.
class _ChoiceToggle extends StatelessWidget {
  const _ChoiceToggle({
    required this.label,
    required this.semanticLabel,
    required this.isSelected,
    required this.onTap,
    this.iconName,
  });

  final String label;
  final String semanticLabel;
  final bool isSelected;
  final VoidCallback onTap;

  /// A leading [MedIcon] name (the type's glyph); none for a sort order.
  final String? iconName;

  @override
  Widget build(BuildContext context) {
    final icon = iconName;
    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
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
                  if (icon != null) ...[
                    AppIcon(
                      icon,
                      size: 16,
                      color: isSelected
                          ? AppColors.textOnBrand
                          : AppColors.textMuted,
                    ),
                    SizedBox(width: 8.w),
                  ],
                  Text(
                    label,
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
