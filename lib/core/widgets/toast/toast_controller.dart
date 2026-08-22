import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/constants.dart';

/// A single toast message with a unique tick, so re-showing the same text still
/// retriggers the animation.
class ToastMessage {
  const ToastMessage(this.text, this.tick);

  final String text;
  final int tick;
}

/// Global, ephemeral toast channel. Screens call [show] from callbacks
/// (`onPressed`, `onChanged`) — never from a `build`. The notifier only holds
/// a string; the actual overlay is rendered by `ToastHost`, so no
/// SnackBar/Navigator logic lives here (keeps it QA-compliant).
class ToastController extends StateNotifier<ToastMessage?> {
  ToastController() : super(null);

  Timer? _timer;
  int _tick = 0;

  void show(String text) {
    _timer?.cancel();
    state = ToastMessage(text, ++_tick);
    _timer = Timer(AppConstants.toastLifetime, () => state = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final toastControllerProvider =
    StateNotifierProvider<ToastController, ToastMessage?>(
      (ref) => ToastController(),
    );
