import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/navbar.dart';
import '../theme/colors.dart';

import '../../features/auth/presentation/screen/login_screen.dart';
import '../../features/auth/presentation/screen/signup_screen.dart';
import '../../features/auth/presentation/screen/forgot_password_screen.dart';
import '../../features/auth/presentation/screen/verify_code_screen.dart';
import '../../features/auth/presentation/screen/new_password_screen.dart';
import '../../features/dashboard/presentation/screen/home_screen.dart';
import '../../features/search/presentation/screen/search_screen.dart';
import '../../features/notifications/presentation/screen/notifications_screen.dart';
import '../../features/booking/presentation/screen/booking_screen.dart';
import '../../features/booking/presentation/screen/doctor_detail_screen.dart';
import '../../features/booking/presentation/screen/booking_success_screen.dart';
import '../../features/appointments/presentation/screen/appointments_screen.dart';
import '../../features/appointments/presentation/screen/appointment_detail_screen.dart';
import '../../features/appointments/presentation/screen/reschedule_screen.dart';
import '../../features/records/presentation/screen/records_screen.dart';
import '../../features/profile/presentation/screen/profile_screen.dart';

import 'app_routes.dart';

/// The app's route table. The four main tabs live in a bottom-nav
/// [StatefulShellRoute]; auth and every deeper screen are pushed full-screen
/// routes (no bottom nav). Payloads arrive as path/query params.
GoRouter buildAppRouter() {
  return GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      // ---- Auth ----
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: AppRoutes.signup, builder: (_, __) => const SignupScreen()),
      GoRoute(path: AppRoutes.forgot, builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: AppRoutes.verify, builder: (_, __) => const VerifyCodeScreen()),
      GoRoute(path: AppRoutes.reset, builder: (_, __) => const NewPasswordScreen()),

      // ---- Bottom-nav shell (home / appointments / records / profile) ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _ScaffoldWithNav(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.appointments, builder: (_, __) => const AppointmentsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.records, builder: (_, __) => const RecordsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.profile, builder: (_, __) => const ProfileScreen())],
          ),
        ],
      ),

      // ---- Pushed full-screen routes ----
      GoRoute(path: AppRoutes.search, builder: (_, __) => const SearchScreen()),
      GoRoute(path: AppRoutes.notifications, builder: (_, __) => const NotificationsScreen()),
      GoRoute(
        path: AppRoutes.booking,
        builder: (context, state) => BookingScreen(
          step: state.uri.queryParameters['step'],
          dept: state.uri.queryParameters['dept'],
          doctor: state.uri.queryParameters['doctor'],
          origin: state.uri.queryParameters['origin'],
        ),
      ),
      GoRoute(
        path: '${AppRoutes.doctor}/:id',
        builder: (context, state) => DoctorDetailScreen(
          id: state.pathParameters['id']!,
          returnTo: state.uri.queryParameters['return'] ?? 'home',
        ),
      ),
      GoRoute(
        path: AppRoutes.success,
        builder: (context, state) => BookingSuccessScreen(
          appointmentId: state.uri.queryParameters['appt'] ?? '',
        ),
      ),
      GoRoute(
        path: '${AppRoutes.appointmentDetail}/:id',
        builder: (context, state) =>
            AppointmentDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.reschedule}/:id',
        builder: (context, state) => RescheduleScreen(id: state.pathParameters['id']!),
      ),
    ],
  );
}

/// Scaffold that hosts the indexed-stack of tab branches with the shared
/// [AppBottomNav]. The design-system nav owns its own SafeArea + padding, so it
/// slots straight into `bottomNavigationBar`.
class _ScaffoldWithNav extends StatelessWidget {
  const _ScaffoldWithNav({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: shell,
      bottomNavigationBar: AppBottomNav(
        active: AppTab.values[shell.currentIndex],
        onChanged: (tab) => shell.goBranch(
          tab.index,
          // Tapping the active tab again returns it to its initial route.
          initialLocation: tab.index == shell.currentIndex,
        ),
      ),
    );
  }
}
