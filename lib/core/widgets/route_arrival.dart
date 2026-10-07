import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The location of the screen on top of [matches], including one opened with
/// `push` (which go_router keeps as a nested match list).
String topLocationOf(RouteMatchList matches) {
  if (matches.isEmpty) return '';
  final last = matches.matches.last;
  return last is ImperativeRouteMatch
      ? topLocationOf(last.matches)
      : matches.uri.path;
}

/// Calls [onArrive] every time the screen this widget lives in is navigated
/// *back* to: its tab is selected again, a link lands on it, or the screen
/// that was opened over it is closed.
///
/// Why it exists: a screen stays built while something else is on top of it
/// (the four tabs live in an indexed stack; a list stays under its detail),
/// so it would otherwise keep whatever it loaded the first time — a booking
/// made elsewhere did not show in Appointments until the patient pulled to
/// refresh. A screen that shows server data re-reads it in [onArrive].
///
/// It does **not** fire when the screen is first opened: that is the screen's
/// normal load. It is not for forms — re-reading would wipe what the patient
/// has typed — nor for anything where a re-read has a side effect.
///
/// `AppRefreshIndicator` includes one, so a screen with pull-to-refresh needs
/// nothing more.
class RouteArrival extends StatefulWidget {
  const RouteArrival({super.key, required this.onArrive, required this.child});

  /// Re-read this screen's data. Errors are the callee's to surface.
  final void Function() onArrive;

  final Widget child;

  @override
  State<RouteArrival> createState() => _RouteArrivalState();
}

class _RouteArrivalState extends State<RouteArrival> {
  GoRouterDelegate? _delegate;

  /// This screen's own location, captured once.
  String? _mine;

  /// The location that was on top the last time the router changed.
  String? _lastTop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_delegate != null) return;
    // No router (a widget test pumping the screen alone): stay inert.
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    try {
      _mine = GoRouterState.of(context).uri.path;
    } on GoError {
      return;
    }
    _delegate = router.routerDelegate..addListener(_onRouteChanged);
    _lastTop = topLocationOf(router.routerDelegate.currentConfiguration);
  }

  void _onRouteChanged() {
    final delegate = _delegate;
    if (delegate == null) return;
    final top = topLocationOf(delegate.currentConfiguration);
    if (top == _lastTop) return;
    _lastTop = top;
    if (top != _mine) return;
    // After the frame: the callee changes providers, which must not happen
    // while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onArrive();
    });
  }

  @override
  void dispose() {
    _delegate?.removeListener(_onRouteChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
