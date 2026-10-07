import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../utils/logger.dart';

/// One frame from a Medibook WebSocket (`FLUTTER_API_INTEGRATION.md` §15):
/// `{ "type": "…", "data": { }, "ts": "…" }`.
class WsFrame {
  const WsFrame({required this.type, required this.data, this.timestamp});

  factory WsFrame.parse(Object? raw) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) {
      throw FormatException('not a frame: ${decoded.runtimeType}');
    }
    final map = decoded.cast<String, Object?>();
    final data = map['data'];
    final ts = map['ts'];
    return WsFrame(
      type: map['type']?.toString() ?? '',
      data: data is Map ? data.cast<String, Object?>() : const {},
      timestamp: ts is String ? DateTime.tryParse(ts) : null,
    );
  }

  final String type;
  final Map<String, Object?> data;
  final DateTime? timestamp;
}

/// Why a connection closed, so the caller knows whether to refresh the token
/// before reconnecting.
enum WsCloseReason {
  /// 4401 — token missing, invalid or expired: refresh, then reconnect.
  unauthorized,

  /// 4408 — idle for 5 minutes.
  idle,

  /// The app closed it.
  local,

  /// Anything else (network drop, server restart).
  other,
}

/// The server answered the upgrade with an HTTP status instead of accepting
/// it. On the live server this — `403`, not a `4401` close frame — is how a
/// missing, invalid or expired access token is refused, because the socket is
/// rejected before it is accepted. The owner refreshes the session and tries
/// once more.
class WsHandshakeRefused implements Exception {
  const WsHandshakeRefused(this.message);

  final String message;

  @override
  String toString() => 'WsHandshakeRefused: $message';
}

/// A push-only WebSocket connection to one Medibook channel.
///
/// Implements §15: the access token goes in the **subprotocol**
/// (`bearer, <access>`), a `{"type":"ping"}` goes out every 30 s, `pong`
/// frames are swallowed, and the close codes 4401 / 4408 are surfaced as
/// [WsCloseReason] so the owner can reconnect with a fresh token.
///
/// The owner (a Riverpod notifier) is responsible for reconnecting; this
/// class never reconnects on its own, so a signed-out user cannot leave a
/// socket retrying in the background.
class WsClient {
  WsClient({
    required this.url,
    required Future<String?> Function() accessToken,
    bool allowBadCertificate = false,
  }) : _accessToken = accessToken,
       _allowBadCertificate = allowBadCertificate;

  static const Duration pingInterval = Duration(seconds: 30);
  static const int closeUnauthorized = 4401;
  static const int closeIdle = 4408;

  /// Absolute `wss://…` URL.
  final String url;
  final Future<String?> Function() _accessToken;
  final bool _allowBadCertificate;

  WebSocketChannel? _channel;
  Timer? _ping;
  final StreamController<WsFrame> _frames =
      StreamController<WsFrame>.broadcast();
  final StreamController<WsCloseReason> _closed =
      StreamController<WsCloseReason>.broadcast();

  Stream<WsFrame> get frames => _frames.stream;
  Stream<WsCloseReason> get closed => _closed.stream;
  bool get isConnected => _channel != null;

  /// Open the socket. Throws a [StateError] when there is no token to
  /// present and [WsHandshakeRefused] when the server refuses the upgrade.
  Future<void> connect() async {
    if (_channel != null) return;
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      throw StateError('cannot open $url without an access token');
    }
    final client = HttpClient();
    if (_allowBadCertificate) {
      client.badCertificateCallback = (cert, host, port) => true;
    }
    final WebSocket socket;
    try {
      socket = await WebSocket.connect(
        url,
        protocols: ['bearer', token],
        customClient: client,
      );
    } on WebSocketException catch (error) {
      // "… was not upgraded to websocket, HTTP status code: 403".
      if (error.message.contains('was not upgraded')) {
        throw WsHandshakeRefused(error.message);
      }
      rethrow;
    }
    final channel = IOWebSocketChannel(socket);
    _channel = channel;
    _ping = Timer.periodic(pingInterval, (_) => _send({'type': 'ping'}));
    channel.stream.listen(
      (raw) {
        try {
          final frame = WsFrame.parse(raw);
          if (frame.type == 'pong') return;
          _frames.add(frame);
        } on FormatException catch (error) {
          AppLogger.warning('Bad WS frame', name: 'ws', error: error);
        }
      },
      onError: (Object error) {
        AppLogger.warning('WS error on $url', name: 'ws', error: error);
        _teardown(WsCloseReason.other);
      },
      onDone: () {
        final code = channel.closeCode;
        _teardown(switch (code) {
          closeUnauthorized => WsCloseReason.unauthorized,
          closeIdle => WsCloseReason.idle,
          _ => WsCloseReason.other,
        });
      },
      cancelOnError: true,
    );
    AppLogger.info('WS connected $url', name: 'ws');
  }

  void _send(Map<String, Object?> frame) {
    try {
      _channel?.sink.add(jsonEncode(frame));
    } catch (error) {
      AppLogger.warning('WS send failed', name: 'ws', error: error);
    }
  }

  void _teardown(WsCloseReason reason) {
    if (_channel == null) return;
    _ping?.cancel();
    _ping = null;
    _channel = null;
    if (!_closed.isClosed) _closed.add(reason);
    AppLogger.info('WS closed $url ($reason)', name: 'ws');
  }

  /// Close the socket from our side.
  Future<void> disconnect() async {
    final channel = _channel;
    _ping?.cancel();
    _ping = null;
    _channel = null;
    await channel?.sink.close();
    if (channel != null && !_closed.isClosed) _closed.add(WsCloseReason.local);
  }

  Future<void> dispose() async {
    await disconnect();
    await _frames.close();
    await _closed.close();
  }
}
