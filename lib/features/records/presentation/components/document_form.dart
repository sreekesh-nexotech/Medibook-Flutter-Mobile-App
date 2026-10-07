import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/file_size.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_picker_sheet.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../common/attachments/application/providers/attachments_provider.dart';
import '../../../common/attachments/domain/entities/stored_file.dart';
import '../../../common/attachments/presentation/components/attachment_upload_tile.dart';
import '../../../common/persons/application/providers/persons_read_provider.dart';
import '../../../common/persons/domain/entities/person_summary.dart';
import '../../../support/application/providers/app_config_provider.dart';
import '../../application/providers/records_provider.dart';
import '../../application/states/document_form_state.dart';
import '../../domain/entities/medical_document.dart';
import '../../../appointments/application/providers/appointments_provider.dart'
    show appointmentsForLinkingProvider;
import '../../application/providers/documents_filter_controller.dart';
import '../../application/providers/linkable_appointments_provider.dart';
import 'document_option_sheet.dart';
import 'document_picker_field.dart';
import 'document_type_icon.dart';

/// The document metadata form — the substance of CM-33 (upload) and CM-35
/// (edit). Hosted by `DocumentUploadScreen` and by the edit sheet on
/// `DocumentDetailScreen`, both of which own the submit button.
///
/// Everything here is typed and goes to `POST` / `PATCH /patient/documents`:
/// the **type**, the **person** (required — the backend files every document
/// under someone), the **date**, free-text **notes** and the optional
/// **appointment link**. In create mode the file itself is picked and
/// uploaded through the shared [AttachmentUploadTile]; the file cannot be
/// swapped after creation (§11.2), so the edit form shows it read-only.
///
/// Validation: errors appear on submit **and** once a field has been left,
/// recomputed from the current value on every keystroke.
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
    _titleFocus.addListener(() {
      if (!_titleFocus.hasFocus) {
        _controller.markTouched(DocumentFormField.title);
      }
    });
    // Persons are usually loaded before this form opens, and `ref.listen`
    // only reports later changes — so the default is applied once here too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _applyDefaultPerson(ref.read(personSummariesProvider).valueOrNull);
    });
  }

  /// Default to the account holder, or the only person on the account — a
  /// form that starts answered where it can. Never overrides a choice.
  void _applyDefaultPerson(List<PersonSummary>? list) {
    if (list == null || list.isEmpty) return;
    final self = list.where((p) => p.isSelf).firstOrNull;
    _controller.applyDefaultPerson(
      self?.id ?? (list.length == 1 ? list.first.id : ''),
    );
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

  Future<void> _pickPerson(String current, List<PersonSummary> persons) async {
    final picked = await showDocumentOptionSheet<String>(
      context,
      title: 'Whose document is this?',
      selected: current,
      options: [
        for (final person in persons)
          DocumentOption(
            value: person.id,
            label: person.fullName,
            subtitle: person.relationLabel,
            iconName: PhIcon.folder,
          ),
      ],
    );
    if (picked != null) {
      _controller
        ..setPerson(picked)
        ..markTouched(DocumentFormField.person);
    }
  }

  Future<void> _pickDate(DateTime current) async {
    final now = DateTime.now();
    final picked = await showAppDatePickerSheet(
      context,
      title: 'Date on the document',
      initialDay: current,
      firstDay: earliestDocumentDate(now),
      lastDay: now,
    );
    if (picked == null) return;
    _controller
      ..setDocumentDate(picked)
      ..markTouched(DocumentFormField.documentDate);
  }

  Future<void> _pickAppointment(String? current) async {
    // The form watches the list (see build), so it is normally loaded; if
    // the patient taps first, wait for it rather than offer an empty choice
    // (BL-REC-022: a one-off read always found it empty).
    await _appointmentsLoaded();
    if (!mounted) return;
    // A visit that never happened (cancelled, no-show) is not offered,
    // unless it is the one already linked.
    final appointments = linkTargets(
      ref.read(linkableAppointmentsProvider),
      currentId: current,
    );
    final names = ref.read(documentPersonNamesProvider);
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
            subtitle: linkableAppointmentDetail(
              appointment,
              patientName: names[appointment.personId],
            ),
            iconName: PhIcon.calendarBlank,
          ),
      ],
    );
    if (picked == null) return;
    if (picked == _noAppointment) {
      _controller.setAppointment(null);
      return;
    }
    final chosen = ref.read(linkableAppointmentByIdProvider(picked));
    _controller.setAppointment(picked, label: chosen?.fullLabel);
  }

  static const String _noAppointment = '__none__';

  /// A linked visit whose details are not loaded (offline).
  static const String _linkedButUnnamed =
      "A linked visit (details load when you're back online)";

  Future<void> _appointmentsLoaded() async {
    try {
      await ref
          .read(appointmentsForLinkingProvider.future)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Offline or slow: offer what there is ("Not linked").
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentId = widget.documentId;
    final state = ref.watch(documentFormProvider(documentId));
    final persons = ref.watch(personSummariesProvider);
    final appointmentId = state.appointmentId;
    // Kept alive and loading while the form is open, for the link picker.
    ref.watch(linkableAppointmentsProvider);
    final linked = appointmentId == null
        ? null
        : ref.watch(linkableAppointmentByIdProvider(appointmentId));
    final existing = documentId == null
        ? null
        : ref.watch(documentProvider(documentId)).valueOrNull;
    final upload = ref.watch(
      attachmentUploadProvider(FileUploadPurpose.medicalDocument),
    );

    // Once persons load, default to the account holder or the only person
    // on the account — a form that starts answered where it can.
    ref.listen(
      personSummariesProvider,
      (previous, next) => _applyDefaultPerson(next.valueOrNull),
    );

    final personList = persons.valueOrNull ?? const <PersonSummary>[];
    final person = personList.where((p) => p.id == state.personId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isEditing) ...[
          AttachmentUploadTile(
            purpose: FileUploadPurpose.medicalDocument,
            title: 'File',
            // The limit is the server's setting, not a number in the app.
            helper:
                'A PDF or a photo — JPEG, PNG or HEIC, up to '
                '${formatSizeLimit(ref.watch(uploadMaxBytesProvider))}',
            enabled: !state.isSaving,
            errorText: state.showErrorFor(DocumentFormField.file)
                ? state.fileError(
                    hasFile: upload.readyFileId != null,
                    needsFile: true,
                  )
                : null,
          ),
          SizedBox(height: 16.h),
        ],
        AppTextField(
          label: 'Document title',
          controller: _title,
          focusNode: _titleFocus,
          hintText: 'Blood test report',
          maxLength: 200,
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
          value: state.docType.label,
          iconName: DocumentTypeIcon.of(state.docType),
          semanticLabel: 'Document type: ${state.docType.label}',
          onTap: () => _pickType(state.docType),
        ),
        SizedBox(height: 16.h),
        _PersonField(
          persons: persons,
          selected: person,
          errorText: state.showErrorFor(DocumentFormField.person)
              ? state.personError
              : null,
          onTap: personList.isEmpty
              ? null
              : () => _pickPerson(state.personId, personList),
          onRetry: () => ref.invalidate(personSummariesProvider),
          onAddFamilyMember: () => context.push(AppRoutes.dependants),
        ),
        SizedBox(height: 16.h),
        DocumentPickerField(
          label: 'Date on the document',
          value: AppDates.dayMonthYear(state.documentDate),
          iconName: PhIcon.calendarBlank,
          errorText: state.showErrorFor(DocumentFormField.documentDate)
              ? state.dateError()
              : null,
          helperText: 'The day the test or consultation happened',
          semanticLabel:
              'Date on the document: '
              '${AppDates.dayMonthYear(state.documentDate)}',
          onTap: () => _pickDate(state.documentDate),
        ),
        SizedBox(height: 16.h),
        DocumentPickerField(
          label: 'Linked appointment (optional)',
          // A link whose visit cannot be named right now (offline) is still a
          // link: never show it as "Not linked" (Screen Coverage pass).
          value:
              linked?.fullLabel ??
              state.appointmentLabel ??
              (appointmentId == null ? null : _linkedButUnnamed),
          placeholder: 'Not linked',
          iconName: PhIcon.calendarBlank,
          errorText: state.appointmentError,
          helperText: 'Your own note — the hospital does not see it',
          semanticLabel:
              'Linked appointment: '
              '${linked?.fullLabel ?? state.appointmentLabel ?? (appointmentId == null ? 'not linked' : _linkedButUnnamed)}',
          onTap: () => _pickAppointment(state.appointmentId),
        ),
        SizedBox(height: 16.h),
        AppTextField(
          label: 'Notes (optional)',
          controller: _notes,
          hintText: 'Fasting sample, collected at home',
          maxLines: 4,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          errorText: state.notesError,
          helperText: 'Anything you want to remember about this document',
          semanticLabel: 'Notes about this document',
          onChanged: _controller.setNotes,
        ),
        if (_isEditing && existing != null) ...[
          SizedBox(height: 20.h),
          _ExistingFileRow(file: existing.file),
        ],
      ],
    );
  }
}

