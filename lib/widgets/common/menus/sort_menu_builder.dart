import 'package:flutter/material.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Helper for building sort menu items used across recipe views.
class SortMenuBuilder {
  /// Build a list of PopupMenuItems for recipe sorting.
  static List<PopupMenuItem<SortCriteria>> buildItems({
    required BuildContext context,
    required SortCriteria currentSort,
    required bool sortAscending,
  }) {
    return [
      _buildItem(context, SortCriteria.title, 'Titel', Icons.title, currentSort,
          sortAscending),
      _buildItem(context, SortCriteria.time, 'Tid', Icons.access_time,
          currentSort, sortAscending),
      _buildItem(context, SortCriteria.rating, 'Betyg', Icons.star, currentSort,
          sortAscending),
      _buildItem(context, SortCriteria.mealType, 'Måltidstyp', Icons.restaurant,
          currentSort, sortAscending),
    ];
  }

  static PopupMenuItem<SortCriteria> _buildItem(
    BuildContext context,
    SortCriteria criteria,
    String label,
    IconData icon,
    SortCriteria currentSort,
    bool sortAscending,
  ) {
    final isSelected = currentSort == criteria;

    return PopupMenuItem(
      value: criteria,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
          const SizedBox(width: AppDimensions.spacingS),
          Flexible(child: Text(label)),
          const SizedBox(width: AppDimensions.spacingM),
          if (isSelected)
            Icon(
              sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.primary,
            ),
        ],
      ),
    );
  }
}
