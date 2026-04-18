import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/tagging/tag_status_badge.dart';

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

  /// Optional callback to show tag decision audit trail.
  /// Only rendered on standard (non-compact) badges.
  final VoidCallback? onInfoTap;

  const DietaryStatusBadge({
    super.key,
    required this.diet,
    required this.status,
    this.compact = false,
    this.showLabel = true,
    this.label,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _getStatusStyle(context);
    final displayLabel = label ?? _getDisplayLabel(context);
    final semanticLabel = _getSemanticLabel(context);

    if (compact) {
      return TagStatusBadgeCompact(
        color: color,
        icon: icon,
        semanticLabel: semanticLabel,
        label: showLabel ? displayLabel : null,
      );
    }

    return TagStatusBadge(
      color: color,
      icon: icon,
      semanticLabel: semanticLabel,
      label: showLabel ? displayLabel : null,
      onInfoTap: onInfoTap,
    );
  }

  String _getSemanticLabel(BuildContext context) {
    final entry = DietaryConfig.getByKey(diet);
    final dietName = entry?.tagSv ?? diet;

    switch (status) {
      case TriState.free:
        return context.l10n.dietaryStatusFreeA11y(dietName);
      case TriState.contains:
        return context.l10n.dietaryStatusContainsA11y(dietName);
      case TriState.unknown:
        return context.l10n.dietaryStatusUnknownA11y(dietName);
    }
  }

  (Color, IconData) _getStatusStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Shape distinction for color-blind accessibility:
    // - FREE: Leaf (eco)
    // - CONTAINS: Neutral "not" icon (dietary preference, not a health risk)
    // - UNKNOWN: Circle with question (help_outline)
    switch (status) {
      case TriState.free:
        return (context.butleryColors.success, Icons.eco_outlined);
      case TriState.contains:
        // Dietary "contains" = factual ("not vegetarian"), not an allergen
        // health risk. Using the same red as allergen warnings made "Ej
        // vegetarisk" look as alarming as "Innehåller gluten". Neutral grey +
        // a cancel icon keeps the message clear without overstating risk.
        return (cs.onSurfaceVariant, Icons.cancel_outlined);
      case TriState.unknown:
        return (cs.onSurfaceVariant, Icons.help_outline);
    }
  }

  String _getDisplayLabel(BuildContext context) {
    final entry = DietaryConfig.getByKey(diet);
    final displayName = entry?.tagSv ?? diet;

    switch (status) {
      case TriState.free:
        return displayName;
      case TriState.contains:
        return context.l10n.dietaryStatusNotLabel(displayName);
      case TriState.unknown:
        // Neutral "Vegetarisk: okänd" instead of "Vegetarisk?" so it doesn't
        // read like a yes/no question. Status-driven; non-interactive.
        return context.l10n.dietaryStatusUnknownLabel(displayName);
    }
  }
}
