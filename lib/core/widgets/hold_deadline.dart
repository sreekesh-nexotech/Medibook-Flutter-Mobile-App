import 'dart:async';

import 'package:flutter/widgets.dart';

import '../utils/server_clock.dart';

/// Wraps an unpaid booking's card (Home, the Appointments tab). At
/// [deadline] (by the server's clock) the hold can no longer be paid, so the
/// card is hidden at once; [onDeadline]
/// then re-reads the list every 15 s until the server has released the
/// booking — it sweeps expired holds every few tens of seconds, not exactly
/// at the deadline (seen: 11 s and 52 s after).
class HoldDeadline extends StatefulWidget {
  const HoldDeadline({
    super.key,
    required this.deadline,
    required this.onDeadline,
    required this.child,
  });

  final DateTime? deadline;
  final VoidCallback onDeadline;
  final Widget child;

  @override
  State<HoldDeadline> createState() => _HoldDeadlineState();
}

class _HoldDeadlineState extends State<HoldDeadline> {
  static const Duration _retry = Duration(seconds: 15);

  Timer? _timer;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(HoldDeadline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final deadline = widget.deadline;
    _expired = false;
    if (deadline == null) return;
    final wait = deadline.difference(ServerClock.now());
    if (wait.isNegative) {
      _expired = true;
      _timer = Timer(Duration.zero, _recheck);
    } else {
      _timer = Timer(wait, _onExpired);
    }
  }

  void _onExpired() {
    if (!mounted) return;
    setState(() => _expired = true);
    _recheck();
  }

  void _recheck() {
    if (!mounted) return;
    widget.onDeadline();
    // Still here after the re-read means the server has not released it
    // yet; ask again shortly. Disposing (the booking is gone) stops this.
    _timer = Timer(_retry, _recheck);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _expired ? const SizedBox.shrink() : widget.child;
}
