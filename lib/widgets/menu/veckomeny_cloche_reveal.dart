import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/widgets/common/brand/butlery_cloche_lift.dart';

/// Laid over the week for a moment when a generated menu is ready: the cover
/// lifts and the plate is shown before the week appears. The wait before it
/// stays the plate line (B-18).
class VeckomenyClocheReveal extends StatefulWidget {
  const VeckomenyClocheReveal({required this.onDone, super.key});

  final VoidCallback onDone;

  /// How long the lifted cloche is held before the week is handed back.
  static const Duration hold = Duration(milliseconds: 350);

  static const Key liftKey = ValueKey<String>('veckomeny-cloche-lift');

  @override
  State<VeckomenyClocheReveal> createState() => _VeckomenyClocheRevealState();
}

class _VeckomenyClocheRevealState extends State<VeckomenyClocheReveal> {
  bool _lifted = false;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    // The first frame draws the closed cloche so the lift has a start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!AnimationUtils.shouldAnimate(context)) {
        widget.onDone();
        return;
      }
      setState(() => _lifted = true);
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onLifted() {
    _holdTimer = Timer(VeckomenyClocheReveal.hold, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: ButleryClocheLift(
          key: VeckomenyClocheReveal.liftKey,
          lifted: _lifted,
          onEnd: _lifted ? _onLifted : null,
        ),
      ),
    );
  }
}
