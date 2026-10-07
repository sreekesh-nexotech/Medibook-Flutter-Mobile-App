import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/location/device_location.dart';
import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_select.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../application/providers/discovery_providers.dart';
import '../../domain/entities/department.dart';
import '../../domain/repositories/discovery_repository.dart';
import '../components/cache_status_bar.dart';
import '../components/flow_screen_enter.dart';
import '../components/hospital_card.dart';
import '../../application/providers/location_scope_provider.dart';
import '../../domain/entities/location_scope.dart';

/// The hospital list (CM-10, CM-11). Route: `/hospitals?city=&area=&dept=`.
///
/// Every filter is a server filter on `GET /patient/hospitals` (§7.2): the
/// name search is `q` (debounced), the department tabs are
/// `department_code` (from `GET /patient/departments`), the location scope
/// is `city`/`area`, and the sort menu is `sort`. The scope is named on
/// screen and removable, because a filtered list that does not say it is
/// filtered reads as missing data. With the phone's approximate position
/// the list sends `lat`/`lng` and offers (and defaults to) 'Nearest', which
/// the backend sorts by distance; without it, name order (CL DISC-015).
class HospitalsScreen extends ConsumerStatefulWidget {
  const HospitalsScreen({super.key, this.city, this.area, this.dept});

  /// City to scope to, or null for every city.
  final String? city;

  /// Area within [city], or null for every area in it.
  final String? area;

  /// Department **code** to pre-select in the filter.
  final String? dept;

