import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/constants.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/mock_data/models/doctor.dart';
import '../../../../core/mock_data/seed_providers.dart';
import '../../../../core/widgets/app_avatar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/app_inner_header.dart';
import '../../../../core/widgets/app_rating.dart';
import '../../domain/booking_routes.dart';
import '../components/doctor_stat.dart';
import '../components/flow_screen_enter.dart';
import '../controllers/booking_controller.dart';

/// Doctor detail: hero card (avatar, name, spec·hospital, rating, 3-up stats) +
/// About + clinic, with a sticky "Book an appointment" footer. Route:
/// `/doctor/:id?return=booking|search|home`.
///
/// The router builder wires the constructor from the path + query, e.g.:
/// ```dart
/// DoctorDetailScreen(
///   id: state.pathParameters['id']!,
///   returnTo: state.uri.queryParameters['return'] ?? 'home',
/// )
/// ```
class DoctorDetailScreen extends ConsumerWidget {
  const DoctorDetailScreen({
    super.key,
    required this.id,
    this.returnTo = 'home',
  });

  final String id;

  /// Where the back button and the booking origin resolve to
  /// (`booking` | `search` | `home`).
  final String returnTo;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(returnTo == 'search' ? AppRoutes.search : AppRoutes.home);
  }

  /// "Book an appointment": jump into booking step 3 pre-filled with this
  /// doctor. When we arrived from an in-flight booking flow, keep that flow's
  /// origin; otherwise the origin is home.
  void _bookThisDoctor(BuildContext context, WidgetRef ref, Doctor doctor) {
    final String origin;
    String? hospitalId;
    if (returnTo == 'booking') {
      final draft = ref.read(bookingControllerProvider);
      origin = draft.origin == BookingOrigin.appointments
          ? 'appointments'
          : 'home';
      // Keep the facility the funnel was entered through (CM-11) — but only
      // when this doctor actually practises there, so a cross-hospital tap
      // cannot produce a draft that contradicts itself.
      if (draft.hospitalId != null && draft.hospitalId == doctor.hospitalId) {
        hospitalId = draft.hospitalId;
      }
    } else {
      origin = 'home';
    }
    context.go(
      BookingRoutes.booking(
        step: 3,
        hospital: hospitalId,
        dept: doctor.department,
        doctor: doctor.id,
        origin: origin,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctor = ref.watch(doctorByIdProvider(id));

    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: SafeArea(
        child: FlowScreenEnter(
          child: Column(
            children: [
              AppInnerHeader(
                title: 'Doctor Details',
                onBack: () => _back(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 24.h),
                  child: Column(
                    children: [
                      _hero(doctor),
                      SizedBox(height: 14.h),
                      _about(doctor),
                      SizedBox(height: 14.h),
                      _clinic(doctor),
                    ],
                  ),
                ),
              ),
              _footer(context, ref, doctor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(Doctor doctor) {
    return AppCard(
      padding: EdgeInsets.symmetric(vertical: 22.h, horizontal: 18.w),
      child: Column(
        children: [
          AppAvatar(name: doctor.name, imageAsset: doctor.imageAsset, size: 88),
          SizedBox(height: 12.h),
          Text(
            doctor.name,
            textAlign: TextAlign.center,
            style: AppText.poppins(
              size: 19,
              weight: AppText.bold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '${doctor.spec} · ${doctor.hospital}',
            textAlign: TextAlign.center,
            style: AppText.poppins(size: 13, color: AppColors.textMuted),
          ),
          SizedBox(height: 10.h),
          AppRating(value: doctor.rating, showValue: true, size: 15),
          SizedBox(height: 18.h),
          Container(
            padding: EdgeInsets.only(top: 16.h),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderSubtle, width: 1.w),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DoctorStat(
                    value: doctor.experience,
                    label: 'Experience',
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: DoctorStat(value: doctor.patients, label: 'Patients'),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: DoctorStat(value: doctor.fee, label: 'Consultation'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _about(Doctor doctor) {
    return AppCard(
      padding: EdgeInsets.all(18.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: AppText.poppins(
              size: 15,
              weight: AppText.bold,
              color: AppColors.textStrong,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            doctor.about,
            style: AppText.poppins(
              size: 13,
              color: AppColors.textBody,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _clinic(Doctor doctor) {
    return AppCard(
      padding: EdgeInsets.all(14.w),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            child: Image.asset(
              'assets/images/hospital.jpg',
              width: 54.w,
              height: 54.w,
              fit: BoxFit.cover,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doctor.hospital,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    size: 14,
                    weight: AppText.semibold,
                    color: AppColors.textStrong,
                  ),
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    AppIcon(
                      MedIcon.location,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 5.w),
                    Flexible(
                      child: Text(
                        'Multi-speciality center',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, WidgetRef ref, Doctor doctor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 14.h,
        bottom: 22.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.w),
        ),
      ),
      child: AppButton(
        label: 'Book an appointment',
        fullWidth: true,
        onPressed: () => _bookThisDoctor(context, ref, doctor),
      ),
    );
  }
}
