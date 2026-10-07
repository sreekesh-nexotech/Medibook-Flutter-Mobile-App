import '../../../../core/error/failure.dart';
import '../../domain/entities/insurance_policy.dart';

/// Which policies the insurance list is showing.
enum InsuranceFilter {
  all('All'),
  active('Active'),
  expired('Expired');

  const InsuranceFilter(this.label);

  final String label;
}

/// The insurance locker's list: what loaded, from where, what is in flight.
class InsuranceListState {
  const InsuranceListState({
    this.filter = InsuranceFilter.all,
    this.policies = const <InsurancePolicy>[],
    this.isLoading = true,
    this.isRefreshing = false,
    this.failure,
    this.fromCache = false,
    this.isStale = false,
    this.revalidating = false,
    this.cachedAt,
  });

  final InsuranceFilter filter;

  /// Every policy on the account (the filter is applied by a derived
  /// provider so the tab counts can be shown).
  final List<InsurancePolicy> policies;
  final bool isLoading;
  final bool isRefreshing;
  final Failure? failure;
  final bool fromCache;
  final bool isStale;
  final bool revalidating;
  final DateTime? cachedAt;

  bool get hasData => policies.isNotEmpty;

  InsuranceListState copyWith({
    InsuranceFilter? filter,
    List<InsurancePolicy>? policies,
    bool? isLoading,
    bool? isRefreshing,
    Failure? failure,
    bool clearFailure = false,
    bool? fromCache,
    bool? isStale,
    bool? revalidating,
    DateTime? cachedAt,
  }) {
    return InsuranceListState(
      filter: filter ?? this.filter,
      policies: policies ?? this.policies,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      failure: clearFailure ? null : (failure ?? this.failure),
      fromCache: fromCache ?? this.fromCache,
      isStale: isStale ?? this.isStale,
      revalidating: revalidating ?? this.revalidating,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}

/// State of the actions on one policy (delete, attach, detach, open file).
class PolicyActionsState {
  const PolicyActionsState({
    this.isDeleting = false,
    this.isAttaching = false,
    this.detachingFileId,
    this.openingFileId,
    this.failure,
  });

  final bool isDeleting;
  final bool isAttaching;
  final String? detachingFileId;
  final String? openingFileId;
  final Failure? failure;

  bool get isBusy =>
      isDeleting ||
      isAttaching ||
      detachingFileId != null ||
      openingFileId != null;

  PolicyActionsState copyWith({
    bool? isDeleting,
    bool? isAttaching,
    String? detachingFileId,
    bool clearDetaching = false,
    String? openingFileId,
    bool clearOpening = false,
    Failure? failure,
    bool clearFailure = false,
  }) => PolicyActionsState(
    isDeleting: isDeleting ?? this.isDeleting,
    isAttaching: isAttaching ?? this.isAttaching,
    detachingFileId: clearDetaching
        ? null
        : (detachingFileId ?? this.detachingFileId),
    openingFileId: clearOpening ? null : (openingFileId ?? this.openingFileId),
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}
