import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/account.dart';

/// The delete-account flow (§5.6): request → 30-day cooling off → withdraw or
/// reactivate.
///
/// [idempotencyKey] is minted once per user action and reused when the same
/// request is retried after a timeout (§1.8), so a double tap cannot open two
/// requests. It is cleared once the server has answered success.
@immutable
class AccountDeletionState {
  const AccountDeletionState({
    this.isBusy = false,
    this.failure,
    this.idempotencyKey,
    this.lastRequest,
  });

  final bool isBusy;
  final Failure? failure;
  final String? idempotencyKey;

  /// The request the last successful call returned (created or withdrawn).
  final DeletionRequest? lastRequest;

  AccountDeletionState copyWith({
    bool? isBusy,
    Failure? failure,
    bool clearFailure = false,
    String? idempotencyKey,
    bool clearIdempotencyKey = false,
    DeletionRequest? lastRequest,
  }) => AccountDeletionState(
    isBusy: isBusy ?? this.isBusy,
    failure: clearFailure ? null : (failure ?? this.failure),
    idempotencyKey: clearIdempotencyKey
        ? null
        : (idempotencyKey ?? this.idempotencyKey),
    lastRequest: lastRequest ?? this.lastRequest,
  );

  @override
  bool operator ==(Object other) =>
      other is AccountDeletionState &&
      other.isBusy == isBusy &&
      other.failure == failure &&
      other.idempotencyKey == idempotencyKey &&
      other.lastRequest == lastRequest;

  @override
  int get hashCode => Object.hash(isBusy, failure, idempotencyKey, lastRequest);
}
