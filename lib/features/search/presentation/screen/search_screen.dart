import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/route_arrival.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_rating.dart';
import '../../../../core/widgets/app_tag.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/states/app_error_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../../../booking/application/providers/discovery_providers.dart';
import '../../../booking/presentation/booking_routes.dart';
import '../../../booking/domain/entities/doctor.dart';
import '../../../booking/domain/entities/hospital.dart';
import '../../../booking/presentation/components/file_image.dart';
import '../../../booking/presentation/components/slot_labels.dart';
import '../../../dashboard/application/providers/home_providers.dart';
import '../../application/providers/search_providers.dart';
import '../../domain/entities/search_results.dart';
import '../../../dashboard/presentation/components/department_icon.dart';

/// Search (`/search`, pushed), laid out as the design's Search screen: back
/// + the search input; idle shows "Recent Searches" and "Popular
/// Specialities"; typing shows the result count, the sort pills, then
/// Specialities · Hospitals · Doctors.
///
/// Results come from `GET /patient/search?q=` (§7.9) — hospitals,
/// departments and doctors, up to ten of each — debounced by
/// [searchQueryProvider], which never sends fewer than two characters.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(searchQueryProvider);

    return RouteArrival(
      onArrive: () {
        ref.invalidate(searchResultsProvider);
        ref.invalidate(discoveryDepartmentsProvider);
      },
      child: Scaffold(
        backgroundColor: AppColors.bgApp,
        body: SafeArea(
          child: Column(
            children: [
              // Design `padding: 54px 20px 12px` — 54 includes the 46px status
              // zone, so 8 below the OS inset.
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: MedIcon.back,
                      size: 38,
                      semanticLabel: 'Back',
                      onPressed: () => _leave(context),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _SearchField(
                        value: search.input,
                        onChanged: (v) =>
                            ref.read(searchQueryProvider.notifier).onInput(v),
                        onClear: () =>
                            ref.read(searchQueryProvider.notifier).clear(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                  child: search.hasQuery
                      ? _Results(query: search.query!)
                      : search.isTooShort
                      ? const _TooShort()
                      : const _Idle(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }
}

// ---- Idle -------------------------------------------------------------------

/// "Recent Searches" · "Popular Specialities" (the platform's departments).
class _Idle extends ConsumerWidget {
  const _Idle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentSearchesProvider);
    final services = ref.watch(homeServicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recents.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(child: _SectionTitle('Recent Searches')),
              Semantics(
                button: true,
                label: 'Clear recent searches',
                child: ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        ref.read(recentSearchesProvider.notifier).clear(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      child: Text(
                        'Clear',
                        style: AppText.poppins(
                          size: AppFontSize.sm,
                          weight: AppText.medium,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final label in recents)
                Semantics(
                  button: true,
                  label: 'Search $label',
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          ref.read(searchQueryProvider.notifier).submit(label),
                      child: AppTag(label: label),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 24.h),
        ],
        const _SectionTitle('Popular Specialities'),
        SizedBox(height: 12.h),
        services.when(
          loading: () => const AppSkeletonList(count: 3, tile: true),
          error: (error, _) => AppInlineError(
            failure: error.asFailure(),
            onRetry: () => ref.invalidate(discoveryDepartmentsProvider),
          ),
          data: (all) => Column(
            children: [
              for (var i = 0; i < all.length; i++) ...[
                if (i > 0) SizedBox(height: 12.h),
                _SpecialityRow(
                  code: all[i].code,
                  label: all[i].label,
                  iconName: departmentIconFor(all[i].code),
                  sub: all[i].hospitalCount == 1
                      ? '1 hospital'
                      : '${all[i].hospitalCount} hospitals',
                  chevron: true,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One character typed: the endpoint needs two, so say so instead of
/// showing stale results or "no results".
class _TooShort extends StatelessWidget {
  const _TooShort();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 50.h),
      child: Text(
        'Type at least ${SearchQueryRules.minLength} characters to search.',
        textAlign: TextAlign.center,
        style: AppText.poppins(
          size: AppFontSize.base,
          color: AppColors.textMuted,
          height: 1.5,
        ),
      ),
    );
  }
}

// ---- Results ----------------------------------------------------------------

class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider(query));
    // A settled query is worth remembering once it returns.
    ref.listen(searchResultsProvider(query), (previous, next) {
      if (next.hasValue && !next.isLoading) {
        ref.read(recentSearchesProvider.notifier).remember(query);
      }
    });

    return results.when(
      loading: () => const AppSkeletonList(count: 3),
      error: (error, _) => AppInlineError(
        failure: error.asFailure(),
        onRetry: () => ref.invalidate(searchResultsProvider(query)),
      ),
      data: (found) => _ResultsBody(query: query, results: found),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({required this.query, required this.results});

  final String query;
  final SearchResults results;

  @override
  Widget build(BuildContext context) {
    final total = results.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${total == 1 ? '1 result' : '$total results'} for "$query"',
          style: AppText.poppins(
            size: AppFontSize.sm,
            color: AppColors.textMuted,
          ),
        ),
        SizedBox(height: 12.h),
        if (results.departments.isNotEmpty) ...[
          const _GroupLabel('Specialities'),
          for (var i = 0; i < results.departments.length; i++) ...[
            if (i > 0) SizedBox(height: 12.h),
            _SpecialityRow(
              code: results.departments[i].code,
              label: results.departments[i].name,
              iconName: departmentIconFor(results.departments[i].code),
              sub: results.departments[i].hospitalCount == 1
                  ? '1 hospital'
                  : '${results.departments[i].hospitalCount} hospitals',
              chevron: false,
            ),
          ],
          SizedBox(height: 20.h),
        ],
        if (results.hospitals.isNotEmpty) ...[
          const _GroupLabel('Hospitals'),
          for (var i = 0; i < results.hospitals.length; i++) ...[
            if (i > 0) SizedBox(height: 12.h),
            _HospitalRow(hospital: results.hospitals[i]),
          ],
          SizedBox(height: 20.h),
        ],
        if (results.doctors.isNotEmpty) const _GroupLabel('Doctors'),
        for (var i = 0; i < results.doctors.length; i++) ...[
          if (i > 0) SizedBox(height: 12.h),
          _DoctorHit(doctor: results.doctors[i]),
        ],
        if (total == 0)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 50.h),
            child: Text(
              'No matches for "$query". Try a doctor, a hospital or a '
              'speciality like "cardio".',
              textAlign: TextAlign.center,
              style: AppText.poppins(
                size: AppFontSize.base,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}

// ---- Pieces -----------------------------------------------------------------

/// The DS `Input` with the search prefix and the design's clear button (a
/// `28` grey disc with an ×) once there is text.
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the field in step with state set elsewhere (a recent-search tap,
    // the clear button) without fighting the patient's own typing.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        AppTextField(
          controller: _controller,
          hintText: 'Doctors, hospitals, specialities',
          iconName: MedIcon.search,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          maxLength: SearchQueryRules.maxLength,
          // The Home search bar opens this screen to type (CL HOME-012).
          autofocus: true,
        ),
        if (widget.value.isNotEmpty)
          Positioned(
            right: 12.w,
            child: Semantics(
              button: true,
              label: 'Clear the search',
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClear,
                  child: Container(
                    width: 28.r,
                    height: 28.r,
                    decoration: const BoxDecoration(
                      color: AppColors.grey100,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: AppIcon(
                        PhIcon.x,
                        size: 16,
                        color: AppColors.grey500,
                      ),
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

/// `16/600` navy section heading.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

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

/// The results' uppercase group label: `12/600` muted, `.04em` tracking.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Text(
        text.toUpperCase(),
        style: AppText.poppins(
          size: AppFontSize.xs,
          weight: AppText.semibold,
          color: AppColors.textMuted,
          letterSpacing: 0.48,
        ),
      ),
    );
  }
}

/// The rotated `caret-left` the design uses as a chevron-right.
class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 3.14159265,
      child: AppIcon(PhIcon.caretLeft, size: 18, color: AppColors.grey300),
    );
  }
}

/// A speciality row: `40` tint square with the `22` mark, label `14/600`,
/// "N hospitals" `12` muted; a chevron on the idle list only. Opens booking
/// at that department code.
class _SpecialityRow extends StatelessWidget {
  const _SpecialityRow({
    required this.code,
    required this.label,
    required this.iconName,
    required this.sub,
    required this.chevron,
  });

  final String code;
  final String label;
  final String iconName;
  final String sub;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(BookingRoutes.booking(step: 2, dept: code)),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: AppRadii.md,
            ),
            child: AppIcon(iconName, size: 22, color: AppColors.brand),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: AppFontSize.base,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (chevron) ...[SizedBox(width: 12.w), const _Chevron()],
        ],
      ),
    );
  }
}

/// A hospital hit: `56` logo (or initials), name, area, next open slot.
class _HospitalRow extends StatelessWidget {
  const _HospitalRow({required this.hospital});

  final HospitalCard hospital;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(AppRoutes.hospitalPath(hospital.id)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadii.md,
            child: SizedBox(
              width: 56.w,
              height: 56.w,
              child: AppFileImage(
                fileId: hospital.logoFileId ?? hospital.coverFileId,
                fallback: ColoredBox(
                  color: AppColors.surfaceTint,
                  child: Center(
                    child: Text(
                      hospital.name
                          .split(' ')
                          .where((w) => w.isNotEmpty)
                          .take(2)
                          .map((w) => w[0].toUpperCase())
                          .join(),
                      style: AppText.poppins(
                        size: AppFontSize.body,
                        weight: AppText.bold,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hospital.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: AppFontSize.body,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  hospital.locationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  SlotLabels.nextAvailable(hospital.nextAvailableAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    color: AppColors.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A doctor hit: `52` avatar, name, "dept · hospital", the DS rating, the fee
/// in brand on the right; then a hairline and the green next-slot line.
class _DoctorHit extends StatelessWidget {
  const _DoctorHit({required this.doctor});

  final DoctorCard doctor;

  @override
  Widget build(BuildContext context) {
    final next = doctor.nextAvailableAt;
    return AppCard(
      onTap: () =>
          context.push(AppRoutes.doctorPath(doctor.id, returnTo: 'search')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 52.w,
                  height: 52.w,
                  child: AppFileImage(
                    fileId: doctor.photoFileId,
                    fallback: ColoredBox(
                      color: AppColors.surfaceTint,
                      child: Center(
                        child: Text(
                          doctor.name
                              .replaceAll(RegExp(r'^Dr\.?\s+'), '')
                              .split(' ')
                              .where((w) => w.isNotEmpty)
                              .take(2)
                              .map((w) => w[0].toUpperCase())
                              .join(),
                          style: AppText.poppins(
                            size: AppFontSize.base,
                            weight: AppText.semibold,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      doctor.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(
                        size: AppFontSize.body,
                        weight: AppText.semibold,
                        color: AppColors.textStrong,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 2.h, bottom: 4.h),
                      child: Text(
                        '${doctor.department.name} · ${doctor.hospital.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          size: AppFontSize.xs,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    if (doctor.hasRating)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: AppRating(
                          value: doctor.ratingValue,
                          showValue: true,
                          size: 13,
                        ),
                      )
                    else
                      Text(
                        'Not yet rated',
                        style: AppText.poppins(
                          size: AppFontSize.xs,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                Money.inr(doctor.consultationFeePaise),
                style: AppText.poppins(
                  size: AppFontSize.sm,
                  weight: AppText.semibold,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
          Container(
            margin: EdgeInsets.only(top: 12.h),
            padding: EdgeInsets.only(top: 12.h),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle, width: 1.h),
              ),
            ),
            child: Row(
              children: [
                AppIcon(
                  PhIcon.clock,
                  size: 16,
                  color: next == null
                      ? AppColors.textMuted
                      : AppColors.successText,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    SlotLabels.nextAvailable(next),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(
                      size: AppFontSize.sm,
                      weight: AppText.medium,
                      color: next == null
                          ? AppColors.textMuted
                          : AppColors.successText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
