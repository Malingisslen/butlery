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
    // BUT-1164: emit the fine-grained meat/fish/fruit/veg buckets for newly
    // categorized items. The ingredient group already distinguishes meat vs
    // seafood and vegetable vs fruit, so the split is deterministic and needs
    // no data migration. Legacy `meatFish`/`fruitVeg` constants remain valid
    // only as a display fallback for already-stored Firestore docs.
    if (lower.startsWith('protein/meat')) {
      return ShoppingCategory.meat;
    }
    if (lower.startsWith('protein/seafood')) {
      return ShoppingCategory.fish;
    }
    if (lower.startsWith('protein/dairy') || lower.startsWith('protein/egg')) {
      return ShoppingCategory.dairy;
    }
    if (lower.startsWith('fruit')) {
      return ShoppingCategory.fruit;
    }
    if (lower.startsWith('vegetable')) {
      return ShoppingCategory.veg;
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
