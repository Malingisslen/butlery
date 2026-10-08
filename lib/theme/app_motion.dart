import 'package:flutter/animation.dart';

/// The design system's motion tokens (tokens.json `motion`). Under reduced
/// motion the end state shows at once: pass a duration through
/// `respectingMotion(context)`, or skip the controller's `forward()`.
class AppMotion {
  AppMotion._();

  /// motion.durations.micro
  static const Duration micro = Duration(milliseconds: 180);

  /// motion.durations.standard
  static const Duration standard = Duration(milliseconds: 320);

  /// motion.durations.pulse: one loop of a pulsing indicator (produktbeslut
  /// R7-4 = B).
  static const Duration pulse = Duration(milliseconds: 1200);

  /// Half of [pulse], derived and not a token: a pulse that runs
  /// `repeat(reverse: true)` takes this each way, so one loop is [pulse]
  /// (produktbeslut R8-9 = A).
  static const Duration pulseHalf = Duration(milliseconds: 600);

  /// motion.easing.standard: cubic-bezier(0.33, 0, 0.2, 1).
  static const Curve curve = Cubic(0.33, 0, 0.2, 1);
}
