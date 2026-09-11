import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/toast/toast_host.dart';
import 'config/constants.dart';
import 'localization/l10n.dart';
import 'router/app_router.dart';
import 'theme/theme.dart';

/// Root application widget. Initialises flutter_screenutil at the design size,
/// assembles the `MaterialApp.router`, wires the localization delegates, and
/// mounts the global [ToastHost] once above the router so toasts float over
/// every screen.
class MedibookApp extends StatefulWidget {
  const MedibookApp({super.key});

  @override
  State<MedibookApp> createState() => _MedibookAppState();
}

class _MedibookAppState extends State<MedibookApp> {
  // Built once — a GoRouter must not be recreated on every rebuild.
  final GoRouter _router = buildAppRouter();

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: AppConstants.designSize,
      // Keeps `.sp` sizes legible on small screens; works with the clamped
      // text scaler below rather than against it.
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => MaterialApp.router(
        title: 'Medibook',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,

        // ---- Localization (audit §3.6) ----
        // Without these delegates the framework's own strings — the date
        // picker, the text-selection menu, the "back" semantics label — stay
        // English on a Hindi or Malayalam device no matter what our copy does.
        localizationsDelegates: AppLocalizations.delegates,
        supportedLocales: AppLocalizations.supportedLocales,
        localeResolutionCallback: AppLocalizations.localeResolution,

        builder: (context, child) {
          final page = child ?? const SizedBox.shrink();
          return MediaQuery(
            // ---- OS text scaling, clamped (audit §3.3.6) ----
            //
            // This was `TextScaler.noScaling`, which flatly ignored the
            // viewer's accessibility text-size setting. That is an app-store
            // rejection risk and, more to the point, it makes the app unusable
            // for anyone who needs larger type — which, for a patient app with
            // an older user base, is a lot of people.
            //
            // It is *clamped* rather than unbounded because this design is
            // built on fixed-height controls: 48px buttons, 52px inputs, a
            // 38px header glyph, single-line pills and a 4-tab nav bar with
            // 12px labels. Those absorb 1.3x cleanly; past that, glyphs clip
            // and the nav labels collide. 1.0 is the lower bound, so a viewer
            // who has shrunk system text does not get a design smaller than
            // drawn.
            //
            // Removing the upper bound is a real goal, but it needs the
            // fixed-height controls reworked to grow with their content —
            // a separate, larger piece of work (audit §5.4).
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.of(context).textScaler.clamp(
                minScaleFactor: 1.0,
                maxScaleFactor: AppConstants.maxTextScale,
              ),
            ),
            child: ToastHost(child: page),
          );
        },
      ),
    );
  }
}
