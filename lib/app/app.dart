import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/toast/toast_host.dart';
import 'config/constants.dart';
import 'router/app_router.dart';
import 'theme/theme.dart';

/// Root application widget. Initialises flutter_screenutil at the design size,
/// assembles the `MaterialApp.router`, and mounts the global [ToastHost] once
/// above the router so toasts float over every screen. `textScaler` is pinned to
/// no-scaling per the ScreenUtil guide.
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
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, _) => MaterialApp.router(
        title: 'Medibook',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
        builder: (context, child) {
          final page = child ?? const SizedBox.shrink();
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
            child: ToastHost(child: page),
          );
        },
      ),
    );
  }
}
