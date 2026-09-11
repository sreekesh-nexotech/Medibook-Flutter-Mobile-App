import 'package:flutter/material.dart';

import '../../app/localization/l10n.dart';
import 'app_confirm_dialog.dart';
import 'app_icon.dart';

/// Asks the user whether to discard unsaved work.
///
/// Returns true to **discard** (leave the screen), false or null to stay.
/// Worded around what is lost, per the rule in [showAppConfirmDialog].
///
/// ```dart
/// final discard = await showDiscardChangesDialog(context);
/// if (discard == true) Navigator.of(context).pop();
/// ```
Future<bool?> showDiscardChangesDialog(
  BuildContext context, {
  String? title,
  String? consequence,
  String? discardLabel,
  String? keepLabel,
}) {
  final strings = context.l10n;
  return showAppConfirmDialog(
    context,
    title: title ?? strings.unsavedChangesTitle,
    consequence: consequence ?? strings.unsavedChangesBody,
    confirmLabel: discardLabel ?? strings.discard,
    cancelLabel: keepLabel ?? strings.keepEditing,
    iconName: MedIcon.edit,
  );
}

/// Blocks a back gesture while a form has unsaved changes (audit §3.7.1 —
/// *"nothing warns about unsaved work"*: every edit form in the app could be
/// abandoned by a swipe with no prompt and no save).
///
/// Wrap the form's body. When [hasUnsavedChanges] is true the pop is
/// intercepted, [showDiscardChangesDialog] is shown, and the screen is popped
/// only if the user chooses Discard.
///
/// Built on [PopScope], so it catches **all three** ways out — the Android
/// hardware/gesture back, the iOS swipe-back, and a programmatic
/// `Navigator.pop` — which a plain "are you sure" button on the header cannot.
///
/// ```dart
/// AppUnsavedChangesGuard(
///   hasUnsavedChanges: controller.isDirty,
///   child: Scaffold(body: …),
/// )
/// ```
///
/// Two notes for callers:
/// * Keep [hasUnsavedChanges] honest. A guard that is always true trains users
///   to dismiss the dialog without reading it.
/// * A screen with a Save button should still call [onDiscard] or pop itself
///   after saving — the guard only handles *leaving without* saving.
class AppUnsavedChangesGuard extends StatelessWidget {
  const AppUnsavedChangesGuard({
    super.key,
    required this.child,
    required this.hasUnsavedChanges,
    this.onDiscard,
    this.title,
    this.consequence,
    this.discardLabel,
    this.keepLabel,
  });

  final Widget child;

  /// True while the form holds edits the user has not saved.
  final bool hasUnsavedChanges;

  /// Extra cleanup when the user confirms discarding (reset a controller,
  /// clear a draft). The pop happens either way.
  final VoidCallback? onDiscard;

  /// Overrides for the dialog's copy — use them when the screen can say
  /// something more specific than "you have unsaved changes"
  /// (e.g. "Discard this dependant?").
  final String? title;
  final String? consequence;
  final String? discardLabel;
  final String? keepLabel;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Only intercept when there is actually something to lose, so a clean
      // form keeps the instant, native-feeling back gesture.
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await showDiscardChangesDialog(
          context,
          title: title,
          consequence: consequence,
          discardLabel: discardLabel,
          keepLabel: keepLabel,
        );
        if (discard != true) return;
        onDiscard?.call();
        if (navigator.canPop()) navigator.pop();
      },
      child: child,
    );
  }
}
