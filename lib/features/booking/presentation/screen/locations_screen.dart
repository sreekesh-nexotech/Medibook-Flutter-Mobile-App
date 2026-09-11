import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/location.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../domain/booking_routes.dart';
import '../components/flow_screen_enter.dart';

/// Where discovery starts (CM-10). Route: `/locations`.
///
/// The audit's finding: *"There is no location picker and no hospital list.
/// Discovery begins at a department."* This is step zero of the funnel the app
/// was missing — city and area first, then `/hospitals` narrowed to that
/// place, then department → doctor → slot.
///
/// Popular areas get a shortcut row; everything else is grouped under its city
/// heading (`citiesProvider` supplies the order, so the headings can never
/// drift from the data). A search box filters both, because ten areas is
/// already more than a phone screen shows at 1.3x text scale.
///
/// Router wiring:
/// ```dart
/// GoRoute(
///   path: AppRoutes.locations,
///   builder: (_, __) => const LocationsScreen(),
/// )
/// ```
class LocationsScreen extends ConsumerStatefulWidget {
  const LocationsScreen({super.key});

  @override
  ConsumerState<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends ConsumerState<LocationsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openLocation(Location location) =>
      context.push(BookingRoutes.hospitalsIn(location));

  bool _matches(Location location) {
    if (_query.isEmpty) return true;
    final needle = _query.toLowerCase();
    return location.area.toLowerCase().contains(needle) ||
        location.city.toLowerCase().contains(needle);
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(locationsProvider);
    final popular = ref.watch(popularLocationsProvider);
    final cities = ref.watch(citiesProvider);

    final matching = [
      for (final l in all)
        if (_matches(l)) l,
    ];
    final matchingPopular = [
      for (final l in popular)
        if (_matches(l)) l,
    ];

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
                      if (matching.isEmpty)
                        AppEmptyView(
                          iconName: MedIcon.location,
                          headline: 'No area matches "$_query"',
                          body:
                              'We currently list ${all.length} areas across '
                              '${cities.length} cities.',
                          actionLabel: 'Clear the search',
                          onAction: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          secondaryLabel: 'See every hospital',
                          onSecondary: () => context.push(AppRoutes.hospitals),
                        )
                      else ...[
                        if (matchingPopular.isNotEmpty) ...[
                          _Heading('Popular right now'),
                          SizedBox(height: AppSpacing.x3.h),
                          Wrap(
                            spacing: AppSpacing.x2.w,
                            runSpacing: AppSpacing.x2.h,
                            children: [
                              for (final l in matchingPopular)
                                _PopularChip(
                                  location: l,
                                  onTap: () => _openLocation(l),
                                ),
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
                                _LocationRow(
                                  location: l,
                                  onTap: () => _openLocation(l),
                                ),
                                SizedBox(height: AppSpacing.x2.h),
                              ],
                            SizedBox(height: AppSpacing.x4.h),
                          ],
                        ],
                        _AllHospitalsRow(
                          onTap: () => context.push(AppRoutes.hospitals),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                AppIcon(MedIcon.location, size: 14, color: AppColors.brand),
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
                  MedIcon.location,
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
                      location.city,
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
          AppIcon(MedIcon.hospital, size: 18, color: AppColors.brand),
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
