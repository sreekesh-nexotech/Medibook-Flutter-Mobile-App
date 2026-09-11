import 'package:flutter/material.dart';

/// Process-wide handles that genuinely have no better owner.
///
/// This file exists for one narrow job: giving **non-widget code** a way to
/// reach the running app. A repository that hits a hard 401, a push-notification
/// callback that must deep-link, a background timer whose slot hold expired —
/// none of them have a [BuildContext], and none of them should be handed one.
///
/// It is deliberately tiny. Global mutable state is a smell, so the rules are:
///
/// * **Keys only, never data.** App data lives in Riverpod providers; app
///   config lives in `app/config/env.dart`. Nothing else belongs here.
/// * **Read through the null-safe accessors** ([currentContext],
///   [navigator]), never `key.currentState!` — during a route transition or in
///   a widget test there may be no navigator, and a `!` there is a crash.
/// * **Prefer a `BuildContext`** whenever you have one. If a widget can reach
///   `Navigator.of(context)`, it must.
///
/// ## Wiring
///
/// [Globals.rootNavigatorKey] must be handed to the router so it points at the
/// real navigator:
///
/// ```dart
/// GoRouter(navigatorKey: Globals.rootNavigatorKey, routes: [...]);
/// ```
///
/// Until that is wired the accessors simply return null and callers take their
/// fallback path — they never throw.
abstract final class Globals {
  Globals._();

  /// The root navigator, shared with the router.
  ///
  /// Use for full-screen redirects that must escape a nested shell (a forced
  /// sign-out) and for dialogs raised from outside the widget tree.
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'medibookRootNavigator');

  /// The bottom-nav shell's navigator, when the shell is mounted. Lets a
  /// tab-local push stay inside its tab.
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'medibookShellNavigator');

  /// The messenger for framework `SnackBar`s.
  ///
  /// Medibook shows its own toast (`core/widgets/toast/`), which is the channel
  /// features should use. This key exists for the framework-level cases the
  /// toast cannot serve — for example a `MaterialBanner` raised before the
  /// `ToastHost` is mounted.
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>(debugLabel: 'medibookMessenger');

  /// The live root navigator, or null when nothing is mounted yet.
  static NavigatorState? get navigator => rootNavigatorKey.currentState;

  /// A context from the root navigator, or null. Safe to call from anywhere.
  static BuildContext? get currentContext => rootNavigatorKey.currentContext;

  /// True when there is a mounted navigator to drive.
  static bool get hasNavigator => navigator != null;

  /// Run [action] with the root navigator if there is one; otherwise do
  /// nothing and report it, so callers can branch without a null check.
  ///
  /// ```dart
  /// final handled = Globals.withNavigator((nav) => nav.pushNamed('/login'));
  /// if (!handled) pendingRedirect = AppRoutes.login;
  /// ```
  static bool withNavigator(void Function(NavigatorState navigator) action) {
    final state = navigator;
    if (state == null) return false;
    action(state);
    return true;
  }
}
