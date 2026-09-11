import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/navbar.dart';
import '../../core/widgets/states/app_loading_view.dart';
import '../../core/widgets/states/app_not_found_view.dart';
import '../../globals.dart';
import '../theme/colors.dart';

import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/auth/application/states/auth_state.dart';

import '../../features/auth/presentation/screen/change_password_screen.dart';
import '../../features/auth/presentation/screen/forgot_password_screen.dart';
import '../../features/auth/presentation/screen/login_screen.dart';
import '../../features/auth/presentation/screen/new_password_screen.dart';
import '../../features/auth/presentation/screen/signup_screen.dart';
import '../../features/auth/presentation/screen/verify_code_screen.dart';
import '../../features/dashboard/presentation/screen/ambulance_screen.dart';
import '../../features/dashboard/presentation/screen/home_screen.dart';
import '../../features/search/presentation/screen/search_screen.dart';
import '../../features/notifications/presentation/screen/notifications_screen.dart';
import '../../features/booking/presentation/screen/booking_screen.dart';
import '../../features/booking/presentation/screen/doctor_detail_screen.dart';
import '../../features/booking/presentation/screen/booking_success_screen.dart';
import '../../features/booking/presentation/screen/hospital_detail_screen.dart';
import '../../features/booking/presentation/screen/hospitals_screen.dart';
import '../../features/booking/presentation/screen/locations_screen.dart';
import '../../features/booking/presentation/screen/queue_screen.dart';
import '../../features/payment/presentation/screen/payment_result_screen.dart';
import '../../features/payment/presentation/screen/payment_screen.dart';
import '../../features/appointments/presentation/screen/appointment_detail_screen.dart';
import '../../features/appointments/presentation/screen/appointment_filter_sheet.dart';
import '../../features/appointments/presentation/screen/appointment_receipt_screen.dart';
import '../../features/appointments/presentation/screen/appointment_search_screen.dart';
import '../../features/appointments/presentation/screen/appointments_screen.dart';
import '../../features/appointments/presentation/screen/reschedule_screen.dart';
import '../../features/records/presentation/screen/document_detail_screen.dart';
import '../../features/records/presentation/screen/document_upload_screen.dart';
import '../../features/records/presentation/screen/records_screen.dart';
import '../../features/insurance/presentation/screen/insurance_add_screen.dart';
import '../../features/insurance/presentation/screen/insurance_detail_screen.dart';
import '../../features/insurance/presentation/screen/insurance_screen.dart';
import '../../features/profile/presentation/screen/addresses_screen.dart';
import '../../features/profile/presentation/screen/dependant_edit_screen.dart';
import '../../features/profile/presentation/screen/dependants_screen.dart';
import '../../features/profile/presentation/screen/emergency_contacts_screen.dart';
import '../../features/profile/presentation/screen/profile_edit_screen.dart';
import '../../features/profile/presentation/screen/profile_screen.dart';
import '../../features/support/presentation/screen/faq_screen.dart';
import '../../features/support/presentation/screen/legal_document_screen.dart';
import '../../features/support/presentation/screen/support_screen.dart';

import 'app_routes.dart';

