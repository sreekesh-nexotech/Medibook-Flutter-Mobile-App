import '../../utils/date_utils.dart';

/// Live token progress at a doctor's desk (CM-09, CM-24).
///
/// This is what makes the Home "Your Token" card and the queue screen honest:
/// the app can say *which token is being seen now* and *roughly how long until
/// yours*, instead of only showing the number on the ticket.
///
/// Presentation view-model — immutable, no logic beyond the derived labels.
class QueueStatus {
  const QueueStatus({
    required this.doctorId,
    required this.currentToken,
    required this.lastCalledToken,
    required this.estimatedWaitMinutes,
    required this.updatedAt,
    this.isPaused = false,
  });

  final String doctorId;

  /// The token the doctor is with right now ("A-23").
  final String currentToken;

  /// The last token called to the room — usually the same as [currentToken],
  /// but ahead of it when someone did not answer.
  final String lastCalledToken;

  /// Minutes the clinic estimates per remaining patient ahead of you.
  final int estimatedWaitMinutes;

  /// When the clinic last published this. Drives the "updated 2 minutes ago"
  /// line, which is what stops a stale queue reading as a live one.
  final DateTime updatedAt;

  /// True when the doctor is on a break — the queue is not moving.
  final bool isPaused;

  /// "Now seeing A-23".
  String get nowServingLabel => 'Now seeing $currentToken';

  /// "~20 min wait" / "Next" / "Paused".
  String get waitLabel {
    if (isPaused) return 'Paused';
    if (estimatedWaitMinutes <= 0) return 'Next';
    return '~$estimatedWaitMinutes min wait';
  }

  /// "Updated 2 minutes ago".
  String get updatedLabel => 'Updated ${AppDates.relativeAgo(updatedAt)}';

  /// True when the published status is older than 10 minutes and should be
  /// shown as possibly out of date.
  bool get isStale =>
      DateTime.now().difference(updatedAt) > const Duration(minutes: 10);

  /// How many patients are between [currentToken] and [myToken].
  ///
  /// Returns null when either token is not in the `A-NN` shape, so the UI
  /// shows the raw tokens rather than a wrong number.
  int? positionsAhead(String myToken) {
    final mine = _tokenNumber(myToken);
    final current = _tokenNumber(currentToken);
    if (mine == null || current == null) return null;
    final ahead = mine - current;
    return ahead < 0 ? 0 : ahead;
  }

  /// Estimated wait for [myToken], or null when it cannot be computed.
  Duration? estimatedWaitFor(String myToken) {
    final ahead = positionsAhead(myToken);
    if (ahead == null) return null;
    return Duration(minutes: ahead * estimatedWaitMinutes);
  }

  static int? _tokenNumber(String token) {
    final match = RegExp(r'(\d+)$').firstMatch(token.trim());
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  QueueStatus copyWith({
    String? doctorId,
    String? currentToken,
    String? lastCalledToken,
    int? estimatedWaitMinutes,
    DateTime? updatedAt,
    bool? isPaused,
  }) {
    return QueueStatus(
      doctorId: doctorId ?? this.doctorId,
      currentToken: currentToken ?? this.currentToken,
      lastCalledToken: lastCalledToken ?? this.lastCalledToken,
      estimatedWaitMinutes: estimatedWaitMinutes ?? this.estimatedWaitMinutes,
      updatedAt: updatedAt ?? this.updatedAt,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}
