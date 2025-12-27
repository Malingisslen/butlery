import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// A wrapper widget that adds scale-on-press feedback to any child widget.
///
/// Respects the user's "Reduce Motion" accessibility setting (WCAG 2.3.3).
/// When animations are disabled, the widget still provides haptic feedback.
///
/// This widget uses a [Listener] to detect pointer events without interfering
/// with the child's own gesture handling (e.g., button ripple effects).
///
/// Example:
/// ```dart
/// AnimatedPressable(
///   child: ElevatedButton(
///     onPressed: () => print('Pressed!'),
///     child: Text('Tap me'),
///   ),
/// )
/// ```
class AnimatedPressable extends StatefulWidget {
  /// The child widget to wrap with press animation.
  final Widget child;

  /// Whether the animation is enabled. When false, no animation occurs.
  /// Useful for disabled or loading states.
  final bool enabled;

  /// The scale to animate to when pressed. Default is 0.95 (5% smaller).
  final double pressedScale;

  /// The duration of the scale animation.
  final Duration duration;

  /// The curve of the scale animation.
  final Curve curve;

  /// Whether to provide haptic feedback on press.
  final bool enableHapticFeedback;

  const AnimatedPressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.pressedScale = 0.95,
    this.duration = AppDimensions.animationDurationFast,
    this.curve = Curves.easeOut,
    this.enableHapticFeedback = true,
  });

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = !AnimationUtils.shouldAnimate(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;

    if (widget.enableHapticFeedback) {
      HapticFeedback.lightImpact();
    }

    if (!_reduceMotion) {
      _controller.forward();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!widget.enabled) return;

    if (!_reduceMotion) {
      _controller.reverse();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (!_reduceMotion) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
