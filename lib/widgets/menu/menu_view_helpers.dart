// lib/widgets/menu/menu_view_helpers.dart

import 'package:butlery/models/recipe_unified.dart';

/// Helper utilities for the Veckomeny (weekly menu) view.
class MenuViewHelpers {
  /// Meal order for sorting menu sections.
  static const List<String> mealOrder = [
    'Frukost',
    'Lunch',
    'Middag',
    'Dessert',
    'Mellanmal',
    'Fika',
  ];

  /// Sorts menu sections in logical meal order (breakfast -> lunch -> dinner).
  static List<MapEntry<String, List<Recipe>>> getSortedMenuEntries(
    Map<String, List<Recipe>> menu,
  ) {
    final entries = menu.entries.toList();

    entries.sort((a, b) {
      final aIndex = mealOrder.indexOf(capitalizeCategory(a.key));
      final bIndex = mealOrder.indexOf(capitalizeCategory(b.key));

      // If both are in the order list, sort by that order
      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      }

      // If only one is in the list, it comes first
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;

      // If neither is in the list, sort alphabetically
      return a.key.compareTo(b.key);
    });

    return entries;
  }

  /// Capitalizes the first letter of a category name.
  static String capitalizeCategory(String category) {
    if (category.isEmpty) return category;
    return category[0].toUpperCase() + category.substring(1).toLowerCase();
  }
}