/// The app's route table.
///
/// The four main tabs live in a bottom-nav [StatefulShellRoute]; auth and every
/// deeper screen are pushed full-screen routes. Payloads arrive as path/query
/// params rather than `extra` objects, so a deep link can address any of them.
///
/// Three things live here and nowhere else:
///
/// * **The sign-in guard** (audit §3.7.4 — "There is no sign-in guard in the
///   patient app. The home screen can be reached without ever passing login").
/// * **Deep-link translation** (audit §3.7.3 — "No screen in the patient app
///   can be opened by a link").
/// * **The not-found screen** (audit §3.2.4 — the app "drops the viewer onto a
///   raw framework crash page").
GoRouter buildAppRouter(WidgetRef ref) {
  return GoRouter(
    navigatorKey: Globals.rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) => _redirect(ref, state),

    // Audit §3.2.4: an unknown route explains itself instead of showing the
    // framework's red error page.
    errorBuilder: (context, state) => AppNotFoundView(
      attemptedPath: state.uri.toString(),
      onGoHome: () => context.go(AppRoutes.home),
    ),

    routes: [
      // Resolved by the guard as soon as the stored session is read; never
      // navigated to by hand.
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const _SplashScreen()),

      // ---- Auth ----
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.signup, builder: (_, _) => const SignupScreen()),
      GoRoute(
        path: AppRoutes.forgot,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.verify,
        builder: (_, _) => const VerifyCodeScreen(),
      ),
      GoRoute(
        path: AppRoutes.reset,
        builder: (_, _) => const NewPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      // The same screen from Profile's own path, so either constant works.
      GoRoute(
        path: AppRoutes.profilePassword,
        builder: (_, _) => const ChangePasswordScreen(),
      ),

      // ---- Bottom-nav shell (home / appointments / records / profile) ----
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _ScaffoldWithNav(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.appointments,
                builder: (_, _) => const AppointmentsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.records,
                builder: (_, _) => const RecordsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---- Pushed full-screen routes ----
      GoRoute(path: AppRoutes.search, builder: (_, _) => const SearchScreen()),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),

      // ---- Discovery (CM-10 / CM-11) ----
      GoRoute(
        path: AppRoutes.locations,
        builder: (_, _) => const LocationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.hospitals,
        builder: (context, state) => HospitalsScreen(
          city: state.uri.queryParameters['city'],
          area: state.uri.queryParameters['area'],
          dept: state.uri.queryParameters['dept'],
        ),
      ),
      GoRoute(
        path: '${AppRoutes.hospital}/:id',
        builder: (context, state) =>
            HospitalDetailScreen(id: state.pathParameters['id']!),
      ),

      // ---- Booking funnel ----
      GoRoute(
        path: AppRoutes.booking,
        builder: (context, state) => BookingScreen(
          step: state.uri.queryParameters['step'],
          dept: state.uri.queryParameters['dept'],
          doctor: state.uri.queryParameters['doctor'],
          origin: state.uri.queryParameters['origin'],
          // Without this, hospital-scoped discovery silently degrades to
          // unscoped once the funnel is entered.
          hospital: state.uri.queryParameters['hospital'],
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

      // ---- Payment (CM-17 / CM-20 / CM-23) ----
      GoRoute(
        path: AppRoutes.bookingPayment,
        builder: (_, _) => const PaymentScreen(),
      ),
      GoRoute(
        path: AppRoutes.bookingPaymentResult,
        builder: (context, state) => PaymentResultScreen(
          status:
              state.uri.queryParameters['status'] ??
              AppRoutes.paymentStatusPending,
          appointmentId: state.uri.queryParameters['appt'],
        ),
      ),

      // ---- Appointments ----
      GoRoute(
        path: '${AppRoutes.appointmentDetail}/:id',
        builder: (context, state) =>
            AppointmentDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '${AppRoutes.reschedule}/:id',
        builder: (context, state) =>
            RescheduleScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.appointmentsSearch,
        builder: (_, _) => const AppointmentSearchScreen(),
      ),
      // The filter is normally a sheet over the list; this route hosts the same
      // body so a deep link and the system back button both work.
      GoRoute(
        path: AppRoutes.appointmentsFilter,
        builder: (_, _) => const AppointmentFilterScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.receipt}/:id',
        builder: (context, state) => AppointmentReceiptScreen(
          appointmentId: state.pathParameters['id']!,
        ),
      ),

      // ---- Queue + emergency (CM-09 / CM-24, CM-44..46) ----
      GoRoute(
        path: '${AppRoutes.queue}/:doctorId',
        builder: (context, state) =>
            QueueScreen(doctorId: state.pathParameters['doctorId']!),
      ),
      GoRoute(
        path: AppRoutes.ambulance,
        builder: (_, _) => const AmbulanceScreen(),
      ),

      // ---- Profile (CM-47, CM-49, CM-50) ----
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (_, _) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEmergency,
        builder: (_, _) => const EmergencyContactsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileAddress,
        builder: (_, _) => const AddressesScreen(),
      ),

      // ---- Dependants (CM-16 / CM-48) ----
      // `/dependants/edit` before the bare list is unnecessary (no param
      // route here), but the edit screen reads `?id=` itself, so one row
      // serves both add and edit.
      GoRoute(
        path: AppRoutes.dependants,
        builder: (_, _) => const DependantsScreen(),
      ),
      GoRoute(
        path: AppRoutes.dependantEdit,
        builder: (context, state) =>
            DependantEditScreen(id: state.uri.queryParameters['id']),
      ),

      // ---- Insurance locker (CM-37..CM-39) ----
      // `/insurance/add` is registered BEFORE `/insurance/:id`, or the param
      // route swallows it and tries to open a policy called "add".
      GoRoute(
        path: AppRoutes.insurance,
        builder: (_, _) => const InsuranceScreen(),
      ),
      GoRoute(
        path: AppRoutes.insuranceAdd,
        builder: (_, _) => const InsuranceAddScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.insurance}/:id',
        builder: (context, state) =>
            InsuranceDetailScreen(id: state.pathParameters['id']),
      ),

      // ---- Legal, FAQ and support (CM-02 / CM-52) ----
      // Public: the sign-up consent checkbox links straight to the legal
      // documents, which a visitor has to be able to read before signing up.
      GoRoute(
        path: '${AppRoutes.legal}/:slug',
        builder: (context, state) =>
            LegalDocumentScreen(slug: state.pathParameters['slug']),
      ),
      GoRoute(path: AppRoutes.faq, builder: (_, _) => const FaqScreen()),
      GoRoute(
        path: AppRoutes.support,
        builder: (_, _) => const SupportScreen(),
      ),
      // Help and Support are the same destination; both constants resolve.
      GoRoute(path: AppRoutes.help, builder: (_, _) => const SupportScreen()),

      // ---- Documents library (CM-32..CM-36) ----
      // `/documents/upload` is registered BEFORE `/documents/:id`, or the
      // param route would swallow it and try to open a document called
      // "upload".
      GoRoute(
        path: AppRoutes.documentUpload,
        builder: (_, _) => const DocumentUploadScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.documents}/:id',
        builder: (context, state) =>
            DocumentDetailScreen(documentId: state.pathParameters['id']!),
      ),

      // Reachable by name so a failed deep link can land somewhere honest.
      GoRoute(
        path: AppRoutes.notFound,
        builder: (context, state) =>
            AppNotFoundView(onGoHome: () => context.go(AppRoutes.home)),
      ),
    ],
  );
}

