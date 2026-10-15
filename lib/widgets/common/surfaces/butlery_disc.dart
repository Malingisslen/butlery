// lib/widgets/common/surfaces/butlery_disc.dart

import 'package:flutter/material.dart';

/// The one filled circle: a dot, a numbered step, a round button body or a
/// placeholder avatar that has no component of its own. People use
/// `AvatarCircle`; this is for everything round that is not a person.
class ButleryDisc extends StatelessWidget {
  const ButleryDisc({
    super.key,
    this.size,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.boxShadow,
    this.clipBehavior = Clip.none,
    this.paintOnly = false,
    this.child,
  });

  /// Diameter. Null lets [child] size the disc.
  final double? size;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
  final Clip clipBehavior;

  /// Paint with a DecoratedBox: the edge does not inset [child].
  final bool paintOnly;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final shape = BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: borderColor == null
          ? null
          : Border.all(color: borderColor!, width: borderWidth),
      boxShadow: boxShadow,
    );
    if (paintOnly) {
      return SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(decoration: shape, child: child),
      );
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: borderWidth),
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}

/// [ButleryDisc] whose fill and edge ease to new values.
class ButleryAnimatedDisc extends StatelessWidget {
  const ButleryAnimatedDisc({
    super.key,
    required this.duration,
    this.curve = Curves.linear,
    this.size,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.child,
  });

  final Duration duration;
  final Curve curve;
  final double? size;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: borderWidth),
      ),
      child: child,
    );
  }
}
