// lib/widgets/common/indicators/circular_icon_badge.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable circular icon badge component
/// Provides consistent styling for circular icons with background.
/// Used for add buttons, status indicators, etc.
class CircularIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? size;

  const CircularIconBadge({
    super.key,
    required this.icon,
    this.backgroundColor,
    this.iconColor,
    this.size,
  });

  /// Add button variant
  const CircularIconBadge.add({
    super.key,
    this.size,
  })  : icon = Icons.add,
        backgroundColor = AppColors.primaryBlue,
        iconColor = AppColors.cardWhite;

  @override
  Widget build(BuildContext context) {
    final badgeSize = size ?? AppDimensions.iconSizeS;

    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primaryBlue,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: badgeSize,
        color: iconColor ?? AppColors.cardWhite,
      ),
    );
  }
}
