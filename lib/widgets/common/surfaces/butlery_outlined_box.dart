// lib/widgets/common/surfaces/butlery_outlined_box.dart

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';

/// The one hand-sized box with a fill, an edge and rounded corners: the
/// card, row, tile or chip body that has no component of its own. Views
/// pass colours and a radius from the theme instead of drawing a
/// `BoxDecoration`.
class ButleryOutlinedBox extends StatelessWidget {
  const ButleryOutlinedBox({
    super.key,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.border,
    this.radius = AppDimensions.radiusCard,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.constraints,
    this.alignment,
    this.clipBehavior = Clip.none,
    this.boxShadow,
    this.paintOnly = false,
    this.child,
  });

  final Color? color;

  /// Colour of a uniform edge; null draws no edge unless [border] is given.
  final Color? borderColor;
  final double borderWidth;

  /// An edge that is not the same on all sides. Wins over [borderColor].
  final BoxBorder? border;
  final double radius;

  /// Corners that differ. Wins over [radius].
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final AlignmentGeometry? alignment;
  final Clip clipBehavior;
  final List<BoxShadow>? boxShadow;

  /// Paint with a DecoratedBox: the edge does not inset [child], and the
  /// layout parameters are ignored.
  final bool paintOnly;
  final Widget? child;

  /// The same fill, edge and corners as a value, for a card that hands its
  /// look to a hover or press wrapper.
  static BoxDecoration decoration({
    Color? color,
    Color? borderColor,
    double borderWidth = 1,
    BoxBorder? border,
    double radius = AppDimensions.radiusCard,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
  }) {
    return BoxDecoration(
      color: color,
      border:
          border ??
          (borderColor == null
              ? null
              : Border.all(color: borderColor, width: borderWidth)),
      borderRadius: borderRadius ?? BorderRadius.circular(radius),
      boxShadow: boxShadow,
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = decoration(
      color: color,
      borderColor: borderColor,
      borderWidth: borderWidth,
      border: border,
      radius: radius,
      borderRadius: borderRadius,
      boxShadow: boxShadow,
    );
    if (paintOnly) return DecoratedBox(decoration: box, child: child);
    return Container(
      width: width,
      height: height,
      constraints: constraints,
      padding: padding,
      margin: margin,
      alignment: alignment,
      clipBehavior: clipBehavior,
      decoration: box,
      child: child,
    );
  }
}

/// [ButleryOutlinedBox] whose fill, edge and size ease to new values.
class ButleryAnimatedOutlinedBox extends StatelessWidget {
  const ButleryAnimatedOutlinedBox({
    super.key,
    required this.duration,
    this.curve = Curves.linear,
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = AppDimensions.radiusCard,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.alignment,
    this.child,
  });

  final Duration duration;
  final Curve curve;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final BorderRadiusGeometry? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      alignment: alignment,
      decoration: ButleryOutlinedBox.decoration(
        color: color,
        borderColor: borderColor,
        borderWidth: borderWidth,
        radius: radius,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}
