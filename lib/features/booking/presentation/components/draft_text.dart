import 'package:flutter/widgets.dart';

/// Owns the [TextEditingController] of a text box whose text also lives in
/// state above it — the booking draft's notes, a search query.
///
/// Building a fresh controller from that state on every rebuild, and keying
/// the box on "is it empty" so that a cleared draft resets it, replaced the
/// box after the first character (dropping focus, so the rest of what was
/// typed went nowhere) and pushed the stored, trimmed text back into it
/// (deleting a space the moment it was typed).
///
/// Here the box keeps its own text while the user types. The state above is
/// followed only when it changes from outside — a cleared search, a new
/// booking — which is the one case the old key was there for.
class DraftText extends StatefulWidget {
  const DraftText({super.key, required this.value, required this.builder});

  /// The text as the state above holds it. It may be the box's text trimmed.
  final String value;

  /// Builds the box around the controller this widget owns.
  final Widget Function(BuildContext context, TextEditingController controller)
  builder;

  @override
  State<DraftText> createState() => _DraftTextState();
}

class _DraftTextState extends State<DraftText> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant DraftText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // While the user types, the state above is this box's own text (as typed,
    // or trimmed), so there is nothing to do. Anything else came from outside.
    final text = _controller.text;
    if (widget.value != text && widget.value != text.trim()) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
