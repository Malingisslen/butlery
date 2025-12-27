/// Platform-adaptive activity indicator widget.
/// Uses CupertinoActivityIndicator on iOS, CircularProgressIndicator on Android.

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A platform-adaptive activity indicator.
/// Automatically uses CupertinoActivityIndicator on iOS and
/// CircularProgressIndicator on Android.
class AdaptiveActivityIndicator extends StatelessWidget {
  /// Creates a platform-adaptive activity indicator.
  const AdaptiveActivityIndicator({
    super.key,
    this.radius,
    this.strokeWidth,
    this.color,
  });

  /// The radius of the spinner (iOS only).
  /// Defaults to 10.0 on iOS.
  final double? radius;

  /// The width of the progress indicator stroke (Android only).
  /// Defaults to 4.0 on Android.
  final double? strokeWidth;

  /// The color of the activity indicator.
  /// Uses theme color if not specified.
  final Color? color;

  /// Creates a small activity indicator suitable for buttons and compact spaces.
  const AdaptiveActivityIndicator.small({
    super.key,
    this.color,
  })  : radius = 8.0,
        strokeWidth = 2.0;

  /// Creates a medium activity indicator for general use.
  const AdaptiveActivityIndicator.medium({
    super.key,
    this.color,
  })  : radius = 12.0,
        strokeWidth = 3.0;

  /// Creates a large activity indicator for page-level loading states.
  const AdaptiveActivityIndicator.large({
    super.key,
    this.color,
  })  : radius = 16.0,
        strokeWidth = 4.0;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return CupertinoActivityIndicator(
        radius: radius ?? 10.0,
        color: color,
      );
    }

    return SizedBox(
      width: (radius ?? 10.0) * 2,
      height: (radius ?? 10.0) * 2,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth ?? 4.0,
        color: color,
      ),
    );
  }
}
