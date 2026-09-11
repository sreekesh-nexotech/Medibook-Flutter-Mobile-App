import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/medical_record.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/mock_data/stores/dependants_store.dart';
import '../../../../core/mock_data/stores/documents_store.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_stub_notice.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/document_form_controller.dart';
import '../controllers/linkable_appointments_provider.dart';
import 'document_option_sheet.dart';
import 'document_picker_field.dart';
import 'document_type_icon.dart';

/// The document metadata form — the substance of CM-33 (upload) and CM-35
/// (edit). Hosted by `DocumentUploadScreen` and by the edit sheet on
/// `DocumentDetailScreen`, both of which own the submit button.
///
/// Everything the form collects is real, typed data written to
/// `documentsStoreProvider`: the document **type**, the **patient** it belongs
/// to, the **date** it was recorded (a `DateTime`, picked from the app's month
/// calendar), free-text **notes** and an optional **link to an appointment**.
///
/// The file itself is the one thing that cannot be real here: this build ships
/// no file-picker, storage or share package, so the "Choose file" control
/// declares itself stubbed instead of pretending. Everything around it is
/// wired, so attaching a real file later is a one-field change.
///
/// Validation: errors appear on submit **and** once a field has been left, and
/// are recomputed from the current value on every keystroke — so an error
/// clears when the value is actually fixed, not on the first keypress
/// (audit §3.5.4).
class DocumentForm extends ConsumerStatefulWidget {
  const DocumentForm({super.key, this.documentId});

  /// The document being edited, or null when creating one.
  final String? documentId;

