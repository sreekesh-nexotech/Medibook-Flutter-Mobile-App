import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/connectivity/connectivity_monitor.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../common/attachments/domain/entities/stored_file.dart';
import '../../../common/attachments/domain/repositories/file_url_resolver.dart';
import '../../../common/attachments/application/providers/attachments_provider.dart';
import '../../../support/application/providers/app_config_provider.dart';
import '../../domain/entities/insurance_policy.dart';
import '../../domain/repositories/insurance_repository.dart';
import '../states/insurance_form_state.dart';
import '../states/insurance_list_state.dart';

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------

/// The insurance repository, as its abstract type.
final insuranceRepositoryProvider = Provider<InsuranceRepository>(
  (ref) => throw UnimplementedError(
    'insuranceRepositoryProvider is wired in app/di',
  ),
);

/// `GET /shared/app-config` → `feature_flags_public['patient_app.insurance']`
/// (§3.1), read from the support slice's [appConfigProvider].
///
/// Enabled while the config has not loaded yet and when the server does not
/// send the flag at all — an absent switch is "not gated", and hiding the
/// locker for the first second of every launch would be the worse failure.
/// Verified live: the test server returns `patient_app.insurance: true`.
final insuranceEnabledProvider = Provider<bool>((ref) {
  final config = ref.watch(appConfigProvider.select((s) => s.value));
  if (config == null) return true;
  return config.featureFlags['patient_app.insurance'] ?? true;
});

// ---------------------------------------------------------------------------
// The list
// ---------------------------------------------------------------------------

/// Loads every policy on the account (cached first, then network) and owns
/// the active / expired filter.
class InsuranceListController extends StateNotifier<InsuranceListState> {
  InsuranceListController({required InsuranceRepository repository})
    : _repository = repository,
      super(const InsuranceListState()) {
    _load();
  }

  final InsuranceRepository _repository;
  StreamSubscription<Object?>? _subscription;

