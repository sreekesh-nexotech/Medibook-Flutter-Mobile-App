import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_segmented_tabs.dart';
import '../../../../core/widgets/app_tab_header.dart';
import '../components/appointment_card.dart';
import '../components/enter_animations.dart';
import '../controllers/appointments_controller.dart';
import '../controllers/appt_tab_controller.dart';

/// `/appointments` (a shell tab — the bottom nav is provided by the shell).
///
/// Large title + bell, an Upcoming/Past segmented control driven by the local
/// [apptTabProvider], the appointment cards for the active bucket (or an empty
/// state), and a bottom "Book an appointment" CTA.
class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(apptTabProvider);
    final appointments = ref.watch(
      appointmentsByBucketProvider(bucketForTab(tab)),
    );

    // Resolve each card's doctor here in build (ref.watch stays in build).
    final cards = [
      for (final a in appointments)
        (appointment: a, doctor: ref.watch(doctorByIdProvider(a.doctorId))),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: ScreenEnter(
          rise: false,
          child: Column(
            children: [
              AppTabHeader(
                title: 'Appointments',
                trailing: AppIconButton(
                  icon: MedIcon.bell,
                  size: 38,
                  onPressed: () => context.push(AppRoutes.notifications),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 6.h),
                child: AppSegmentedTabs(
                  tabs: kAppointmentTabs,
                  active: tab,
                  onChanged: (value) {
                    ref.read(apptTabProvider.notifier).state = value;
                  },
                ),
              ),
              Expanded(
                child: cards.isEmpty
                    ? _EmptyState(tab: tab)
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 24.h),
                        itemCount: cards.length,
                        separatorBuilder: (_, __) => SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final card = cards[index];
                          return AppointmentCard(
                            appointment: card.appointment,
                            doctor: card.doctor,
                            onTap: () => context.push(
                              AppRoutes.appointmentDetailPath(
                                card.appointment.id,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 14.h),
                child: AppButton(
                  label: 'Book an appointment',
                  fullWidth: true,
                  onPressed: () => context.push(
                    AppRoutes.bookingPath(step: 1, origin: 'appointments'),
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

/// Centered empty state near the top of the list area ("No upcoming/past
/// appointments").
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab});

  final String tab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 24.h),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 46.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(MedIcon.calendar, size: 34, color: AppColors.textMuted),
              SizedBox(height: 12.h),
              Text(
                'No ${tab.toLowerCase()} appointments',
                textAlign: TextAlign.center,
                style: AppText.poppins(size: 14, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
