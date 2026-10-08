import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/tagging/tag_status_badge.dart';

/// Badge displaying allergen status with tri-state coloring.
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
  ///
  /// No call site in `lib/` constructs THIS widget with it (the same name on
  /// `TagResult` and in the tagging phases is a different thing), and that is by
  /// design rather than by neglect: both rows that
  /// build allergen badges filter UNKNOWN out (Malin, 2026-08-18), so nothing
  /// can construct the badge this argument decorates. The UNKNOWN cases in
  /// `allergen_status_badge_test.dart` still redden if the widget breaks, but
  /// they no longer stand for anything a user can reach — do not read them as
  /// coverage of a live path.
  ///
  /// Kept rather than deleted because the removal is its own decision: the
  /// filtering was a display call, not a statement that uncertainty stops being
  /// worth rendering (BUT-1895 item 4).
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
    final (tone, icon) = _getStatusStyle(context);
    final displayLabel = label ?? _getDisplayLabel(context);
    final semanticLabel = _getSemanticLabel(context);

    if (compact) {
      return TagStatusBadgeCompact(
        tone: tone,
        icon: icon,
        semanticLabel: semanticLabel,
        label: showLabel ? displayLabel : null,
      );
    }

    return TagStatusBadge(
      tone: tone,
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

  (TagStatusTone, IconData) _getStatusStyle(BuildContext context) {
    // Shape distinction for color-blind accessibility:
    // - FREE: Circle (check_circle)
    // - CONTAINS: Triangle (warning)
    // - UNKNOWN: Circle with question (help_outline)
    switch (status) {
      case TriState.free:
        return (TagStatusTone.success, ButleryIcons.circleCheck);
      case TriState.contains:
        // Triangle shape distinguishes from other states
        return (TagStatusTone.danger, ButleryIcons.triangleAlert);
      case TriState.unknown:
        return (TagStatusTone.neutral, ButleryIcons.info);
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
          // `containsTag` is stored as a slug ("innehåller-gluten") for the
          // tag system; humanize it for display: "Innehåller gluten".
          baseLabel = _humanizeContainsTag(entry.containsTag);
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

  /// Converts a dash-separated tag slug ("innehåller-gluten") into a
  /// human-readable label ("Innehåller gluten").
  static String _humanizeContainsTag(String tag) {
    final spaced = tag.replaceAll('-', ' ');
    if (spaced.isEmpty) return spaced;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}