  Future<void> _load({bool forceRefresh = false}) async {
    // Not awaited: offline, the list being replaced is parked until the
    // network returns and would finish cancelling only then — the
    // pull-to-refresh spinner turned until the connection was back.
    unawaited(_subscription?.cancel());
    final done = Completer<void>();
    _subscription = _repository
        .watchPolicies(forceRefresh: forceRefresh)
        .listen(
          (snapshot) {
            if (!mounted) return;
            state = state.copyWith(
              policies: snapshot.value,
              isLoading: false,
              isRefreshing: false,
              clearFailure: true,
              fromCache: snapshot.fromCache,
              isStale: snapshot.isStale,
              revalidating: snapshot.revalidating,
              cachedAt: snapshot.cachedAt,
            );
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted) return;
            final failure = error.asFailure(stackTrace);
            AppLogger.warning(
              'Policies load failed',
              name: 'insurance',
              error: failure,
            );
            state = state.copyWith(
              isLoading: false,
              isRefreshing: false,
              revalidating: false,
              failure: failure,
            );
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (mounted && state.revalidating) {
              state = state.copyWith(revalidating: false);
            }
            if (!done.isCompleted) done.complete();
          },
        );
    return done.future;
  }

  Future<void> refresh() {
    if (state.isRefreshing) return Future.value();
    state = state.copyWith(isRefreshing: true, clearFailure: true);
    return _load(forceRefresh: true);
  }

  Future<void> retry() {
    state = state.copyWith(isLoading: !state.hasData, clearFailure: true);
    return _load(forceRefresh: true);
  }

  /// Load again after a failed read, once the network is back — a refresh
  /// that failed offline otherwise kept its error up after reconnecting.
  void reloadIfFailed() {
    if (mounted && state.failure != null) unawaited(retry());
  }

  void setFilter(InsuranceFilter value) {
    if (state.filter == value) return;
    state = state.copyWith(filter: value);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// `autoDispose` — the filter and the loaded list belong to one visit.
/// Screens call `ref.invalidate(insuranceListProvider)` after a mutation.
final insuranceListProvider =
    StateNotifierProvider.autoDispose<
      InsuranceListController,
      InsuranceListState
    >((ref) {
      final controller = InsuranceListController(
        repository: ref.watch(insuranceRepositoryProvider),
      );
      // A failed read loads once more when the connection returns (HIVE
      // Scenario 3).
      final reconnects = ref
          .watch(connectivityMonitorProvider)
          .onReconnect
          .listen((_) => controller.reloadIfFailed());
      ref.onDispose(reconnects.cancel);
      return controller;
    });

/// How many policies the account holds — the count on Profile's Insurance
/// row. Reads the same cached-first `GET /patient/me/insurance-policies` as
/// the list, without taking over the list's per-visit filter.
///
/// Null until a count is known; a failed refresh keeps the last one, so the
/// row never shows a wrong number. [refresh] with `force` is Profile's
/// pull-to-refresh.
class InsurancePolicyCountController extends StateNotifier<int?> {
  InsurancePolicyCountController({required InsuranceRepository repository})
    : _repository = repository,
      super(null) {
    refresh();
  }

  final InsuranceRepository _repository;
  StreamSubscription<Object?>? _subscription;

  Future<void> refresh({bool force = false}) async {
    // Not awaited, as in the list above: Profile's pull-to-refresh waits
    // on this, and offline the read it replaces is parked until reconnect.
    unawaited(_subscription?.cancel());
    final done = Completer<void>();
    _subscription = _repository
        .watchPolicies(forceRefresh: force)
        .listen(
          (snapshot) {
            if (mounted) state = snapshot.value.length;
          },
          onError: (Object error, StackTrace stackTrace) {
            AppLogger.debug(
              'Policy count unavailable: $error',
              name: 'insurance',
            );
            if (!done.isCompleted) done.complete();
          },
          onDone: () {
            if (!done.isCompleted) done.complete();
          },
        );
    return done.future;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

/// Rebuilt per account: signing in as someone else re-reads. The screens that
/// add, edit or remove a policy invalidate it together with the list.
final insurancePolicyCountProvider =
    StateNotifierProvider.autoDispose<InsurancePolicyCountController, int?>((
      ref,
    ) {
      ref.watch(currentUserProvider.select((u) => u?.id));
      return InsurancePolicyCountController(
        repository: ref.watch(insuranceRepositoryProvider),
      );
    });

/// The policies the list should render, filtered and ordered: in force
/// first, soonest-expiring at the top, the longest-expired last.
final visibleInsurancePoliciesProvider =
    Provider.autoDispose<List<InsurancePolicy>>((ref) {
      final policies = ref.watch(
        insuranceListProvider.select((s) => s.policies),
      );
      final filter = ref.watch(insuranceListProvider.select((s) => s.filter));
      final now = DateTime.now();

      final filtered = switch (filter) {
        InsuranceFilter.all => [...policies],
        InsuranceFilter.active =>
          policies
              .where((p) => p.statusOn(now) != PolicyStatus.expired)
              .toList(),
        InsuranceFilter.expired =>
          policies
              .where((p) => p.statusOn(now) == PolicyStatus.expired)
              .toList(),
      };

      filtered.sort((a, b) {
        final aExpired = a.statusOn(now) == PolicyStatus.expired;
        final bExpired = b.statusOn(now) == PolicyStatus.expired;
        if (aExpired != bExpired) return aExpired ? 1 : -1;
        return a.validTo.compareTo(b.validTo);
      });
      return filtered;
    });

/// How many policies each filter would show — the tab counts.
final insuranceFilterCountsProvider =
    Provider.autoDispose<Map<InsuranceFilter, int>>((ref) {
      final policies = ref.watch(
        insuranceListProvider.select((s) => s.policies),
      );
      final now = DateTime.now();
      final expired = policies
          .where((p) => p.statusOn(now) == PolicyStatus.expired)
          .length;
      return {
        InsuranceFilter.all: policies.length,
        InsuranceFilter.active: policies.length - expired,
        InsuranceFilter.expired: expired,
      };
    });

/// Policies within 30 days of expiry — the CM-39 renewal nudge.
final expiringSoonPoliciesProvider =
    Provider.autoDispose<List<InsurancePolicy>>((ref) {
      final policies = ref.watch(
        insuranceListProvider.select((s) => s.policies),
      );
      final now = DateTime.now();
      return policies
          .where((p) => p.statusOn(now) == PolicyStatus.expiringSoon)
          .toList();
    });

// ---------------------------------------------------------------------------
// One policy
// ---------------------------------------------------------------------------

/// `GET /patient/me/insurance-policies/{id}` with its documents.
final insurancePolicyProvider = FutureProvider.autoDispose
    .family<InsurancePolicy, String>((ref, id) async {
      try {
        return await ref.watch(insuranceRepositoryProvider).policy(id);
      } catch (error, stackTrace) {
        throw error.asFailure(stackTrace);
      }
    });

/// Delete / attach / detach / open-file for one policy. Hands URLs back to
/// the screen; never launches or navigates itself.
class PolicyActionsController extends StateNotifier<PolicyActionsState> {
  PolicyActionsController({
    required InsuranceRepository repository,
    required FileUrlResolver urls,
  }) : _repository = repository,
       _urls = urls,
       super(const PolicyActionsState());

  final InsuranceRepository _repository;
  final FileUrlResolver _urls;

  Future<Failure?> delete(String policyId) async {
    if (state.isBusy) return state.failure;
    state = state.copyWith(isDeleting: true, clearFailure: true);
    try {
      await _repository.delete(policyId);
      if (mounted) state = state.copyWith(isDeleting: false);
      return null;
    } catch (error, stackTrace) {
      final failure = error.asFailure(stackTrace);
      if (mounted) state = state.copyWith(isDeleting: false, failure: failure);
      return failure;
    }
  }

  /// Attach a `clean` `insurance` upload. Returns the refreshed policy, or
  /// null with the failure on state.
  Future<InsurancePolicy?> attach(String policyId, String fileId) async {
    if (state.isBusy) return null;
    state = state.copyWith(isAttaching: true, clearFailure: true);
    try {
      final policy = await _repository.attachDocument(policyId, fileId);
      if (mounted) state = state.copyWith(isAttaching: false);
      return policy;
    } catch (error, stackTrace) {
      if (mounted) {
        state = state.copyWith(
          isAttaching: false,
          failure: error.asFailure(stackTrace),
        );
      }
      return null;
    }
  }

  Future<Failure?> detach(String policyId, String fileId) async {
    if (state.isBusy) return state.failure;
    state = state.copyWith(detachingFileId: fileId, clearFailure: true);
    try {
      await _repository.detachDocument(policyId, fileId);
      _urls.forget(fileId);
      if (mounted) state = state.copyWith(clearDetaching: true);
      return null;
    } catch (error, stackTrace) {
      final failure = error.asFailure(stackTrace);
      if (mounted) {
        state = state.copyWith(clearDetaching: true, failure: failure);
      }
      return failure;
    }
  }

  /// A signed URL for an attached file (§11.4), memoised under ten minutes.
  Future<SignedFileUrl?> fileUrl(String fileId) async {
    if (state.isBusy) return null;
    state = state.copyWith(openingFileId: fileId, clearFailure: true);
    try {
      final url = await _urls.resolve(fileId);
      if (mounted) state = state.copyWith(clearOpening: true);
      return url;
    } catch (error, stackTrace) {
      if (mounted) {
        state = state.copyWith(
          clearOpening: true,
          failure: error.asFailure(stackTrace),
        );
      }
      return null;
    }
  }

  void clearFailure() => state = state.copyWith(clearFailure: true);
}

final policyActionsProvider = StateNotifierProvider.autoDispose
    .family<PolicyActionsController, PolicyActionsState, String>(
      (ref, policyId) => PolicyActionsController(
        repository: ref.watch(insuranceRepositoryProvider),
        urls: ref.watch(fileUrlResolverProvider),
      ),
    );

// ---------------------------------------------------------------------------
// The add form
// ---------------------------------------------------------------------------

class InsuranceFormController extends StateNotifier<InsuranceFormState> {
  InsuranceFormController({
    required InsuranceRepository repository,
    String? holderName,
    InsurancePolicy? editing,
  }) : _repository = repository,
       super(
         editing == null
             ? InsuranceFormState(holderName: holderName ?? '')
             : InsuranceFormState.fromPolicy(editing),
       ) {
    _revalidate();
  }

  final InsuranceRepository _repository;

  /// The largest cover a retail health policy plausibly carries.
  static const int maxSumInsuredRupees = 100000000;

  /// The smallest cover worth recording.
  static const int minSumInsuredRupees = 1000;

  void setProvider(String value) {
    state = state.copyWith(provider: value);
    _revalidate();
  }

  void setPolicyNumber(String value) {
    state = state.copyWith(policyNumber: value);
    _revalidate();
  }

  void setHolderName(String value) {
    state = state.copyWith(holderName: value);
    _revalidate();
  }

  void setPlanName(String value) {
    state = state.copyWith(planName: value);
    _revalidate();
  }

  /// Digits only; an empty field clears the amount rather than storing 0.
  void setSumInsuredRupees(String digits) {
    final trimmed = digits.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(clearSumInsured: true);
      _revalidate();
      return;
    }
    final rupees = int.tryParse(Validators.digitsOf(trimmed));
    state = rupees == null
        ? state.copyWith(clearSumInsured: true)
        : state.copyWith(sumInsured: Money.rupees(rupees));
    _revalidate();
  }

  void setValidFrom(DateTime value) {
    state = state.copyWith(
      validFrom: value,
      errors: state.errors.withTouched(InsuranceField.validFrom),
    );
    _revalidate();
  }

  void setValidTo(DateTime value) {
    state = state.copyWith(
      validTo: value,
      errors: state.errors.withTouched(InsuranceField.validTo),
    );
    _revalidate();
  }

  void setTpaName(String value) {
    state = state.copyWith(tpaName: value);
    _revalidate();
  }

  void setNotes(String value) {
    state = state.copyWith(notes: value);
    _revalidate();
  }

  void setPerson(String? personId) {
    state = personId == null
        ? state.copyWith(clearPerson: true)
        : state.copyWith(personId: personId);
    _revalidate();
  }

  void markTouched(String field) {
    state = state.copyWith(errors: state.errors.withTouched(field));
  }

  bool validate() {
    _revalidate();
    state = state.copyWith(errors: state.errors.withSubmitted());
    return state.errors.isValid;
  }

  /// Validate and `POST`. Returns the created policy, or null when the form
  /// is invalid / a save is in flight / the server refused (failure and
  /// field errors are then on the state).
  Future<InsurancePolicy?> save() async {
    if (state.isSaving) return null;
    if (!validate()) return null;
    final form = state;
    final editing = form.editing;
    if (editing != null && !form.isDirty) return editing;
    state = state.copyWith(isSaving: true, clearFailure: true);
    try {
      if (editing != null) {
        // Edit (BL-INS-006): only what changed, against the saved version.
        String? changed(String now, String? before) =>
            now.trim() == (before ?? '') ? null : now.trim();
        return await _repository.update(
          editing.id,
          PolicyPatch(
            providerName: changed(form.provider, editing.providerName),
            policyNumber: changed(form.policyNumber, editing.policyNumber),
            holderName: changed(form.holderName, editing.holderName),
            validFrom: form.validFrom == editing.validFrom
                ? null
                : form.validFrom,
            validTo: form.validTo == editing.validTo ? null : form.validTo,
            personId: form.personId == editing.personId ? null : form.personId,
            clearPerson: form.personId == null && editing.personId != null,
            planName: changed(form.planName, editing.planName),
            sumInsuredPaise: form.sumInsured?.paise == editing.sumInsuredPaise
                ? null
                : form.sumInsured?.paise,
            tpaName: changed(form.tpaName, editing.tpaName),
            notes: changed(form.notes, editing.notes),
          ),
          version: editing.version,
        );
      }
      final policy = await _repository.create(
        PolicyDraft(
          providerName: form.provider.trim(),
          policyNumber: form.policyNumber.trim(),
          holderName: form.holderName.trim(),
          validFrom: form.validFrom!,
          validTo: form.validTo!,
          personId: form.personId,
          planName: form.planName.trim(),
          sumInsuredPaise: form.sumInsured?.paise,
          tpaName: form.tpaName.trim(),
          notes: form.notes.trim(),
        ),
      );
      // isSaving stays true through the navigation so the unsaved-changes
      // guard does not challenge leaving a form that has been saved.
      return policy;
    } catch (error, stackTrace) {
      if (!mounted) return null;
      final failure = error.asFailure(stackTrace);
      state = state.copyWith(
        isSaving: false,
        failure: failure,
        errors: failure is ValidationFailure
            ? state.errors.withServerErrors(failure.fieldErrors)
            : state.errors,
      );
      return null;
    }
  }

  void _revalidate() {
    final from = state.validFrom;
    final to = state.validTo;

    state = state.copyWith(
      errors: state.errors.withErrors({
        InsuranceField.provider: _lengthError(
          Validators.requiredField('the insurer', state.provider),
          state.provider,
          200,
        ),
        InsuranceField.policyNumber: _policyNumberError(state.policyNumber),
        InsuranceField.holderName: _lengthError(
          Validators.personName(state.holderName),
          state.holderName,
          200,
        ),
        InsuranceField.planName: _lengthError(null, state.planName, 200),
        InsuranceField.sumInsured: _sumInsuredError(state.sumInsured),
        InsuranceField.validFrom: from == null
            ? 'Select the date cover started'
            : null,
        InsuranceField.validTo: to == null
            ? 'Select the date cover ends'
            : (from != null && to.isBefore(from)
                  ? 'Cover cannot end before it starts'
                  : null),
        InsuranceField.tpaName: _lengthError(null, state.tpaName, 200),
        InsuranceField.notes: _lengthError(null, state.notes, 2000),
      }),
    );
  }

  static String? _lengthError(String? existing, String value, int max) {
    if (existing != null) return existing;
    return value.trim().length > max ? 'Keep this under $max characters' : null;
  }

  static String? _policyNumberError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Enter the policy number';
    if (trimmed.length < 5) return 'That looks too short for a policy number';
    if (trimmed.length > 100) return 'Keep this under 100 characters';
    return null;
  }

  static String? _sumInsuredError(Money? value) {
    if (value == null) return null; // optional on the wire
    if (value.rupeePart < minSumInsuredRupees) {
      return 'Sum insured looks too low. Enter the amount in rupees.';
    }
    if (value.rupeePart > maxSumInsuredRupees) {
      return 'That is higher than any retail policy. Check for an extra zero.';
    }
    return null;
  }
}

/// `autoDispose` — an add form belongs to one visit to `/insurance/add`.
/// The holder name is seeded from the signed-in user (read, not watched, so
/// a mid-edit profile refresh cannot overwrite what was typed).
final insuranceFormProvider =
    StateNotifierProvider.autoDispose<
      InsuranceFormController,
      InsuranceFormState
    >(
      (ref) => InsuranceFormController(
        repository: ref.watch(insuranceRepositoryProvider),
        holderName: ref.read(currentUserProvider)?.name,
      ),
    );

/// The form for editing saved policy [id] — opened from its detail screen,
/// which has already loaded it (BL-INS-006).
final insuranceEditFormProvider = StateNotifierProvider.autoDispose
    .family<InsuranceFormController, InsuranceFormState, String>(
      (ref, id) => InsuranceFormController(
        repository: ref.watch(insuranceRepositoryProvider),
        editing: ref.read(insurancePolicyProvider(id)).valueOrNull,
      ),
    );
