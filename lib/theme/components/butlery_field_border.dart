import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// The field edge drawn [AppDimensions.controlVisualHeight] tall inside a
/// decorator that is laid out up to the 48 dp touch target (B-03), so the
/// semantics node and the hit area of a field are the full 48 while the box
/// reads 40.
class ButleryFieldBorder extends OutlineInputBorder {
  const ButleryFieldBorder({super.borderRadius, super.borderSide});

  /// [box] as drawn: a decorator no taller than the touch target loses the
  /// slack above and below the 40 dp box, a taller one (several lines) is
  /// drawn in full. The focus ring reads the same rule.
  static Rect visualBox(Rect box) {
    if (box.height > AppDimensions.minTouchTarget) return box;
    final inset = ((box.height - AppDimensions.controlVisualHeight) / 2).clamp(
      0.0,
      AppDimensions.fieldTapPad,
    );
    return Rect.fromLTRB(
      box.left,
      box.top + inset,
      box.right,
      box.bottom - inset,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      super.getInnerPath(visualBox(rect), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      super.getOuterPath(visualBox(rect), textDirection: textDirection);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    super.paint(
      canvas,
      visualBox(rect),
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }

  @override
  ButleryFieldBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) => ButleryFieldBorder(
    borderRadius: borderRadius ?? this.borderRadius,
    borderSide: borderSide ?? this.borderSide,
  );

  @override
  ButleryFieldBorder scale(double t) => ButleryFieldBorder(
    borderRadius: borderRadius * t,
    borderSide: borderSide.scale(t),
  );

  // OutlineInputBorder's own lerp hands back a plain OutlineInputBorder,
  // which would drop the inset for the rest of the animation.
  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    final result = super.lerpFrom(a, t);
    return a is ButleryFieldBorder && result is OutlineInputBorder
        ? ButleryFieldBorder(
            borderRadius: result.borderRadius,
            borderSide: result.borderSide,
          )
        : result;
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    final result = super.lerpTo(b, t);
    return b is ButleryFieldBorder && result is OutlineInputBorder
        ? ButleryFieldBorder(
            borderRadius: result.borderRadius,
            borderSide: result.borderSide,
          )
        : result;
  }
}
