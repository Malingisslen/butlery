// lib/widgets/common/indicators/status_indicator.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable status indicator component
/// 
/// Provides consistent styling for status indicators with icons.
/// Used for content type indicators, status displays, etc.
class StatusIndicator extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double? iconSize;
  final double? padding;

  const StatusIndicator({
    super.key,
    required this.icon,
    required this.color,
    this.iconSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding ?? AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Icon(
        icon, 
        color: color, 
        size: iconSize ?? AppDimensions.iconSizeAction,
      ),
    );
  }
}