import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/department.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../components/search_result_row.dart';
import '../controllers/search_controller.dart';

/// Search (`/search`, pushed). Live-filters departments and doctors from the
/// single [searchQueryProvider]. The input autofocuses shortly after the screen
/// settles (`AppConstants.searchAutoFocusDelay`). Enters with `screenIn`.
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
    // Autofocus after the push animation settles (matches the prototype's
    // ~260ms delay), not immediately, so the keyboard doesn't fight the enter
    // transition.
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

  @override
  Widget build(BuildContext context) {
    final rawQuery = ref.watch(searchQueryProvider);
    final query = rawQuery.trim().toLowerCase();
    final departments = ref.watch(departmentsProvider);
    final doctors = ref.watch(doctorsProvider);

    // Match: departments on name + descriptor; doctors on name + specialty +
    // department + that department's descriptor (so "skin" finds Dr. Sara Ali).
    final deptByName = {for (final d in departments) d.name: d};
    final filteredDepts = query.isEmpty
        ? departments
        : departments
              .where(
                (d) => '${d.name} ${d.sub}'.toLowerCase().contains(query),
              )
              .toList();
    final filteredDocs = query.isEmpty
        ? doctors
        : doctors.where((doc) {
            final descriptor = deptByName[doc.department]?.sub ?? '';
            final haystack =
                '${doc.name} ${doc.spec} ${doc.department} $descriptor'
                    .toLowerCase();
            return haystack.contains(query);
          }).toList();
    final isEmpty = filteredDepts.isEmpty && filteredDocs.isEmpty;

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
              AppInnerHeader(title: 'Search', onBack: _goBack),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 14.h),
                child: _SearchField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (value) =>
                      ref.read(searchQueryProvider.notifier).state = value,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 2.h, 20.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (filteredDepts.isNotEmpty) ...[
                        SizedBox(height: 10.h),
                        _ResultsHeading('Departments'),
                        SizedBox(height: 10.h),
                        _ResultsCard(
                          rows: [
                            for (final dept in filteredDepts)
                              _departmentRow(context, dept),
                          ],
                        ),
                      ],
                      if (filteredDocs.isNotEmpty) ...[
                        SizedBox(height: 20.h),
                        _ResultsHeading('Doctors'),
                        SizedBox(height: 10.h),
                        _ResultsCard(
                          rows: [
                            for (final doc in filteredDocs)
                              _doctorRow(context, doc),
                          ],
                        ),
                      ],
                      if (isEmpty) _EmptyState(query: rawQuery),
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
      leading: Container(
        width: 40.r,
        height: 40.r,
        decoration: BoxDecoration(
          color: AppColors.surfaceTint,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Center(
          child: AppIcon(dept.iconName, size: 22, color: AppColors.brand),
        ),
      ),
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
      onTap: () => context.push(AppRoutes.doctorPath(doc.id, returnTo: 'search')),
    );
  }
}

/// The pill-shaped search input (bordered white pill, leading search glyph).
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52.h,
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 1.w),
        borderRadius: BorderRadius.circular(999.r),
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
                size: 15,
                weight: AppText.regular,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search doctors or departments...',
                hintStyle: AppText.poppins(
                  size: 15,
                  weight: AppText.regular,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A results section heading (16/600, navy).
class _ResultsHeading extends StatelessWidget {
  const _ResultsHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.poppins(
        size: 16,
        weight: AppText.semibold,
        color: AppColors.textStrong,
      ),
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

/// Shown when the query matches neither a department nor a doctor.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 46.h),
      child: Column(
        children: [
          AppIcon(MedIcon.search, size: 34, color: AppColors.textMuted),
          SizedBox(height: 12.h),
          Text(
            'No matches for “$query”',
            textAlign: TextAlign.center,
            style: AppText.poppins(
              size: 14,
              weight: AppText.regular,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
