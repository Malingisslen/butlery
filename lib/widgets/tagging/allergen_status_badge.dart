import 'package:flutter/material.dart';

import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Badge displaying allergen status with tri-state coloring and shape distinction.
///
/// Both color AND shape are used for accessibility (color-blind users):
/// - FREE: Green circle with checkmark (safe)
/// - CONTAINS: Red triangle with exclamation (allergen present)
/// - UNKNOWN: Grey circle with question mark (uncertain)
class AllergenStatusBadge extends StatelessWidget {
  /// The allergen key (e.g., 'gluten', 'mjölk').
  final String allergen;

  /// The tri-state status of this allergen.
  final TriState status;

  /// Use compact size for recipe cards.
  final bool compact;

  /// Show the text label alongside the icon.
  final bool showLabel;

  /// Optional custom label override.
  final String? label;

  const AllergenStatusBadge({
    super.key,
    required this.allergen,
    required this.status,
    this.compact = false,
    this.showLabel = true,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _getStatusStyle();
    final displayLabel = label ?? _getSwedishLabel();
    final semanticLabel = _getSemanticLabel();

    if (compact) {
      return _CompactBadge(
        color: color,
        icon: icon,
        semanticLabel: semanticLabel,
        label: showLabel ? displayLabel : null,
      );
    }

    return _StandardBadge(
      color: color,
      icon: icon,
      semanticLabel: semanticLabel,
      label: showLabel ? displayLabel : null,
    );
  }

  String _getSemanticLabel() {
    final entry = AllergenConfig.getByKey(allergen);
    final allergenName = entry?.key ?? allergen;

    switch (status) {
      case TriState.free:
        return 'Fri från $allergenName';
      case TriState.contains:
        return 'Innehåller $allergenName';
      case TriState.unknown:
        return '$allergenName status okänd';
    }
  }

  (Color, IconData) _getStatusStyle() {
    // Shape distinction for color-blind accessibility:
    // - FREE: Circle (check_circle)
    // - CONTAINS: Triangle (warning)
    // - UNKNOWN: Circle with question (help_outline)
    switch (status) {
      case TriState.free:
        return (AppColors.success, Icons.check_circle_outline);
      case TriState.contains:
        // Triangle shape distinguishes from other states
        return (AppColors.error, Icons.warning_amber);
      case TriState.unknown:
        return (AppColors.textMedium, Icons.help_outline);
    }
  }

  String _getSwedishLabel() {
    final entry = AllergenConfig.getByKey(allergen);
    if (entry != null) {
      switch (status) {
        case TriState.free:
          return entry.freeTag ?? '${entry.key}fri';
        case TriState.contains:
          return entry.containsTag;
        case TriState.unknown:
          return '${entry.key} okänd';
      }
    }
    // Fallback for unknown allergen keys
    switch (status) {
      case TriState.free:
        return '${allergen}fri';
      case TriState.contains:
        return 'innehåller $allergen';
      case TriState.unknown:
        return '$allergen okänd';
    }
  }
}

class _StandardBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String? label;
  final String semanticLabel;

  const _StandardBadge({
    required this.color,
    required this.icon,
    required this.semanticLabel,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMs,
            vertical: AppDimensions.spacing6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppDimensions.opacityVeryLight),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadius16),
          border: Border.all(
              color: color.withValues(alpha: AppDimensions.opacityMediumLight)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: AppDimensions.iconSize18,
                color: color,
                semanticLabel: null),
            if (label != null) ...[
              const SizedBox(width: AppDimensions.spacing6),
              ExcludeSemantics(
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompactBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String? label;
  final String semanticLabel;

  const _CompactBadge({
    required this.color,
    required this.icon,
    required this.semanticLabel,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing6,
            vertical: AppDimensions.spacingS),
        decoration: BoxDecoration(
          color: color.withValues(alpha: AppDimensions.opacityVeryLight),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppDimensions.iconSize14, color: color, semanticLabel: null),
            if (label != null) ...[
              const SizedBox(width: AppDimensions.spacingXs),
              ExcludeSemantics(
                child: Text(
                  label!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
