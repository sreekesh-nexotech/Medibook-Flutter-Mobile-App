import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../common/cached/application/providers/cached_controller.dart';
import '../../../common/cached/application/states/cached_state.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/profile_repository.dart';
import '../states/data_export_state.dart';
import 'profile_provider.dart';

/// `GET /patient/me/data-exports`, cached, newest first.
///
/// autoDispose — read by one screen; rebuilt (and so emptied) when the
/// signed-in account changes, so one user's requests never show for another.
final dataExportsProvider =
    StateNotifierProvider.autoDispose<
      CachedController<List<DataExportRequest>>,
      CachedState<List<DataExportRequest>>
    >((ref) {
      final accountId = ref.watch(currentUserProvider.select((u) => u?.id));
      final repository = ref.watch(profileRepositoryProvider);
      return CachedController<List<DataExportRequest>>(
        ({required forceRefresh}) =>
            repository.dataExports(forceRefresh: forceRefresh),
        loadImmediately: accountId != null,
        reconnects: ref.watch(connectivityMonitorProvider).onReconnect,
      );
    });

/// The export still being prepared, or null — while there is one the server
/// refuses another (`409 STATE_CONFLICT`).
final openDataExportProvider = Provider.autoDispose<DataExportRequest?>(
  (ref) => ref
      .watch(dataExportsProvider.select((s) => s.value))
      ?.where((r) => r.isOpen)
      .firstOrNull,
);

/// "Download my data" (§5.7): [request] opens an export
/// (`POST /patient/me/data-exports`, `Idempotency-Key` minted once per action
/// and reused on retry, §1.8); [link] mints the ten-minute signed URL for a
/// finished one. Opening the URL is the screen's job — nothing here touches
/// the UI.
class DataExportController extends StateNotifier<DataExportState> {
  DataExportController(this._ref, {required ProfileRepository repository})
    : _repository = repository,
      super(const DataExportState());

  final Ref _ref;
  final ProfileRepository _repository;

  /// Returns null on success, otherwise the `Failure`.
  Future<Failure?> request() async {
    if (state.isBusy) return null;
    // Reuse the key on a retry of this same action; mint one otherwise.
    final key = state.idempotencyKey ?? IdempotencyKeys.mint();
    state = state.copyWith(
      isRequesting: true,
      idempotencyKey: key,
      clearFailure: true,
    );
    try {
      final created = await _repository.requestDataExport(idempotencyKey: key);
      if (!mounted) return null;
      state = state.copyWith(isRequesting: false, clearIdempotencyKey: true);
      _ref
          .read(dataExportsProvider.notifier)
          .update(
            (list) => [created, ...list.where((r) => r.id != created.id)],
          );
      return null;
    } catch (error, stackTrace) {
      if (!mounted) return null;
      final failure = error.asFailure(stackTrace);
      state = state.copyWith(isRequesting: false, failure: failure);
      return failure;
    }
  }

  /// The signed link for the finished request [id], or null with
  /// [DataExportState.failure] set (`NOT_FOUND` once the file's seven days
  /// are up).
  Future<DataExportLink?> link(String id) async {
    if (state.isBusy) return null;
    state = state.copyWith(linkingId: id, clearFailure: true);
    try {
      final link = await _repository.dataExportLink(id);
      if (!mounted) return null;
      state = state.copyWith(clearLinkingId: true);
      return link;
    } catch (error, stackTrace) {
      if (!mounted) return null;
      state = state.copyWith(
        clearLinkingId: true,
        failure: error.asFailure(stackTrace),
      );
      return null;
    }
  }
}

/// autoDispose — the key and the busy flags belong to one visit to the
/// screen.
final dataExportControllerProvider =
    StateNotifierProvider.autoDispose<DataExportController, DataExportState>(
      (ref) => DataExportController(
        ref,
        repository: ref.watch(profileRepositoryProvider),
      ),
    );
