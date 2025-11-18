// lib/widgets/common/indicators/loading_indicator.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable loading indicator component
/// Provides consistent styling for loading indicators.
/// Used in app bars, buttons, overlays, etc.
class LoadingIndicator extends StatelessWidget {
  final double? size;
  final double? strokeWidth;
  final EdgeInsetsGeometry? padding;

  const LoadingIndicator({
    super.key,
    this.size,
    this.strokeWidth,
    this.padding,
  });

  /// Small loading indicator for app bars and buttons
  const LoadingIndicator.small({
    super.key,
  }) : size = AppDimensions.iconSizeS,
       strokeWidth = 2,
       padding = const EdgeInsets.all(AppDimensions.spacingL);

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: size ?? AppDimensions.iconSizeM,
      height: size ?? AppDimensions.iconSizeM,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth ?? 3,
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