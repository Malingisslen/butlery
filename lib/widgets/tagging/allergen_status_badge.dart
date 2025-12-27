import 'package:flutter/material.dart';

import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/theme/app_colors.dart';

/// Badge displaying allergen status with tri-state coloring.
///
/// Colors:
/// - FREE: Green with checkmark (safe)
/// - CONTAINS: Red with X (allergen present)
/// - UNKNOWN: Yellow with warning (uncertain)
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

    if (compact) {
      return _CompactBadge(
        color: color,
        icon: icon,
        label: showLabel ? displayLabel : null,
      );
    }

    return _StandardBadge(
      color: color,
      icon: icon,
      label: showLabel ? displayLabel : null,
    );
  }

  (Color, IconData) _getStatusStyle() {
    switch (status) {
      case TriState.free:
        return (AppColors.success, Icons.check_circle_outline);
      case TriState.contains:
        return (AppColors.error, Icons.cancel_outlined);
      case TriState.unknown:
        return (AppColors.warning, Icons.help_outline);
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

  const _StandardBadge({
    required this.color,
    required this.icon,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          if (label != null) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompactBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String? label;

  const _CompactBadge({
    required this.color,
    required this.icon,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
