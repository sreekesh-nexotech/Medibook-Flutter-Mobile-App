import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_refresh.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../application/providers/discovery_providers.dart';
import '../booking_routes.dart';
import '../../domain/entities/location.dart';
import '../components/cache_status_bar.dart';
import '../components/flow_screen_enter.dart';
import '../../application/providers/location_scope_provider.dart';
import '../../domain/entities/location_scope.dart';

/// Where discovery starts (CM-10). Route: `/locations`.
///
/// City and area first (`GET /patient/locations`, §7.1), then `/hospitals`
/// narrowed to that place, then department → doctor → slot. Popular areas
/// get a shortcut row; everything else is grouped under its city heading. A
/// search box filters both, locally — the list is small and already cached.
class LocationsScreen extends ConsumerStatefulWidget {
  const LocationsScreen({super.key});

  @override
  ConsumerState<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends ConsumerState<LocationsScreen> {
  // Purely visual: the filter text for this visit.
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Saves the choice (Home and the Hospitals list stay scoped to it after
  /// a relaunch, CL DISC-001), then shows that area's hospitals.
  Future<void> _openLocation(Location location) async {
    await ref
        .read(locationScopeProvider.notifier)
        .choose(LocationScope(city: location.city, area: location.area));
    if (mounted) context.push(BookingRoutes.hospitalsIn(location));
  }

  /// "All hospitals": forgets the saved location.
  Future<void> _openEverywhere() async {
    await ref.read(locationScopeProvider.notifier).clear();
    if (mounted) context.push(AppRoutes.hospitals);
  }

  bool _matches(Location location) {
    if (_query.isEmpty) return true;
    final needle = _query.toLowerCase();
    return location.area.toLowerCase().contains(needle) ||
        location.city.toLowerCase().contains(needle);
  }

  /// Pull-to-refresh asks the server (`forceRefresh`: the saved ETag is still
  /// sent, so an unchanged list is a cheap 304), then the provider reads
  /// again and finds that answer. It used to re-read only the copy in
  /// memory, so a pull right after opening never reached the network.
  /// Offline, what is saved stays and the status line says so.
  Future<void> _refresh() async {
    try {
      await ref
          .read(discoveryRepositoryProvider)
          .locations(forceRefresh: true)
          .last;
    } catch (_) {
      // What is saved stays on screen; the screen shows its own state.
    }
    ref.invalidate(discoveryLocationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(discoveryLocationsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: FlowScreenEnter(
          child: Column(
            children: [
              AppInnerHeader(
                title: 'Choose a location',
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.home),
              ),
              Expanded(
                child: AppRefreshIndicator(
                  semanticsLabel: 'Refresh locations',
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 28.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          controller: _search,
                          hintText: 'Search city or area',
                          iconName: MedIcon.search,
                          semanticLabel: 'Search for a city or area',
                          textInputAction: TextInputAction.search,
                          onChanged: (value) =>
                              setState(() => _query = value.trim()),
                        ),
                        SizedBox(height: AppSpacing.x5.h),
                        CacheStatusBar(
                          // valueOrNull: `.value` re-throws a list that
                          // could not load, which replaced the screen with
                          // Flutter's red error page offline.
                          result: locations.valueOrNull,
                          onRefresh: _refresh,
                        ),
                        locations.when(
                          loading: () => const AppSkeletonList(count: 4),
                          error: (error, _) => AppErrorView(
                            failure: error.asFailure(),
                            onRetry: _refresh,
                            secondaryLabel: 'See every hospital',
                            // Forgets the saved area first, as the same
                            // button does elsewhere — otherwise "every
                            // hospital" opened still filtered to it.
                            onSecondary: _openEverywhere,
                          ),
                          data: (result) => _body(
                            result.value.results,
                            total: result.value.total,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// [total] is the server's count of areas, which "We currently list …"
  /// names — not the rows that happened to load.
  Widget _body(List<Location> all, {required int total}) {
    final matching = [
      for (final l in all)
        if (_matches(l)) l,
    ];
    final matchingPopular = [
      for (final l in matching)
        if (l.isPopular) l,
    ];
    final cities = <String>[];
    for (final l in all) {
      if (!cities.contains(l.city)) cities.add(l.city);
    }

    if (all.isEmpty) {
      return AppEmptyView(
        iconName: PhIcon.mapPin,
        headline: 'No areas listed yet',
        body: 'The directory has no locations right now.',
        actionLabel: 'See every hospital',
        onAction: _openEverywhere,
      );
    }
    if (matching.isEmpty) {
      return AppEmptyView(
        iconName: PhIcon.mapPin,
        headline: 'No area matches "$_query"',
        body:
            'We currently list $total ${total == 1 ? 'area' : 'areas'} '
            'across ${cities.length} '
            '${cities.length == 1 ? 'city' : 'cities'}.',
        actionLabel: 'Clear the search',
        onAction: () {
          _search.clear();
          setState(() => _query = '');
        },
        secondaryLabel: 'See every hospital',
        onSecondary: _openEverywhere,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (matchingPopular.isNotEmpty) ...[
          const _Heading('Popular right now'),
          SizedBox(height: AppSpacing.x3.h),
          Wrap(
            spacing: AppSpacing.x2.w,
            runSpacing: AppSpacing.x2.h,
            children: [
              for (final l in matchingPopular)
                _PopularChip(location: l, onTap: () => _openLocation(l)),
            ],
          ),
          SizedBox(height: AppSpacing.x6.h),
        ],
        for (final city in cities) ...[
          if (matching.any((l) => l.city == city)) ...[
            _Heading(city),
            SizedBox(height: AppSpacing.x3.h),
            for (final l in matching)
              if (l.city == city) ...[
                _LocationRow(location: l, onTap: () => _openLocation(l)),
                SizedBox(height: AppSpacing.x2.h),
              ],
            SizedBox(height: AppSpacing.x4.h),
          ],
        ],
        _AllHospitalsRow(onTap: _openEverywhere),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.poppins(
        size: AppFontSize.body,
        weight: AppText.semibold,
        color: AppColors.textStrong,
      ),
    );
  }
}

/// A popular area as a tappable pill.
class _PopularChip extends StatelessWidget {
  const _PopularChip({required this.location, required this.onTap});

  final Location location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hospitals in ${location.label}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: 44.h),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.x4.w,
              vertical: AppSpacing.x2.h,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: AppRadii.pill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(PhIcon.mapPin, size: 14, color: AppColors.brand),
                SizedBox(width: 6.w),
                Text(
                  location.area,
                  style: AppText.poppins(
                    size: AppFontSize.sm,
                    weight: AppText.medium,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One area row: the area name over its city, with a chevron glyph.
class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location, required this.onTap});

  final Location location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Hospitals in ${location.label}',
      child: ExcludeSemantics(
        child: AppCard(
          onTap: onTap,
          padding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: AppSpacing.x3.h,
          ),
          child: Row(
            children: [
              Container(
                width: 34.w,
                height: 34.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.sm.r),
                ),
                child: AppIcon(
                  PhIcon.mapPin,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ),
              SizedBox(width: AppSpacing.x3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      location.area,
                      style: AppText.poppins(
                        size: AppFontSize.base,
                        weight: AppText.medium,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${location.city}, ${location.state}',
                      style: AppText.poppins(
                        size: AppFontSize.xs,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The escape hatch for a patient who does not care where: every facility,
/// unfiltered.
class _AllHospitalsRow extends StatelessWidget {
  const _AllHospitalsRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(14.w),
      color: AppColors.surfaceAlt,
      shadow: AppShadowToken.none,
      child: Row(
        children: [
          AppIcon(PhIcon.firstAid, size: 18, color: AppColors.brand),
          SizedBox(width: AppSpacing.x3.w),
          Expanded(
            child: Text(
              'Show hospitals in every area',
              style: AppText.poppins(
                size: AppFontSize.base,
                weight: AppText.medium,
                color: AppColors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
