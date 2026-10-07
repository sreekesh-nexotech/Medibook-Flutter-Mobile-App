import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';

/// The "Download my data" actions (§5.7): asking for an export and minting a
/// download link for a finished one.
///
/// [idempotencyKey] is minted once per "Request" tap and reused when that
/// same request is retried after a timeout (§1.8), so a double tap cannot
/// open two exports. It is cleared once the server has answered success.
/// [linkingId] is the request whose download link is being fetched, so only
/// that row's button spins.
@immutable
class DataExportState {
  const DataExportState({
    this.isRequesting = false,
    this.linkingId,
    this.failure,
    this.idempotencyKey,
  });

  final bool isRequesting;
  final String? linkingId;
  final Failure? failure;
  final String? idempotencyKey;

  bool get isBusy => isRequesting || linkingId != null;

  DataExportState copyWith({
    bool? isRequesting,
    String? linkingId,
    bool clearLinkingId = false,
    Failure? failure,
    bool clearFailure = false,
    String? idempotencyKey,
    bool clearIdempotencyKey = false,
  }) => DataExportState(
    isRequesting: isRequesting ?? this.isRequesting,
    linkingId: clearLinkingId ? null : (linkingId ?? this.linkingId),
    failure: clearFailure ? null : (failure ?? this.failure),
    idempotencyKey: clearIdempotencyKey
        ? null
        : (idempotencyKey ?? this.idempotencyKey),
  );

  @override
  bool operator ==(Object other) =>
      other is DataExportState &&
      other.isRequesting == isRequesting &&
      other.linkingId == linkingId &&
      other.failure == failure &&
      other.idempotencyKey == idempotencyKey;

  @override
  int get hashCode =>
      Object.hash(isRequesting, linkingId, failure, idempotencyKey);
}
