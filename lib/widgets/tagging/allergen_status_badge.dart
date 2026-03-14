import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

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

  const AllergenStatusBadge({
    super.key,
    required this.allergen,
    required this.status,
    this.compact = false,
    this.showLabel = true,
    this.label,
    this.coveragePercent,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _getStatusStyle(context);
    final displayLabel = label ?? _getDisplayLabel(context);
    final semanticLabel = _getSemanticLabel(context);

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

/// Standard badge with left-border style (UI Redesign).
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
          vertical: AppDimensions.spacing6,
        ),
        decoration: BoxDecoration(
          // Light tinted background (10-12% opacity)
          color: color.withValues(alpha: AppDimensions.opacityVeryLight),
          // Full rectangular border on all sides per mockup
          border: Border.all(
            color: color,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppDimensions.iconSize18,
              color: color,
              semanticLabel: null,
            ),
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

/// Compact badge with left-border style (UI Redesign).
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
          vertical: AppDimensions.spacingS,
        ),
        decoration: BoxDecoration(
          // Light tinted background (10-12% opacity)
          color: color.withValues(alpha: AppDimensions.opacityVeryLight),
          // Full rectangular border on all sides per mockup
          border: Border.all(
            color: color,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppDimensions.iconSize14,
              color: color,
              semanticLabel: null,
            ),
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
