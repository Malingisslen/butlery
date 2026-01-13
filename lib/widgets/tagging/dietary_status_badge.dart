import 'package:flutter/material.dart';

import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Badge displaying dietary status with tri-state coloring and shape distinction.
///
/// Both color AND shape are used for accessibility (color-blind users):
/// - FREE: Green leaf icon (diet-compatible)
/// - CONTAINS: Red triangle with exclamation (contains excluded ingredients)
/// - UNKNOWN: Grey circle with question mark (uncertain)
class DietaryStatusBadge extends StatelessWidget {
  /// The dietary key (e.g., 'vegetarisk', 'vegansk').
  final String diet;

  /// The tri-state status of this dietary restriction.
  final TriState status;

  /// Use compact size for recipe cards.
  final bool compact;

  /// Show the text label alongside the icon.
  final bool showLabel;

  /// Optional custom label override.
  final String? label;

  const DietaryStatusBadge({
    super.key,
    required this.diet,
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
    final entry = DietaryConfig.getByKey(diet);
    final dietName = entry?.tagSv ?? diet;

    switch (status) {
      case TriState.free:
        return 'Passar för $dietName kost';
      case TriState.contains:
        return 'Passar ej för $dietName kost';
      case TriState.unknown:
        return '$dietName status okänd';
    }
  }

  (Color, IconData) _getStatusStyle() {
    // Shape distinction for color-blind accessibility:
    // - FREE: Leaf (eco)
    // - CONTAINS: Triangle (warning)
    // - UNKNOWN: Circle with question (help_outline)
    switch (status) {
      case TriState.free:
        return (AppColors.success, Icons.eco_outlined);
      case TriState.contains:
        // Triangle shape distinguishes from other states
        return (AppColors.error, Icons.warning_amber);
      case TriState.unknown:
        return (AppColors.textMedium, Icons.help_outline);
    }
  }

  String _getSwedishLabel() {
    final entry = DietaryConfig.getByKey(diet);
    final displayName = entry?.tagSv ?? diet;

    switch (status) {
      case TriState.free:
        return displayName;
      case TriState.contains:
        return 'Ej $displayName';
      case TriState.unknown:
        return '$displayName?';
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
                  style: AppTextStyles.metadataEmphasized.copyWith(
                    color: color,
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
                  style: AppTextStyles.labelSmall.copyWith(
                    color: color,
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
