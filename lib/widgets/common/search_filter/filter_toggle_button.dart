// lib/widgets/common/search_filter/filter_toggle_button.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Toggle button for showing/hiding filters
class FilterToggleButton extends StatelessWidget {
  final bool showFilters;
  final bool hasActiveFilters;
  final VoidCallback onToggle;

  const FilterToggleButton({
    super.key,
    required this.showFilters,
    required this.hasActiveFilters,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        IconButton(
          onPressed: onToggle,
          icon: Icon(
            Icons.tune,
            size: AppDimensions.iconSizeAction,
            color: showFilters ? cs.primary : cs.onSurfaceVariant,
          ),
          tooltip:
              showFilters ? context.l10n.filterHide : context.l10n.filterShow,
        ),
        // Active filters indicator
        if (hasActiveFilters && !showFilters)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: cs.secondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