/// The "whose document" picker with its three honest states: loading,
/// failed (retry), and empty — the account has nobody to file a document
/// under, which on this backend means "add a family member first".
class _PersonField extends StatelessWidget {
  const _PersonField({
    required this.persons,
    required this.selected,
    required this.errorText,
    required this.onTap,
    required this.onRetry,
    required this.onAddFamilyMember,
  });

  final AsyncValue<List<PersonSummary>> persons;
  final PersonSummary? selected;
  final String? errorText;
  final VoidCallback? onTap;
  final VoidCallback onRetry;
  final VoidCallback onAddFamilyMember;

  @override
  Widget build(BuildContext context) {
    return persons.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Patient',
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.medium,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 8.h),
          const AppSkeletonLine(height: 52),
        ],
      ),
      error: (error, _) => DocumentPickerField(
        label: 'Patient',
        value: null,
        placeholder: 'Could not load your family members',
        iconName: PhIcon.warningCircleFill,
        errorText: 'Tap to try again',
        semanticLabel: 'Patient list failed to load. Tap to retry.',
        onTap: onRetry,
      ),
      data: (list) {
        if (list.isEmpty) {
          return Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: AppRadii.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a family member first',
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.semibold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Every document is filed under a person, and there is '
                  'nobody on your account yet.',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    height: 1.45,
                    color: AppColors.textBody,
                  ),
                ),
                SizedBox(height: 10.h),
                AppButton(
                  label: 'Add a family member',
                  size: AppButtonSize.sm,
                  pill: true,
                  onPressed: onAddFamilyMember,
                ),
              ],
            ),
          );
        }
        return DocumentPickerField(
          label: 'Patient',
          value: selected?.fullName,
          placeholder: 'Select a person',
          iconName: PhIcon.folder,
          errorText: errorText,
          // The server's relation for them ("Wife", "Son"), not "Family
          // member" for everyone.
          helperText: selected?.relationLabel,
          semanticLabel: 'Patient: ${selected?.fullName ?? 'not selected'}',
          onTap: onTap,
        );
      },
    );
  }
}

/// The file behind a document being edited — read-only, because the file
/// cannot be swapped after creation (§11.2).
class _ExistingFileRow extends StatelessWidget {
  const _ExistingFileRow({required this.file});

  final DocumentFile file;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadii.md,
        border: Border.all(color: AppColors.border, width: 1.w),
      ),
      child: Row(
        children: [
          AppIcon(PhIcon.folder, size: 20, color: AppColors.textMuted),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.originalName.isEmpty
                      ? 'Attached file'
                      : file.originalName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.medium,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${formatFileSize(file.sizeBytes)} · The file cannot be '
                  'changed; delete the document to replace it',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
