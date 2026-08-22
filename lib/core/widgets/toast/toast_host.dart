import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/config/constants.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/theme.dart';
import '../../../app/theme/typography.dart';
import 'toast_controller.dart';

/// Overlays the current toast above the app content. Wrap the app body once
/// (see `app/app.dart`). Renders the design's coal pill at 104px from the
/// bottom with the `toastIn` rise animation; auto-dismiss is handled by
/// [ToastController].
class ToastHost extends ConsumerWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toast = ref.watch(toastControllerProvider);
    return Stack(
      children: [
        child,
        if (toast != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 104.h,
            child: IgnorePointer(
              child: Center(
                child: _ToastPill(key: ValueKey(toast.tick), text: toast.text),
              ),
            ),
          ),
      ],
    );
  }
}

class _ToastPill extends StatefulWidget {
  const _ToastPill({super.key, required this.text});

  final String text;

  @override
  State<_ToastPill> createState() => _ToastPillState();
}

class _ToastPillState extends State<_ToastPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppConstants.toastIn,
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(curve),
        child: Container(
          constraints: BoxConstraints(maxWidth: 320.w),
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.coal,
            borderRadius: AppRadii.pill,
            boxShadow: AppShadows.toast,
          ),
          child: Text(
            widget.text,
            textAlign: TextAlign.center,
            style: AppText.poppins(
              size: 13,
              weight: AppText.medium,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
