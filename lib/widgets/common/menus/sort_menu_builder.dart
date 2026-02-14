import 'package:flutter/material.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Helper for building sort menu items used across recipe views.
class SortMenuBuilder {
  /// Build a list of PopupMenuItems for recipe sorting.
  static List<PopupMenuItem<SortCriteria>> buildItems({
    required BuildContext context,
    required SortCriteria currentSort,
    required bool sortAscending,
  }) {
    return [
      _buildItem(context, SortCriteria.title, context.l10n.sortTitle,
          Icons.title, currentSort, sortAscending),
      _buildItem(context, SortCriteria.time, context.l10n.sortTime,
          Icons.access_time, currentSort, sortAscending),
      _buildItem(context, SortCriteria.rating, context.l10n.sortRating,
          Icons.star, currentSort, sortAscending),
      _buildItem(context, SortCriteria.mealType, context.l10n.sortMealType,
          Icons.restaurant, currentSort, sortAscending),
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
