import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/tagging/tag_status_badge.dart';

/// Badge displaying allergen status with tri-state coloring.
///
/// **UI Redesign:** Uses left-border style instead of pill/chip style:
/// - 3px left border (color based on status)
/// - Light tinted background (10-12% opacity)
/// - Icon + label in row
///
/// Both color AND shape are used for accessibility (color-blind users):
/// - FREE: Green with checkmark (safe)
/// - CONTAINS: Red with exclamation (allergen present)
/// - UNKNOWN: Grey with question mark (uncertain)
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

  /// Optional coverage percentage (0-100) shown alongside UNKNOWN badges.
  /// When provided and status is UNKNOWN, appends "(X% täckning)" to the label.
  final int? coveragePercent;

  /// Optional callback to show tag decision audit trail.
  /// Only rendered on standard (non-compact) badges.
  final VoidCallback? onInfoTap;

  const AllergenStatusBadge({
    super.key,
    required this.allergen,
    required this.status,
    this.compact = false,
    this.showLabel = true,
    this.label,
    this.coveragePercent,
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
    final entry = AllergenConfig.getByKey(allergen);
    final allergenName = entry?.key ?? allergen;

    switch (status) {
      case TriState.free:
        return context.l10n.allergenStatusFreeA11y(allergenName);
      case TriState.contains:
        return context.l10n.allergenStatusContainsA11y(allergenName);
      case TriState.unknown:
        return context.l10n.allergenStatusUnknownA11y(allergenName);
    }
  }

  (Color, IconData) _getStatusStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Shape distinction for color-blind accessibility:
    // - FREE: Circle (check_circle)
    // - CONTAINS: Triangle (warning)
    // - UNKNOWN: Circle with question (help_outline)
    switch (status) {
      case TriState.free:
        return (context.butleryColors.success, Icons.check_circle_outline);
      case TriState.contains:
        // Triangle shape distinguishes from other states
        return (cs.error, Icons.warning_amber);
      case TriState.unknown:
        return (cs.onSurfaceVariant, Icons.help_outline);
    }
  }

  String _getDisplayLabel(BuildContext context) {
    final entry = AllergenConfig.getByKey(allergen);
    String baseLabel;
    if (entry != null) {
      switch (status) {
        case TriState.free:
          baseLabel =
              entry.freeTag ?? context.l10n.allergenFreeLabel(entry.key);
        case TriState.contains:
          baseLabel = entry.containsTag;
        case TriState.unknown:
          baseLabel = context.l10n.allergenUnknownLabel(entry.key);
      }
    } else {
      // Fallback for unknown allergen keys
      switch (status) {
        case TriState.free:
          baseLabel = context.l10n.allergenFreeLabel(allergen);
        case TriState.contains:
          baseLabel = context.l10n.allergenContainsLabel(allergen);
        case TriState.unknown:
          baseLabel = context.l10n.allergenUnknownLabel(allergen);
      }
    }

    // Append coverage % for UNKNOWN status when available
    if (status == TriState.unknown && coveragePercent != null) {
      return '$baseLabel (${context.l10n.allergenCoverageLabel(coveragePercent!)})';
    }
    return baseLabel;
  }
}
