/// Session `status` (§17).
enum SessionState {
  scheduled('scheduled'),
  open('open'),
  paused('paused'),
  closed('closed'),
  cancelled('cancelled');

  const SessionState(this.wire);

  final String wire;

  static SessionState fromWire(String? value) {
    for (final state in values) {
      if (state.wire == value) return state;
    }
    return scheduled;
  }
}

/// Session `queue_state` (§17).
enum QueueState {
  available('available'),
  consulting('consulting'),
  waiting('waiting'),
  onBreak('on_break');

  const QueueState(this.wire);

  final String wire;

  static QueueState fromWire(String? value) {
    for (final state in values) {
      if (state.wire == value) return state;
    }
    return available;
  }
}

/// The live queue for **one appointment** (§10.5): where the desk is, where
/// this patient's token is, and the backend's own wait estimate.
///
/// `estimatedWaitMinutes` is never computed in the app — it is the number
/// the API sent (`tokens_ahead × the doctor's minutes per patient`).
class QueueStatus {
  const QueueStatus({
    required this.sessionState,
    required this.queueState,
    required this.tokensAhead,
    required this.estimatedWaitMinutes,
    required this.updatedAt,
    this.currentToken,
    this.currentTokenNo,
    this.lastCalledToken,
    this.yourToken,
    this.yourTokenNo,
  });

  final SessionState sessionState;
  final QueueState queueState;

  /// Label now being seen, or null when nobody is.
  final String? currentToken;
  final int? currentTokenNo;
  final int? lastCalledToken;
  final String? yourToken;
  final int? yourTokenNo;
  final int tokensAhead;
  final int estimatedWaitMinutes;
  final DateTime updatedAt;

  /// "Doctor on a break" — §15.1.
  bool get isOnBreak =>
      sessionState == SessionState.paused || queueState == QueueState.onBreak;

  /// The desk has not opened yet (a session in the future).
  bool get isNotOpenYet => sessionState == SessionState.scheduled;

  bool get isOver =>
      sessionState == SessionState.closed ||
      sessionState == SessionState.cancelled;

  /// True when this patient's token is the one being seen.
  bool get isBeingSeen =>
      currentTokenNo != null &&
      yourTokenNo != null &&
      currentTokenNo == yourTokenNo;
}
