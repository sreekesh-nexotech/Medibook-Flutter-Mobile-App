/// The session as one WebSocket owner sees it.
///
/// A socket presents the access token in its handshake, and the server
/// refuses the handshake (HTTP 403) when that token has expired. The owner
/// then needs a fresh token — but so does every REST call that failed at the
/// same moment, and the API client is already refreshing for them. Refresh
/// tokens rotate (§1.4), so a second refresh is at best wasted and at worst
/// revokes the session.
///
/// This remembers which token the socket last presented, so that
/// [refreshIfStale] only asks for a new one when nobody else already has.
/// The dependencies are plain functions so `core/` does not import a feature.
class WsSession {
  WsSession({
    required Future<String?> Function() accessToken,
    required Future<void> Function() refresh,
  }) : _accessToken = accessToken,
       _refresh = refresh;

  final Future<String?> Function() _accessToken;
  final Future<void> Function() _refresh;

  /// The token handed to the most recent handshake.
  String? _presented;

  /// The current access token, for a [WsClient] handshake.
  Future<String?> accessToken() async => _presented = await _accessToken();

  /// Call after a refused handshake. Refreshes the session unless the stored
  /// token has already been replaced since the socket presented it.
  Future<void> refreshIfStale() async {
    final presented = _presented;
    final current = await _accessToken();
    final alreadyReplaced =
        presented != null &&
        current != null &&
        current.isNotEmpty &&
        current != presented;
    if (alreadyReplaced) return;
    await _refresh();
  }
}
