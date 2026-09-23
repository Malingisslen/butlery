/// The former platform-adaptive activity indicator. It now draws the plate
/// line on every platform (B-18, beslutslogg.md:25: no spinner; B-45,
/// beslutslogg.md:52: no Cupertino branch).

import 'package:flutter/material.dart';

import 'package:butlery/widgets/common/indicators/plate_line.dart';

/// The plate line under an old name.
///
/// It used to draw a CupertinoActivityIndicator on iOS and a
/// CircularProgressIndicator elsewhere. Both are spinners, which the system
/// forbids (produktregler.md:163), so it draws the indeterminate
/// [PlateLine]. [radius] and [strokeWidth] no longer change anything and
/// stay only so existing code keeps compiling; the widget is retired in
/// package 7. [color] is ignored as well: the line takes its tokens
/// (tokens.json progressTrack and surface.disabled).
class AdaptiveActivityIndicator extends StatelessWidget {
  /// Creates the indicator.
  const AdaptiveActivityIndicator({
    super.key,
    this.radius,
    this.strokeWidth,
    this.color,
    this.semanticLabel,
  });

  /// No longer used.
  final double? radius;

  /// No longer used.
  final double? strokeWidth;

  /// No longer used.
  final Color? color;

  /// What is being loaded, for the screen reader. Null gives a11yLoading.
  final String? semanticLabel;

  /// The small form. Same line.
  const AdaptiveActivityIndicator.small({
    super.key,
    this.color,
    this.semanticLabel,
  }) : radius = 8.0,
       strokeWidth = 2.0;

  /// The medium form. Same line.
  const AdaptiveActivityIndicator.medium({
    super.key,
    this.color,
    this.semanticLabel,
  }) : radius = 12.0,
       strokeWidth = 3.0;

  /// The large form. Same line.
  const AdaptiveActivityIndicator.large({
    super.key,
    this.color,
    this.semanticLabel,
  }) : radius = 16.0,
       strokeWidth = 4.0;

  @override
  Widget build(BuildContext context) {
    return PlateLine(semanticLabel: semanticLabel);
  }
}
