import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/theme.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/department.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/mock_data/models/hospital.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/states/app_empty_view.dart';
import '../../../../core/widgets/states/app_loading_view.dart';
import '../components/search_result_row.dart';
import '../controllers/search_controller.dart';

/// Search (`/search`, pushed).
///
/// Covers **departments, doctors and hospitals** — the audit finding was
/// *"Search covers departments and doctors only"*, which left the whole
/// hospital directory (four facilities across two cities) unreachable by name,
/// area or city. Results are grouped by kind, each group labelled with its
/// count, because a department, a doctor and a facility lead to three
/// different next steps.
///
/// Input is debounced by [AppConstants.searchDebounce] through
/// [searchProvider]: the field updates instantly, the lists re-filter once the
/// typing settles, and a quiet loader covers the gap so a half-typed word never
/// reads as "no results".
///
/// Searching **your own appointments** is a different job with a different
/// haystack (booking reference, token, patient) and lives on the appointments
/// feature's own screen — this screen links across to it rather than
/// duplicating it.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Autofocus after the push animation settles, not immediately, so the
    // keyboard doesn't fight the enter transition.
    Future.delayed(AppConstants.searchAutoFocusDelay, () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _clear() {
    _controller.clear();
    ref.read(searchProvider.notifier).clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: AppConstants.screenIn,
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 10.h),
            child: child,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppInnerHeader(title: 'Search', onBack: _goBack, bottomGap: 10),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 14.h),
                child: _SearchField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: ref.read(searchProvider.notifier).onInput,
                  onClear: state.hasInput ? _clear : null,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 2.h, 20.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (state.isSettling && state.hasInput)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 28.h),
                          child: const Center(child: AppInlineLoader()),
                        )
                      else if (results.isEmpty)
                        _EmptyState(
                          query: state.input,
                          onClear: _clear,
                          onBrowseHospitals: () =>
                              context.push(AppRoutes.hospitals),
                        )
                      else ...[
                        if (results.departments.isNotEmpty) ...[
                          SizedBox(height: 10.h),
                          _ResultsHeading(
                            'Departments',
                            count: results.departments.length,
                          ),
                          SizedBox(height: 10.h),
                          _ResultsCard(
                            rows: [
                              for (final dept in results.departments)
                                _departmentRow(context, dept),
                            ],
                          ),
                        ],
                        if (results.doctors.isNotEmpty) ...[
                          SizedBox(height: 20.h),
                          _ResultsHeading(
                            'Doctors',
                            count: results.doctors.length,
                          ),
                          SizedBox(height: 10.h),
                          _ResultsCard(
                            rows: [
                              for (final doc in results.doctors)
                                _doctorRow(context, doc),
                            ],
                          ),
                        ],
                        if (results.hospitals.isNotEmpty) ...[
                          SizedBox(height: 20.h),
                          _ResultsHeading(
                            'Hospitals',
                            count: results.hospitals.length,
                          ),
                          SizedBox(height: 10.h),
                          _ResultsCard(
                            rows: [
                              for (final hospital in results.hospitals)
                                _hospitalRow(context, hospital),
                            ],
                          ),
                        ],
                      ],
                      SizedBox(height: 22.h),
                      _AppointmentSearchLink(
                        onTap: () => context.push(AppRoutes.appointmentsSearch),
                      ),
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

  Widget _departmentRow(BuildContext context, Department dept) {
    return SearchResultRow(
      leading: _IconHolder(iconName: dept.iconName),
      title: dept.name,
      subtitle: dept.sub,
      actionLabel: 'Book',
      onTap: () =>
          context.push(AppRoutes.bookingPath(step: 2, dept: dept.name)),
    );
  }

  Widget _doctorRow(BuildContext context, Doctor doc) {
    return SearchResultRow(
      leading: AppAvatar(name: doc.name, imageAsset: doc.imageAsset, size: 40),
      title: doc.name,
      subtitle: '${doc.spec} · ${doc.hospital}',
      actionLabel: 'View',
      onTap: () =>
          context.push(AppRoutes.doctorPath(doc.id, returnTo: 'search')),
    );
  }

  Widget _hospitalRow(BuildContext context, Hospital hospital) {
    return SearchResultRow(
      leading: _IconHolder(iconName: MedIcon.hospital),
      title: hospital.name,
      subtitle: '${hospital.locationLabel} · ${hospital.distanceLabel}',
      actionLabel: 'View',
      onTap: () => context.push(AppRoutes.hospitalPath(hospital.id)),
    );
  }
}

