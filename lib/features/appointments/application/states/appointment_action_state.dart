import '../../../../core/error/failure.dart';
import '../../domain/entities/cancellation_preview.dart';

/// Which of the detail screen's mutations is in flight, so its button can
/// show `loading:` and refuse a second tap (audit §3.5.6).
enum AppointmentActionKind { cancel, review, receiptPdf, calendar }

/// The transient state behind the appointment detail's buttons.
///
/// Immutable; every update goes through [copyWith]. [preview] is the last
/// cancellation preview fetched (§10.6), kept so the confirm dialog and the
/// policy notice show the same numbers.
class AppointmentActionState {
  const AppointmentActionState({this.busy, this.failure, this.preview});

  /// The action currently running, or null when idle.
  final AppointmentActionKind? busy;

  /// Why the last action failed, for the toast.
  final Failure? failure;

  final CancellationPreview? preview;

  bool get isBusy => busy != null;

  bool isRunning(AppointmentActionKind kind) => busy == kind;

  AppointmentActionState copyWith({
    AppointmentActionKind? busy,
    bool clearBusy = false,
    Failure? failure,
    bool clearFailure = false,
    CancellationPreview? preview,
  }) {
    return AppointmentActionState(
      busy: clearBusy ? null : (busy ?? this.busy),
      failure: clearFailure ? null : (failure ?? this.failure),
      preview: preview ?? this.preview,
    );
  }
}
