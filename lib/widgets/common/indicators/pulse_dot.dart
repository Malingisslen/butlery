// lib/widgets/common/indicators/pulse_dot.dart
//
// BUT-408: Reusable pulsing status dot, extracted from [EditIndicatorWidget]
// so cooking session cards and other live-presence widgets share the same
// animation contract (WCAG 2.3.3 reduce-motion aware).
//
// Behavior:
// - Pulses from scale 0.5 → 1.0 and back, over 2s.
// - Respects MediaQuery.disableAnimations — renders a static square when
//   reduced motion is enabled (no scale animation).
// - Square shape by design system (no BorderRadius).

import 'package:flutter/material.dart';

import 'package:butlery/core/utils/animation_utils.dart';

/// A small pulsing dot used to indicate live activity (editing, cooking,
/// presence). Square by design system rule. Respects reduce-motion.
class PulseDot extends StatefulWidget {
  const PulseDot({
    required this.color,
    this.size = 8.0,
    this.duration = const Duration(seconds: 2),
    super.key,
  });

  /// Fill color of the dot.
  final Color color;

  /// Edge length in logical pixels (square).
  final double size;

  /// Full pulse cycle (0.5 → 1.0 → 0.5). 2s matches the original
  /// [EditIndicatorWidget] cadence.
  final Duration duration;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = !AnimationUtils.shouldAnimate(context);
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PulseDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
      if (!_reduceMotion && !_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: ColoredBox(color: widget.color),
      );
    }
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Transform.scale(
          scale: _animation.value,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: ColoredBox(color: widget.color),
          ),
        );
      },
    );
  }
}