/// The tinted square that fronts a department or hospital row.
class _IconHolder extends StatelessWidget {
  const _IconHolder({required this.iconName});

  final String iconName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.r,
      height: 40.r,
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: AppRadii.md,
      ),
      child: Center(child: AppIcon(iconName, size: 22, color: AppColors.brand)),
    );
  }
}

/// The pill-shaped search input, with a clear button once there is text.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  /// Null while the field is empty, so the button is absent rather than inert.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Minimum, not fixed: the pill grows with the OS text scale instead of
      // clipping the query at 1.3x.
      constraints: BoxConstraints(minHeight: 52.h),
      padding: EdgeInsets.fromLTRB(18.w, 4.h, 8.w, 4.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 1.w),
        borderRadius: AppRadii.pill,
      ),
      child: Row(
        children: [
          AppIcon(MedIcon.search, size: 20, color: AppColors.textMuted),
          SizedBox(width: 10.w),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              cursorColor: AppColors.brand,
              textInputAction: TextInputAction.search,
              style: AppText.poppins(
                size: AppFontSize.body,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Doctors, departments or hospitals',
                hintStyle: AppText.poppins(
                  size: AppFontSize.body,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          if (onClear != null)
            AppIconButton(
              icon: MedIcon.closeCircle,
              variant: AppIconButtonVariant.plain,
              size: 32,
              semanticLabel: 'Clear the search',
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

/// A results section heading with its count, so the groups are scannable.
class _ResultsHeading extends StatelessWidget {
  const _ResultsHeading(this.text, {required this.count});

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: AppText.poppins(
            size: AppFontSize.body,
            weight: AppText.semibold,
            color: AppColors.textStrong,
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          '$count',
          style: AppText.poppins(
            size: AppFontSize.xs,
            weight: AppText.medium,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// The white card that groups a section's result rows.
class _ResultsCard extends StatelessWidget {
  const _ResultsCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(6.w),
      child: Column(children: rows),
    );
  }
}

/// The way across to appointment search, which matches a different haystack
/// (booking reference, token, patient) and belongs to the appointments feature.
class _AppointmentSearchLink extends StatelessWidget {
  const _AppointmentSearchLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Search your own appointments by booking reference or token',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: AppRadii.md,
              border: Border.all(color: AppColors.border, width: 1.w),
            ),
            child: Row(
              children: [
                AppIcon(MedIcon.calendar, size: 18, color: AppColors.textMuted),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Looking for one of your appointments? Search by booking '
                    'reference or token.',
                    style: AppText.poppins(
                      size: AppFontSize.xs,
                      color: AppColors.textBody,
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  'Open',
                  style: AppText.poppins(
                    size: AppFontSize.xs,
                    weight: AppText.semibold,
                    color: AppColors.textLink,
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

/// Shown when the query matches no department, doctor or hospital.
///
/// Carries actions, per §3.2.2: a dead-end "no matches" line was the audit's
/// complaint about every empty state in the app.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.query,
    required this.onClear,
    required this.onBrowseHospitals,
  });

  final String query;
  final VoidCallback onClear;
  final VoidCallback onBrowseHospitals;

  @override
  Widget build(BuildContext context) {
    return AppEmptyView(
      iconName: MedIcon.search,
      headline: 'No matches for “${query.trim()}”',
      body:
          'Try a department ("Cardiology"), a doctor\'s name, or an area '
          'like "Whitefield".',
      actionLabel: 'Clear the search',
      onAction: onClear,
      secondaryLabel: 'Browse hospitals',
      onSecondary: onBrowseHospitals,
    );
  }
}
