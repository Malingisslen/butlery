// lib/core/utils/shopping_category_mapper.dart

import 'package:butlery/models/unified/unified_shopping_item.dart';

/// Maps ingredient groups to shopping categories.
/// Shared between service and viewmodel layers to avoid dependency inversion.
/// Returns language-neutral ShoppingCategory constants (not display strings).
class ShoppingCategoryMapper {
  /// Map an ingredient group path to a shopping category constant.
  /// Used for auto-categorization when adding items without a category.
  static String categoryFromIngredientGroup(String group) {
    final lower = group.toLowerCase();
    if (lower.startsWith('protein/meat') ||
        lower.startsWith('protein/seafood')) {
      return ShoppingCategory.meatFish;
    }
    if (lower.startsWith('protein/dairy') || lower.startsWith('protein/egg')) {
      return ShoppingCategory.dairy;
    }
    if (lower.startsWith('vegetable') || lower.startsWith('fruit')) {
      return ShoppingCategory.fruitVeg;
    }
    if (lower.startsWith('grain')) {
      return ShoppingCategory.breadGrain;
    }
    if (lower.startsWith('spice') ||
        lower.startsWith('fat') ||
        lower.startsWith('sweetener')) {
      return ShoppingCategory.pantry;
    }
    return ShoppingCategory.other;
  }
}