/// Paths an unauthenticated visitor may open.
///
/// Prefix-matched, so `/legal/privacy` is covered by `/legal`. Everything not
/// listed here needs a session — that is the guard's default, so a screen added
/// later is protected unless someone deliberately opens it up.
const List<String> _publicPrefixes = [
  AppRoutes.splash,
  AppRoutes.login,
  AppRoutes.signup,
  AppRoutes.forgot,
  AppRoutes.verify,
  AppRoutes.reset,
  AppRoutes.lockout,
  AppRoutes.legal,
  AppRoutes.faq,
  AppRoutes.support,
  AppRoutes.help,
  AppRoutes.notFound,
];

/// Sign-in screens a signed-in user should not be sitting on.
///
/// `/verify` is deliberately absent: it also serves re-verifying a changed
/// phone number from Profile, which happens while signed in.
const List<String> _signedOutOnly = [
  AppRoutes.login,
  AppRoutes.signup,
  AppRoutes.forgot,
  AppRoutes.reset,
  AppRoutes.lockout,
];

bool _isPublic(String location) => _publicPrefixes.any(
  (prefix) => location == prefix || location.startsWith('$prefix/'),
);

/// The guard.
///
/// Returns null to allow the navigation, or a path to redirect to.
String? _redirect(WidgetRef ref, GoRouterState state) {
  // ---- Deep links (audit §3.7.3) ----
  //
  // Only genuinely external URIs are translated. In-app navigation already
  // speaks real paths, and `fromDeepLink` matches on the first segment, so
  // running it over everything would rewrite `/change-password` to a
  // not-found and collapse `/appointments/search` to `/appointments`.
  final uri = state.uri;
  final isExternalLink =
      uri.scheme == AppRoutes.deepLinkScheme ||
      uri.host == AppRoutes.deepLinkHost;
  if (isExternalLink) {
    // A null mapping means "explain yourself", not "ignore".
    return AppRoutes.fromDeepLink(uri) ?? AppRoutes.notFound;
  }

  final location = state.matchedLocation;

  return switch (ref.read(authProvider)) {
    // Storage not read yet: hold on the splash rather than guessing, so a
    // returning user never flashes the sign-in screen.
    AuthUnknown() => location == AppRoutes.splash ? null : AppRoutes.splash,

    // Audit §3.7.4: the home screen could be reached without ever passing
    // login. Anything not explicitly public now needs a session.
    AuthUnauthenticated() =>
      location == AppRoutes.splash
          ? AppRoutes.login
          : _isPublic(location)
          ? null
          : AppRoutes.login,

    AuthAuthenticated() =>
      location == AppRoutes.splash || _signedOutOnly.contains(location)
          ? AppRoutes.home
          : null,
  };
}

/// Re-runs the guard when the session changes.
///
/// Without this, signing in or out would update the state but leave the user on
/// the screen they were already on — which is exactly the audit's CM-53
/// finding, a logout that navigates without the session actually ending.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(WidgetRef ref) {
    _sub = ref.listenManual<AuthState>(authProvider, (previous, next) {
      // Only a change of *kind* can change a routing decision; the
      // failed-attempt counter ticking up must not bounce the user.
      if (previous.runtimeType != next.runtimeType) notifyListeners();
    }, fireImmediately: false);
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// Shown only while the stored session is being read.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgApp,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: const AppLoadingView(label: 'Medibook'),
        ),
      ),
    );
  }
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
