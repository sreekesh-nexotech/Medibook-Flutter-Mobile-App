import 'package:flutter_test/flutter_test.dart';
import 'package:medibook/features/profile/application/providers/dependant_form_controller.dart';
import 'package:medibook/features/profile/domain/entities/person.dart';

/// `guardian_note` (§6.1) is now shown and edited: it reaches the POST body,
/// a PATCH sends it only when it changed, and emptying it clears it.
void main() {
  DependantFormState form({String guardianNote = ''}) =>
      DependantFormState.from(
        firstName: 'Ishaan',
        lastName: 'Varma',
        relation: PersonRelation.child,
        dateOfBirth: DateTime(2019, 12, 5),
        gender: Gender.male,
        bloodGroup: 'AB+',
        allergies: const <String>[],
        phone: '',
        guardianNote: guardianNote,
        isSelf: false,
        version: 1,
      );

  test('a new family member is created with the note', () {
    final state = form().copyWith(guardianNote: '  Mother brings him in. ');
    expect(state.toCreateDraft().guardianNote, 'Mother brings him in.');
    expect(form().toCreateDraft().guardianNote, isNull);
  });

  test('a PATCH sends the note only when it changed', () {
    final saved = form(guardianNote: 'Mother brings him in.');
    expect(saved.isDirty, isFalse);
    expect(saved.toPatchDraft().guardianNote, isNull);
    expect(saved.toPatchDraft().clearGuardianNote, isFalse);

    final edited = saved.copyWith(guardianNote: 'Father brings him in.');
    expect(edited.isDirty, isTrue);
    expect(edited.toPatchDraft().guardianNote, 'Father brings him in.');
  });

  test('emptying the note clears it on the server', () {
    final cleared = form(
      guardianNote: 'Mother brings him in.',
    ).copyWith(guardianNote: '');
    final draft = cleared.toPatchDraft();
    expect(draft.guardianNote, isNull);
    expect(draft.clearGuardianNote, isTrue);
    expect(draft.isEmpty, isFalse);
  });

  test('a note over the server limit is refused before sending', () {
    final controller = DependantFormController(form());
    controller.setGuardianNote('x' * (guardianNoteMaxLength + 1));
    expect(controller.validate(), isFalse);
    controller.setGuardianNote('x' * guardianNoteMaxLength);
    expect(controller.validate(), isTrue);
  });
}
