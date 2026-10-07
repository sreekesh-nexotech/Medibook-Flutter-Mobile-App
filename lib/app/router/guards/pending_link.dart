import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A link the patient opened before the app could show it: at a cold start
/// (the session is still being read) or while signed out. Without it the
/// splash and the sign-in screen both ended on Home and the link was lost
/// (CL NAV-003, NAV-005).
class PendingLink {
  String? _location;

  /// Remember [location] to open once signed in.
  void remember(String location) => _location = location;

  /// The remembered location, still kept.
  String? peek() => _location;

  /// The remembered location, now forgotten — it is opened once.
  String? take() {
    final location = _location;
    _location = null;
    return location;
  }
}

/// App-lifetime holder; the router writes it, the sign-in screens read it.
final pendingLinkProvider = Provider<PendingLink>((ref) => PendingLink());
