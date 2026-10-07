import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../domain/repositories/profile_repository.dart';
import '../states/account_deletion_state.dart';
import 'profile_mutations_provider.dart';
import 'profile_provider.dart';

/// Delete account (§5.6): [request] opens a 30-day cooling-off request
/// (`Idempotency-Key` minted once per action and reused on retry, §1.8);
/// [withdraw] cancels it; [reactivate] brings a `pending_deletion` account
/// back to `active`.
///
/// After [request] every *other* session is ended by the server; this one
/// stays, with `user.status = pending_deletion`, which the profile screen
/// renders as the cooling-off card.
class AccountDeletionController extends StateNotifier<AccountDeletionState> {
  AccountDeletionController(this._ref, {required ProfileRepository repository})
    : _repository = repository,
      super(const AccountDeletionState());

  final Ref _ref;
  final ProfileRepository _repository;

  /// `POST /patient/me/deletion-requests`. `409 STATE_CONFLICT` when one is
  /// already open.
  Future<Failure?> request({String? reason}) => _run(() async {
    // Reuse the key on a retry of this same action; mint one otherwise.
    final key = state.idempotencyKey ?? IdempotencyKeys.mint();
    state = state.copyWith(idempotencyKey: key);
    final created = await _repository.requestDeletion(
      reason: reason,
      idempotencyKey: key,
    );
    state = state.copyWith(lastRequest: created, clearIdempotencyKey: true);
    _ref
        .read(deletionRequestsProvider.notifier)
        .update(
          (list) => [
            created,
            ...list.where((r) => r.requestNo != created.requestNo),
          ],
        );
    // The user's status is now `pending_deletion`.
    await _ref.read(authProvider.notifier).refreshMe();
  });

  /// `DELETE /patient/me/deletion-requests/{request_no}` → withdrawn.
  Future<Failure?> withdraw(String requestNo) => _run(() async {
    final withdrawn = await _repository.withdrawDeletion(requestNo);
    state = state.copyWith(lastRequest: withdrawn);
    _ref
        .read(deletionRequestsProvider.notifier)
        .update(
          (list) => [
            for (final r in list)
              r.requestNo == withdrawn.requestNo ? withdrawn : r,
          ],
        );
    await _ref.read(authProvider.notifier).refreshMe();
  });

  /// `POST /patient/me/reactivate` → the user, `status` back to `active`.
  Future<Failure?> reactivate() => _run(() async {
    mergeUserIntoSession(_ref, await _repository.reactivate());
    await _ref.read(deletionRequestsProvider.notifier).refresh(force: true);
  });

  Future<Failure?> _run(Future<void> Function() call) async {
    if (state.isBusy) return null;
    state = state.copyWith(isBusy: true, clearFailure: true);
    try {
      await call();
      if (!mounted) return null;
      state = state.copyWith(isBusy: false);
      return null;
    } catch (error, stackTrace) {
      if (!mounted) return null;
      final failure = error.asFailure(stackTrace);
      state = state.copyWith(isBusy: false, failure: failure);
      return failure;
    }
  }
}

/// autoDispose — the key and the last result belong to one visit to the
/// profile screen.
final accountDeletionControllerProvider =
    StateNotifierProvider.autoDispose<
      AccountDeletionController,
      AccountDeletionState
    >(
      (ref) => AccountDeletionController(
        ref,
        repository: ref.watch(profileRepositoryProvider),
      ),
    );
