import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/mock_data/models/insurance_policy.dart';
import '../../../../core/mock_data/stores/insurance_store.dart';

/// Which policies the insurance list is showing.
enum InsuranceFilter {
  /// Everything on the account, expired included.
  all('All'),

  /// In force today — the only policies a claim can be made against.
  active('Active'),

  /// Past their validity window (CM-39).
  expired('Expired');

  const InsuranceFilter(this.label);

  final String label;
}

/// The load / refresh / filter state of the insurance locker (`/insurance`).
///
/// The policies themselves live in `insuranceStoreProvider`, which reads the
/// seed synchronously. The loading and error states here are the seam the data
/// layer lands on — when the store becomes a repository call, only [_fetch]
/// changes — and they are what makes the list's four states (loading, error,
/// empty, content) real today rather than dead branches. Nothing here claims
/// anything was downloaded, and [refresh] reports no success message.
@immutable
class InsuranceListState {
  const InsuranceListState({
    this.filter = InsuranceFilter.all,
    this.isLoading = true,
    this.isRefreshing = false,
    this.failure,
  });

  final InsuranceFilter filter;
  final bool isLoading;
  final bool isRefreshing;

  /// Non-null when the last load or refresh failed.
  final Failure? failure;

  InsuranceListState copyWith({
    InsuranceFilter? filter,
    bool? isLoading,
    bool? isRefreshing,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return InsuranceListState(
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

class InsuranceListController extends StateNotifier<InsuranceListState> {
  InsuranceListController() : super(const InsuranceListState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      await _fetch();
      if (!mounted) return;
      state = state.copyWith(isLoading: false, clearFailure: true);
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        failure: error.asFailure(stackTrace),
      );
    }
  }

  /// Pull-to-refresh (audit §3.9.4).
  Future<void> refresh() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    try {
      await _fetch();
      if (!mounted) return;
      state = state.copyWith(isRefreshing: false, clearFailure: true);
    } catch (error, stackTrace) {
      if (!mounted) return;
      state = state.copyWith(
        isRefreshing: false,
        failure: error.asFailure(stackTrace),
      );
    }
  }

  Future<void> retry() {
    state = state.copyWith(isLoading: true, clearFailure: true);
    return _load();
  }

  void setFilter(InsuranceFilter value) {
    if (state.filter == value) return;
    state = state.copyWith(filter: value);
  }

  /// The swap-point for the repository call. See the class doc.
  Future<void> _fetch() => Future<void>.delayed(AppConstants.easeShort);
}

/// autoDispose — the filter and the loading flag belong to one visit.
final insuranceListControllerProvider =
    StateNotifierProvider.autoDispose<
      InsuranceListController,
      InsuranceListState
    >((ref) => InsuranceListController());

/// The policies the list should render, filtered and ordered.
///
/// Ordering puts what is in force first and the longest-expired last, so the
/// policy a user needs at a hospital counter is at the top and an expired one
/// is never mistaken for cover.
final visibleInsurancePoliciesProvider =
    Provider.autoDispose<List<InsurancePolicy>>((ref) {
      final policies = ref.watch(insuranceStoreProvider);
      final filter = ref.watch(
        insuranceListControllerProvider.select((s) => s.filter),
      );

      final filtered = switch (filter) {
        InsuranceFilter.all => [...policies],
        InsuranceFilter.active => policies.where((p) => p.isActive).toList(),
        InsuranceFilter.expired => policies.where((p) => p.isExpired).toList(),
      };

      filtered.sort((a, b) {
        if (a.isExpired != b.isExpired) return a.isExpired ? 1 : -1;
        // Within a group, the one expiring soonest first: that is the one
        // needing attention.
        return a.validTo.compareTo(b.validTo);
      });
      return filtered;
    });

/// How many policies each filter would show — the tab counts.
final insuranceFilterCountsProvider =
    Provider.autoDispose<Map<InsuranceFilter, int>>((ref) {
      final policies = ref.watch(insuranceStoreProvider);
      return {
        InsuranceFilter.all: policies.length,
        InsuranceFilter.active: policies.where((p) => p.isActive).length,
        InsuranceFilter.expired: policies.where((p) => p.isExpired).length,
      };
    });

/// Policies within 30 days of expiry — the CM-39 renewal nudge at the top of
/// the list.
final expiringSoonPoliciesProvider = Provider<List<InsurancePolicy>>((ref) {
  final policies = ref.watch(insuranceStoreProvider);
  return policies.where((p) => p.isExpiringSoon).toList();
});