  @override
  ConsumerState<DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends ConsumerState<DocumentForm> {
  late final TextEditingController _title;
  late final TextEditingController _notes;
  final FocusNode _titleFocus = FocusNode();

  bool get _isEditing => widget.documentId != null;

  DocumentFormController get _controller =>
      ref.read(documentFormProvider(widget.documentId).notifier);

  @override
  void initState() {
    super.initState();
    final initial = ref.read(documentFormProvider(widget.documentId));
    _title = TextEditingController(text: initial.title);
    _notes = TextEditingController(text: initial.notes);
    // Reveal the title error when the user leaves the field, not while they
    // are still typing their first character.
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) {
        _controller.markTouched(DocumentFormField.title);
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _pickType(DocumentType current) async {
    final picked = await showDocumentOptionSheet<DocumentType>(
      context,
      title: 'Document type',
      selected: current,
      options: [
        for (final type in DocumentType.values)
          DocumentOption(
            value: type,
            label: type.label,
            iconName: DocumentTypeIcon.of(type),
          ),
      ],
    );
    if (picked != null) _controller.setType(picked);
  }

  Future<void> _pickPatient(String current) async {
    final patients = ref.read(patientsProvider);
    final picked = await showDocumentOptionSheet<String>(
      context,
      title: 'Whose document is this?',
      selected: current,
      options: [
        for (final patient in patients)
          DocumentOption(
            value: patient.id,
            label: patient.name,
            subtitle: '${patient.relation} · ${patient.meta}',
            iconName: MedIcon.records,
          ),
      ],
    );
    if (picked != null) _controller.setPatient(picked);
  }

  Future<void> _pickDate(DateTime current) async {
    final now = DateTime.now();
    final picked = await showAppDatePickerSheet(
      context,
      title: 'Date on the document',
      initialDay: current,
      // A document cannot have been recorded in the future, so the calendar
      // cannot offer one.
      firstDay: DateTime(now.year - 10, now.month, now.day),
      lastDay: now,
    );
    if (picked == null) return;
    _controller
      ..setRecordedAt(picked)
      ..markTouched(DocumentFormField.recordedAt);
  }

  Future<void> _pickAppointment(String? current) async {
    final appointments = ref.read(linkableAppointmentsProvider);
    final picked = await showDocumentOptionSheet<String>(
      context,
      title: 'Link an appointment',
      selected: current ?? _noAppointment,
      options: [
        const DocumentOption(
          value: _noAppointment,
          label: 'Not linked',
          subtitle: 'This document stands on its own',
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
    if (picked == _noAppointment) {
      _controller.setAppointment(null);
      return;
    }
    final chosen = ref.read(linkableAppointmentByIdProvider(picked));
    _controller.setAppointment(
      picked,
      label: chosen?.label,
      doctorName: chosen?.doctorName,
      hospitalName: chosen?.hospitalName,
    );
  }

  /// Sentinel for the "Not linked" row — `showDocumentOptionSheet` returns null
  /// for a dismissed sheet, so "no appointment" needs a value of its own.
  static const String _noAppointment = '__none__';

  @override
  Widget build(BuildContext context) {
    final documentId = widget.documentId;
    final state = ref.watch(documentFormProvider(documentId));
    final patient = ref.watch(patientByIdProvider(state.patientId));
    final appointmentId = state.appointmentId;
    final linked = appointmentId == null
        ? null
        : ref.watch(linkableAppointmentByIdProvider(appointmentId));
    // In edit mode the file (if any) comes from the stored document, which is
    // the only thing that knows about it.
    final existing = documentId == null
        ? null
        : ref.watch(documentByIdProvider(documentId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Document title',
          controller: _title,
          focusNode: _titleFocus,
          hintText: 'Blood test report',
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          semanticLabel: 'Document title',
          errorText: state.showErrorFor(DocumentFormField.title)
              ? state.titleError
              : null,
          onChanged: _controller.setTitle,
        ),
        SizedBox(height: 16.h),
        DocumentPickerField(
          label: 'Document type',
          value: state.type.label,
          iconName: DocumentTypeIcon.of(state.type),
          semanticLabel: 'Document type: ${state.type.label}',
          onTap: () => _pickType(state.type),
        ),
        SizedBox(height: 16.h),
        DocumentPickerField(
          label: 'Patient',
          value: patient?.name,
          placeholder: 'Select a patient',
          iconName: MedIcon.records,
          helperText: patient == null
              ? null
              : '${patient.relation} · ${patient.meta}',
          semanticLabel: 'Patient: ${patient?.name ?? 'not selected'}',
          onTap: () => _pickPatient(state.patientId),
        ),
        SizedBox(height: 16.h),
        DocumentPickerField(
          label: 'Date on the document',
          value: AppDates.dayMonthYear(state.recordedAt),
          iconName: MedIcon.calendar,
          enabled: !_isEditing,
          errorText: state.showErrorFor(DocumentFormField.recordedAt)
              ? state.dateError()
              : null,
          helperText: _isEditing
              ? 'The recorded date is fixed once a document is saved'
              : 'The day the test or consultation happened',
          semanticLabel: _isEditing
              ? 'Date on the document, ${AppDates.dayMonthYear(state.recordedAt)}, '
                    'cannot be changed after saving'
              : 'Date on the document: '
                    '${AppDates.dayMonthYear(state.recordedAt)}',
          onTap: () => _pickDate(state.recordedAt),
        ),
        SizedBox(height: 16.h),
        DocumentPickerField(
          label: 'Linked appointment (optional)',
          value: linked?.label ?? state.appointmentLabel,
          placeholder: 'Not linked',
          iconName: MedIcon.calendar,
          enabled: !_isEditing,
          helperText: _isEditing
              ? 'The appointment link is fixed once a document is saved'
              : 'Attach it to a visit so it shows on that appointment',
          semanticLabel:
              'Linked appointment: '
              '${linked?.label ?? state.appointmentLabel ?? 'not linked'}',
          onTap: () => _pickAppointment(state.appointmentId),
        ),
        SizedBox(height: 16.h),
        AppTextField(
          label: 'Notes (optional)',
          controller: _notes,
          hintText: 'Fasting sample, collected at home',
          maxLines: 4,
          maxLength: 240,
          textCapitalization: TextCapitalization.sentences,
          helperText: 'Anything you want to remember about this document',
          semanticLabel: 'Notes about this document',
          onChanged: _controller.setNotes,
        ),
        SizedBox(height: 20.h),
        _FileRow(
          fileName: existing?.fileName ?? '',
          fileSizeLabel: existing?.fileSizeLabel ?? '—',
        ),
      ],
    );
  }
}

/// The file slot. There is no file-picker package in this build and none may be
/// added, so this control says so rather than reporting a file it never moved.
/// The metadata around it is real, which is what makes wiring a picker later a
/// small change.
class _FileRow extends ConsumerWidget {
  const _FileRow({required this.fileName, required this.fileSizeLabel});

  final String fileName;
  final String fileSizeLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFile = fileName.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.md,
        border: Border.all(color: AppColors.border, width: 1.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppIcon(MedIcon.records, size: 20, color: AppColors.textMuted),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasFile ? fileName : 'No file attached',
                      style: AppText.poppins(
                        size: AppFontSize.base,
                        weight: AppText.medium,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      hasFile
                          ? fileSizeLabel
                          : 'The details you enter are saved either way',
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          AppButton(
            label: hasFile ? 'Replace file' : 'Choose file',
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.sm,
            pill: true,
            fullWidth: true,
            stubbed: true,
            semanticLabel: 'Choose a file — stubbed in this demo',
            onPressed: () => showStubbedToast(context, ref, 'Choosing a file'),
          ),
        ],
      ),
    );
  }
}
