import '../../../../core/error/failure.dart';
import '../../domain/entities/queue_status.dart';

/// The state of the `/ws/patient/session/{appointment_id}` connection
/// (§15.1), so the screen can say whether the numbers are live.
enum LiveQueueConnection {
  /// Not opened yet, or opening.
  connecting,

  /// Frames are flowing.
  live,

  /// Dropped; a reconnect is scheduled.
  reconnecting,

  /// Gave up (too many drops, signed out, or the socket refused). The REST
  /// reading is still shown and pull-to-refresh still works.
  offline,
}

/// The live-queue screen's state: the latest REST reading (§10.5), the
/// socket status and the "it's your turn" flag from a `token.called` frame.
///
/// Immutable; every update goes through [copyWith].
class LiveQueueState {
  const LiveQueueState({
    this.queue,
    this.isLoading = true,
    this.failure,
    this.connection = LiveQueueConnection.connecting,
    this.isYourTurn = false,
    this.calledAt,
  });

  final QueueStatus? queue;

  /// True until the first REST reading arrives.
  final bool isLoading;

  /// The last REST fetch failed. With a [queue] already shown, this is a
  /// banner; without one, the error view.
  final Failure? failure;

  final LiveQueueConnection connection;

  /// `token.called` arrived for this appointment.
  final bool isYourTurn;
  final DateTime? calledAt;

  bool get isLive => connection == LiveQueueConnection.live;

  LiveQueueState copyWith({
    QueueStatus? queue,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
    LiveQueueConnection? connection,
    bool? isYourTurn,
    DateTime? calledAt,
  }) {
    return LiveQueueState(
      queue: queue ?? this.queue,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      connection: connection ?? this.connection,
      isYourTurn: isYourTurn ?? this.isYourTurn,
      calledAt: calledAt ?? this.calledAt,
    );
  }
}
