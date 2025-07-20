// lib/widgets/common/search_filter/filter_toggle_button.dart

import 'package:flutter/material.dart';
import '../../../theme/app_dimensions.dart';

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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: showFilters
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          width: showFilters ? 2 : 1,
        ),
        color: showFilters
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surface,
      ),
      child: Stack(
        children: [
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              Icons.filter_list,
              color: showFilters
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            tooltip: showFilters ? 'Dölj filter' : 'Visa filter',
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
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}