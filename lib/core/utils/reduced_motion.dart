// lib/core/utils/reduced_motion.dart
//
// BUT-527: lightweight helpers for honoring the OS "Reduce Motion" /
// `MediaQuery.disableAnimations` setting (WCAG 2.3.3, EN 301 549).
//
// See also: `lib/core/utils/animation_utils.dart` — the older class-based
// surface (`AnimationUtils.shouldAnimate(context)` / `getDuration` /
// `getCurve`). It's the right tool for `AnimationController`-driven custom
// animations (snap-to-end, skip `forward()` etc.). This file is the modern
// extension surface for declarative `AnimatedX` widgets — pass
// `myDuration.respectingMotion(context)` and the widget renders its
// end-state immediately when the user has reduced motion enabled.
//
// Why both files coexist:
//  - extension on `Duration` only works when imported as a top-level symbol;
//    keeping the helper here avoids dragging `AnimationUtils` into every
//    widget that just needs `.respectingMotion(context)`.
//  - top-level `isReducedMotion()` reads better at call sites than
//    `!AnimationUtils.shouldAnimate(context)` (double-negative).
//
// Future consolidation: if we converge on the extension surface, fold the
// class methods in here and delete `animation_utils.dart`.

import 'package:flutter/widgets.dart';

/// Returns `true` when the OS-level "Reduce Motion" / accessibility setting
/// is enabled and non-essential animations should be skipped.
///
/// Reads `MediaQuery.disableAnimationsOf(context)` rather than
/// `MediaQuery.of(context).disableAnimations` so the widget only rebuilds
/// when this specific aspect changes (Flutter inherited-aspect pattern).
bool isReducedMotion(BuildContext context) {
  return MediaQuery.disableAnimationsOf(context);
}

/// Convenience extension: collapse a `Duration` to `Duration.zero` when the
/// user has reduced motion enabled.
///
/// Use on declarative animated widgets (`AnimatedContainer`,
/// `AnimatedSwitcher`, `AnimatedOpacity`, etc.) where the animation is
/// purely decorative — informational animations like loading spinners and
/// progress bars should NOT use this; they convey state and must keep
/// playing for everyone.
///
/// Example:
/// ```dart
/// AnimatedContainer(
///   duration: const Duration(milliseconds: 200).respectingMotion(context),
///   color: isSelected ? cs.primary : cs.surface,
///   child: child,
/// );
/// ```
extension ReducedMotionDuration on Duration {
  /// Returns `Duration.zero` when reduced motion is on, else `this`.
  Duration respectingMotion(BuildContext context) {
    return isReducedMotion(context) ? Duration.zero : this;
  }
}
