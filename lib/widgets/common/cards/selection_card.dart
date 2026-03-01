// lib/widgets/common/cards/selection_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Reusable selection card component
/// Provides consistent styling for selectable cards.
/// Used for friend selection, item selection, etc.
class SelectionCard extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback? onTap;
  final double? elevation;
  final BorderRadius? borderRadius;

  /// Semantic label for screen readers. Required for accessibility.
  final String? semanticLabel;

  const SelectionCard({
    super.key,
    required this.child,
    this.isSelected = false,
    this.onTap,
    this.elevation,
    this.borderRadius,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius =
        borderRadius ?? BorderRadius.circular(AppDimensions.borderRadiusM);

    return Card(
      elevation: elevation ?? AppDimensions.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: effectiveBorderRadius,
        side: isSelected
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: Semantics(
        label: semanticLabel,
        button: onTap != null,
        selected: isSelected,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: child,
          ),
        ),
      ),
    );
  }
}
