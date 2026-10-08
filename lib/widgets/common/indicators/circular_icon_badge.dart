// lib/widgets/common/indicators/circular_icon_badge.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

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
  }) : icon = ButleryIcons.plus,
       backgroundColor = null,
       iconColor = null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final badgeSize = size ?? AppDimensions.iconSizeS;

    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.primary,
        shape: BoxShape.circle,
      ),
      child: ButleryIcon(
        icon,
        size: badgeSize,
        color: iconColor ?? cs.surfaceContainerHighest,
      ),
    );
  }
}
