// lib/widgets/common/cards/selection_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable selection card component
/// 
/// Provides consistent styling for selectable cards.
/// Used for friend selection, item selection, etc.
class SelectionCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? elevation;
  final BorderRadius? borderRadius;

  const SelectionCard({
    super.key,
    required this.child,
    this.onTap,
    this.elevation,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation ?? AppDimensions.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(AppDimensions.borderRadiusM),
        child: child,
      ),
    );
  }
}