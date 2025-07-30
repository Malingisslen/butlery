// lib/widgets/common/indicators/filter_indicator_dot.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable filter indicator dot component
/// 
/// Provides consistent styling for filter status indicators.
/// Used to show when filters are active in various UI contexts.
class FilterIndicatorDot extends StatelessWidget {
  final Color? color;
  final double? size;

  const FilterIndicatorDot({
    super.key,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size ?? AppDimensions.spacingS,
      height: size ?? AppDimensions.spacingS,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.error,
        shape: BoxShape.circle,
      ),
    );
  }
}