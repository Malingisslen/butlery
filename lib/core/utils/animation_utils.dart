import 'package:flutter/material.dart';

/// Utility class for accessibility-aware animations.
///
/// Respects the user's "Reduce Motion" system setting (WCAG 2.3.3).
///
/// See also: `lib/core/utils/reduced_motion.dart` for the extension-based
/// surface (`Duration.respectingMotion(context)`) used by declarative
/// `AnimatedX` widgets. This class remains the right tool for
/// `AnimationController`-driven custom animations.
class AnimationUtils {
  AnimationUtils._();

  /// Returns true if animations should play, false if user has enabled
  /// "Reduce Motion" in their device accessibility settings.
  static bool shouldAnimate(BuildContext context) {
    return !MediaQuery.of(context).disableAnimations;
  }

  /// Returns the animation duration, or [Duration.zero] if animations
  /// are disabled by the user's accessibility settings.
  static Duration getDuration(BuildContext context, Duration normalDuration) {
    return shouldAnimate(context) ? normalDuration : Duration.zero;
  }

  /// Returns the animation curve, or [Curves.linear] if animations
  /// are disabled (for instant state changes).
  static Curve getCurve(BuildContext context,
      [Curve normalCurve = Curves.easeInOut]) {
    return shouldAnimate(context) ? normalCurve : Curves.linear;
  }

  /// Returns a duration that respects reduced motion preference.
  /// Use this for AnimationController initialization.
  ///
  /// Example:
  /// ```dart
  /// _controller = AnimationController(
  ///   duration: AnimationUtils.getReducedDuration(
  ///     context,
  ///     const Duration(milliseconds: 300),
  ///   ),
  ///   vsync: this,
  /// );
  /// ```
  static Duration getReducedDuration(
    BuildContext context,
    Duration normalDuration, {
    Duration? reducedDuration,
  }) {
    if (shouldAnimate(context)) {
      return normalDuration;
    }
    return reducedDuration ?? Duration.zero;
  }
}
