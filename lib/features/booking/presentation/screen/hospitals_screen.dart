import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/hospital.dart';
import '../../../../core/mock_data/models/location.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../components/flow_screen_enter.dart';
import '../components/hospital_card.dart';

/// The hospital list (CM-10, CM-11). Route:
/// `/hospitals?city=&area=&dept=`.
///
/// The audit's finding: *"The hospital is only a label printed on a doctor
/// card. It cannot be chosen, searched or filtered."* All three are here — a
/// name/area search box, a department filter whose tabs come from
/// `departmentsProvider`, and rows that open `/hospital/:id`.
///
/// With `city`/`area` present the list is scoped through
/// `hospitalsInLocationProvider`; without them it is every facility. Either
/// way the scope is named on screen and removable, because a filtered list
/// that does not say it is filtered reads as missing data.
///
/// Router wiring:
/// ```dart
/// GoRoute(
///   path: AppRoutes.hospitals,
///   builder: (context, state) => HospitalsScreen(
///     city: state.uri.queryParameters['city'],
///     area: state.uri.queryParameters['area'],
///     dept: state.uri.queryParameters['dept'],
///   ),
/// )
/// ```
class HospitalsScreen extends ConsumerStatefulWidget {
  const HospitalsScreen({super.key, this.city, this.area, this.dept});

  /// City to scope to, or null for every city.
  final String? city;

  /// Area within [city], or null for every area in it.
  final String? area;

  /// Department to pre-select in the filter.
  final String? dept;

  @override
  ConsumerState<HospitalsScreen> createState() => _HospitalsScreenState();
}

class _HospitalsScreenState extends ConsumerState<HospitalsScreen> {
  static const String _allDepartments = 'All';

  final TextEditingController _search = TextEditingController();
  String _query = '';
  late String _department = widget.dept ?? _allDepartments;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The location scope, or null when the screen was opened unscoped.
  Location? get _scope {
    final city = widget.city;
    if (city == null) return null;
    return Location(city: city, area: widget.area ?? '');
  }

  bool _matchesQuery(Hospital hospital) {
    if (_query.isEmpty) return true;
    final needle = _query.toLowerCase();
    return hospital.name.toLowerCase().contains(needle) ||
        hospital.area.toLowerCase().contains(needle) ||
        hospital.city.toLowerCase().contains(needle);
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _department = _allDepartments;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope;
    // `hospitalsInLocationProvider` keys on a city *and* an area, so a
    // city-only scope (no `area` in the query) is filtered here instead —
    // rather than asking that provider for an area called "".
    final List<Hospital> scoped;
    if (scope == null) {
      scoped = ref.watch(hospitalsProvider);
    } else if (scope.area.isEmpty) {
      scoped = [
        for (final h in ref.watch(hospitalsProvider))
          if (h.city == scope.city) h,
      ];
    } else {
      scoped = ref.watch(hospitalsInLocationProvider(scope));
    }

    final departments = ref.watch(departmentsProvider);
    final tabs = [_allDepartments, for (final d in departments) d.name];

    final results = [
      for (final h in scoped)
        if (_matchesQuery(h) &&
            (_department == _allDepartments || h.offers(_department)))
          h,
    ];

    final hasFilter = _query.isNotEmpty || _department != _allDepartments;

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
                        label: scope.area.isEmpty ? scope.city : scope.label,
                        onChange: () =>
                            context.pushReplacement(AppRoutes.locations),
                      ),
                      SizedBox(height: AppSpacing.x3.h),
                    ],
                    AppTextField(
                      controller: _search,
                      hintText: 'Search hospital or area',
                      iconName: MedIcon.search,
                      semanticLabel: 'Search hospitals by name or area',
                      textInputAction: TextInputAction.search,
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                    ),
                    SizedBox(height: AppSpacing.x3.h),
                    AppSegmentedTabs(
                      tabs: tabs,
                      active: _department,
                      onChanged: (value) => setState(() => _department = value),
                    ),
                    SizedBox(height: AppSpacing.x3.h),
                    Text(
                      results.length == 1
                          ? '1 hospital'
                          : '${results.length} hospitals',
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? _empty(scope: scope, hasFilter: hasFilter)
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 28.h),
                        itemCount: results.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: AppSpacing.x3.h),
                        itemBuilder: (context, index) {
                          final hospital = results[index];
                          return HospitalCard(
                            hospital: hospital,
                            highlightDepartment: _department == _allDepartments
                                ? null
                                : _department,
                            onTap: () => context.push(
                              AppRoutes.hospitalPath(hospital.id),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty({required Location? scope, required bool hasFilter}) {
    // Three different reasons for an empty list, three different next steps.
    if (hasFilter) {
      return AppEmptyView(
        iconName: MedIcon.search,
        headline: 'No hospital matches these filters',
        body: _department == _allDepartments
            ? 'Nothing here is called "$_query".'
            : 'No facility in this list runs a $_department department.',
        actionLabel: 'Clear filters',
        onAction: _clearFilters,
        secondaryLabel: 'Choose another area',
        onSecondary: () => context.push(AppRoutes.locations),
      );
    }
    return AppEmptyView(
      iconName: MedIcon.hospital,
      headline: scope == null
          ? 'No hospitals listed yet'
          : 'No hospitals in ${scope.area.isEmpty ? scope.city : scope.label}',
      body: scope == null
          ? 'The facility directory is empty for this account.'
          : 'We have not partnered with a facility here yet. Try a nearby '
                'area, or browse every hospital.',
      actionLabel: 'Choose another area',
      onAction: () => context.push(AppRoutes.locations),
      secondaryLabel: scope == null ? null : 'See every hospital',
      onSecondary: scope == null
          ? null
          : () => context.pushReplacement(AppRoutes.hospitals),
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
        AppIcon(MedIcon.location, size: 15, color: AppColors.brand),
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
