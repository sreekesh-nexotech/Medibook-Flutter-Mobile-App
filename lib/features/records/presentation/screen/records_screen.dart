import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../../../../core/widgets/toast/toast_controller.dart';
import '../components/record_card.dart';

/// Records tab (`/records`). Lives inside the bottom-nav shell, so it renders no
/// nav bar of its own — just the tab header + the scrolling list of records.
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsProvider);

    return ColoredBox(
      color: AppColors.bgApp,
      child: SafeArea(
        bottom: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: AppConstants.fadeIn,
          curve: Curves.easeOut,
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTabHeader(
                title: 'Records',
                trailing: AppIconButton(
                  icon: MedIcon.bell,
                  variant: AppIconButtonVariant.plain,
                  size: 38,
                  onPressed: () => context.push(AppRoutes.notifications),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 24.h),
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: 6.h, bottom: 14.h),
                      child: Text(
                        'Recent Records',
                        style: AppText.poppins(
                          size: 16,
                          weight: AppText.semibold,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ),
                    for (final record in records)
                      Padding(
                        padding: EdgeInsets.only(bottom: 16.h),
                        child: RecordCard(
                          record: record,
                          onView: () => ref
                              .read(toastControllerProvider.notifier)
                              .show(
                                '${record.title} — preview stubbed in this demo',
                              ),
                          onDownload: () => ref
                              .read(toastControllerProvider.notifier)
                              .show('Downloading ${record.title}…'),
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