  @override
  ConsumerState<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends ConsumerState<HospitalsScreen> {
  static const String _allDepartments = 'All';

  // Purely visual state for this visit: the typed text, the settled query,
  // the active tab and sort. The data itself is in the providers.
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _departmentCode;

  /// The patient's choice; null until they pick one, which means "nearest
  /// first" when the position is known and name order otherwise.
  HospitalSort? _sort;

  /// The phone's approximate position, or null (CL DISC-015).
  Coordinates? get _at =>
      ref.read(deviceLocationProvider).valueOrNull?.coordinates;

  HospitalSort get _effectiveSort {
    final chosen = _sort;
    if (chosen == HospitalSort.distance && _at == null) {
      return HospitalSort.name;
    }
    return chosen ?? (_at != null ? HospitalSort.distance : HospitalSort.name);
  }

  @override
  void initState() {
    super.initState();
    _departmentCode = widget.dept;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// The link's location when it names one, else the saved one (CL
  /// DISC-001), else everywhere.
  LocationScope? get _scope {
    final city = widget.city;
    if (city != null && city.isNotEmpty) {
      return LocationScope(city: city, area: widget.area);
    }
    return ref.read(locationScopeProvider);
  }

  HospitalsQuery get _hospitalsQuery => HospitalsQuery(
    city: _scope?.city,
    area: (_scope?.hasArea ?? false) ? _scope!.area : null,
    departmentCode: _departmentCode,
    q: _query.isEmpty ? null : _query,
    // With a position the backend works out each hospital's distance (and
    // can sort by it); the app never computes distances itself.
    lat: _at?.latText,
    lng: _at?.lngText,
    sort: _effectiveSort,
    pageSize: 50,
  );

  String? get _scopeLabel => _scope?.label;

  /// "See every hospital": forgets the saved location too, so Home and this
  /// list go back to everywhere.
  Future<void> _showEverywhere() async {
    await ref.read(locationScopeProvider.notifier).clear();
    if (mounted) context.pushReplacement(AppRoutes.hospitals);
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(AppConstants.searchDebounce, () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _clearFilters() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _query = '';
      _departmentCode = null;
    });
  }

  /// Pull-to-refresh asks the server (`forceRefresh`: the saved ETag is still
  /// sent, so an unchanged list is a cheap 304), then the provider reads
  /// again and finds that answer. It used to re-read only the copy in
  /// memory, so a pull right after opening never reached the network.
  Future<void> _refresh() async {
    final query = _hospitalsQuery;
    try {
      await ref
          .read(discoveryRepositoryProvider)
          .hospitals(query, forceRefresh: true)
          .last;
    } catch (_) {
      // What is saved stays on screen; the screen shows its own state.
    }
    ref.invalidate(discoveryHospitalsProvider(query));
  }

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(discoveryDepartmentsProvider);
    // Rebuilds with the distance order once the position arrives, and when
    // the saved location changes.
    ref.watch(deviceLocationProvider);
    ref.watch(locationScopeProvider);
    final hospitals = ref.watch(discoveryHospitalsProvider(_hospitalsQuery));
    final scope = _scopeLabel;

    final tabs = <DepartmentSummary>[
      ...?departments.valueOrNull?.value.results,
    ];
    final activeTab = tabs.any((d) => d.code == _departmentCode)
        ? tabs.firstWhere((d) => d.code == _departmentCode).name
        : _allDepartments;
    final hasFilter = _query.isNotEmpty || _departmentCode != null;

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: FlowScreenEnter(
          child: Column(
            children: [
              AppInnerHeader(
                title: 'Hospitals',
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.home),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (scope != null) ...[
                      _ScopeRow(
                        label: scope,
                        onChange: () =>
                            context.pushReplacement(AppRoutes.locations),
                      ),
                      SizedBox(height: AppSpacing.x3.h),
                    ],
                    AppTextField(
                      controller: _search,
                      hintText: 'Search hospital by name',
                      iconName: MedIcon.search,
                      semanticLabel: 'Search hospitals by name',
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearch,
                    ),
                    SizedBox(height: AppSpacing.x3.h),
                    if (tabs.isNotEmpty)
                      AppSegmentedTabs(
                        tabs: [_allDepartments, for (final d in tabs) d.name],
                        active: activeTab,
                        onChanged: (value) => setState(() {
                          _departmentCode = value == _allDepartments
                              ? null
                              : tabs.firstWhere((d) => d.name == value).code;
                        }),
                      ),
                    SizedBox(height: AppSpacing.x3.h),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            switch (hospitals.valueOrNull?.value.total) {
                              null => '',
                              1 => '1 hospital',
                              final n => '$n hospitals',
                            },
                            style: AppText.poppins(
                              size: AppFontSize.xs,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 168.w,
                          child: AppSelect<HospitalSort>(
                            value: _effectiveSort,
                            options: [
                              if (_at != null)
                                const AppSelectOption(
                                  HospitalSort.distance,
                                  'Nearest',
                                ),
                              const AppSelectOption(
                                HospitalSort.name,
                                'Name A–Z',
                              ),
                              const AppSelectOption(
                                HospitalSort.rating,
                                'Highest rated',
                              ),
                              const AppSelectOption(
                                HospitalSort.nextAvailable,
                                'Soonest slot',
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => _sort = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.x2.h),
                    CacheStatusBar(
                      // valueOrNull: `.value` re-throws a list that could
                      // not load — offline, an area never opened before
                      // showed Flutter's red error page.
                      result: hospitals.valueOrNull,
                      onRefresh: _refresh,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AppRefreshIndicator(
                  semanticsLabel: 'Refresh hospitals',
                  onRefresh: _refresh,
                  child: hospitals.when(
                    loading: () => AppSkeletonList(
                      count: 3,
                      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 28.h),
                    ),
                    error: (error, _) => AppErrorView(
                      failure: error.asFailure(),
                      onRetry: _refresh,
                    ),
                    data: (result) {
                      final rows = result.value.results;
                      if (rows.isEmpty) {
                        return SingleChildScrollView(
                          child: _empty(scope: scope, hasFilter: hasFilter),
                        );
                      }
                      return ListView.separated(
                        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 28.h),
                        itemCount: rows.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: AppSpacing.x3.h),
                        itemBuilder: (context, index) => HospitalListCard(
                          hospital: rows[index],
                          highlightDepartment: _departmentCode,
                          onTap: () => context.push(
                            AppRoutes.hospitalPath(rows[index].id),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty({required String? scope, required bool hasFilter}) {
    // Three different reasons for an empty list, three different next steps.
    if (hasFilter) {
      return AppEmptyView(
        iconName: PhIcon.magnifyingGlass,
        headline: 'No hospital matches these filters',
        body: _departmentCode == null
            ? 'Nothing here is called "$_query".'
            : 'No facility in this list runs that department.',
        actionLabel: 'Clear filters',
        onAction: _clearFilters,
        secondaryLabel: 'Choose another area',
        onSecondary: () => context.push(AppRoutes.locations),
      );
    }
    return AppEmptyView(
      iconName: PhIcon.firstAid,
      headline: scope == null
          ? 'No hospitals listed yet'
          : 'No hospitals in $scope',
      body: scope == null
          ? 'No facility is live and accepting patients right now.'
          : 'We have not partnered with a facility here yet. Try a nearby '
                'area, or browse every hospital.',
      actionLabel: 'Choose another area',
      onAction: () => context.push(AppRoutes.locations),
      secondaryLabel: scope == null ? null : 'See every hospital',
      onSecondary: scope == null ? null : _showEverywhere,
    );
  }
}

/// The location this list is scoped to, with the way to change it. Named on
/// screen so a short list never looks like missing data.
class _ScopeRow extends StatelessWidget {
  const _ScopeRow({required this.label, required this.onChange});

  final String label;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppIcon(PhIcon.mapPin, size: 15, color: AppColors.brand),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.poppins(
              size: AppFontSize.base,
              weight: AppText.medium,
              color: AppColors.textStrong,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Change location, currently $label',
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onChange,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.x2.w,
                  vertical: AppSpacing.x3.h,
                ),
                child: Text(
                  'Change',
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    weight: AppText.medium,
                    color: AppColors.textLink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
