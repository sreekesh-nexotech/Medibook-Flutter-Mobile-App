import 'package:flutter/widgets.dart';

/// The [FocusNode]s of one form, plus the blur reporting the auth forms need.
///
/// Two audit findings meet here:
///
/// * **§3.5.4** — a field has to be re-validated once the user has dealt with
///   it, and "left the field" is one of the two ways that happens (the other
///   is submitting). So every node reports its blur to [onBlur], which the
///   form controller turns into a re-check.
/// * **Keyboard flow** — `textInputAction: next` is only half of moving
///   through a form; something has to hold the node to hand focus *to*. This
///   owns them, keyed by the same field names the controller validates by, so
///   a screen writes `focus.requestFocus(SignupFields.lastName)` and nothing
///   else.
///
/// Nodes are created on first use and disposed together:
///
/// ```dart
/// late final FieldFocusGroup _focus = FieldFocusGroup(
///   onBlur: (field) => ref
///       .read(signupFormControllerProvider.notifier)
///       .onBlur(field, _controllers[field]?.text ?? ''),
/// );
///
/// @override
/// void dispose() {
///   _focus.dispose();
///   super.dispose();
/// }
/// ```
class FieldFocusGroup {
  FieldFocusGroup({required this.onBlur});

  /// Called with the field key when that field loses focus.
  final void Function(String field) onBlur;

  final Map<String, FocusNode> _nodes = <String, FocusNode>{};
  final Map<String, VoidCallback> _listeners = <String, VoidCallback>{};

  /// The node for [field], created on first call and reused after that — so
  /// calling this from `build` is safe.
  FocusNode node(String field) {
    final existing = _nodes[field];
    if (existing != null) return existing;

    final created = FocusNode(debugLabel: field);
    void listener() {
      if (!created.hasFocus) onBlur(field);
    }

    created.addListener(listener);
    _nodes[field] = created;
    _listeners[field] = listener;
    return created;
  }

  /// Move the keyboard to [field] — what a `next` action does.
  void requestFocus(String field) => node(field).requestFocus();

  /// Drop focus, closing the keyboard. Called before a submit so the last
  /// field blurs (and re-validates) like every other one.
  void unfocus() {
    for (final node in _nodes.values) {
      if (node.hasFocus) node.unfocus();
    }
  }

  void dispose() {
    for (final entry in _nodes.entries) {
      final listener = _listeners[entry.key];
      if (listener != null) entry.value.removeListener(listener);
      entry.value.dispose();
    }
    _nodes.clear();
    _listeners.clear();
  }
}
