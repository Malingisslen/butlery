// lib/widgets/common/indicators/loading_indicator.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/indicators/adaptive_activity_indicator.dart';

/// Configurable loading indicator with consistent styling.
/// Uses platform-adaptive activity indicator (Cupertino on iOS, Material on Android).
class LoadingIndicator extends StatelessWidget {
  final double? size;
  final double? strokeWidth;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const LoadingIndicator({
    super.key,
    this.size,
    this.strokeWidth,
    this.padding,
    this.color,
  });

  /// Small loading indicator for app bars and buttons
  const LoadingIndicator.small({
    super.key,
    this.color,
  })  : size = AppDimensions.iconSizeS,
        strokeWidth = 2,
        padding = const EdgeInsets.all(AppDimensions.spacingL);

  @override
  Widget build(BuildContext context) {
    final indicatorSize = size ?? AppDimensions.iconSizeM;
    final indicator = SizedBox(
      width: indicatorSize,
      height: indicatorSize,
      child: AdaptiveActivityIndicator(
        radius: indicatorSize / 2,
        strokeWidth: strokeWidth ?? 3,
        color: color,
      ),
    );

    if (padding != null) {
      return Padding(
        padding: padding!,
        child: indicator,
      );
    }

    return indicator;
  }
}
