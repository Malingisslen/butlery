import 'package:flutter/material.dart';

import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';
import 'package:butlery/theme/app_colors.dart';

/// Badge displaying dietary status with tri-state coloring.
///
/// Colors:
/// - FREE: Green with checkmark (diet-compatible)
/// - CONTAINS: Red with X (contains excluded ingredients)
/// - UNKNOWN: Yellow with warning (uncertain)
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
        return (AppColors.success, Icons.eco_outlined);
      case TriState.contains:
        return (AppColors.error, Icons.cancel_outlined);
      case TriState.unknown:
        return (AppColors.warning, Icons.help_outline);
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
