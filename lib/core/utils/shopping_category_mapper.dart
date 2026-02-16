// lib/core/utils/shopping_category_mapper.dart

import 'package:butlery/core/l10n/app_locale.dart';

/// Maps ingredient groups to shopping categories.
/// Shared between service and viewmodel layers to avoid dependency inversion.
class ShoppingCategoryMapper {
  /// Map an ingredient group path to a shopping category.
  /// Used for auto-categorization when adding items without a category.
  static String categoryFromIngredientGroup(String group) {
    final lower = group.toLowerCase();
    if (lower.startsWith('protein/meat') ||
        lower.startsWith('protein/seafood')) {
      return AppLocale.current.shoppingCatMeatFish;
    }
    if (lower.startsWith('protein/dairy') || lower.startsWith('protein/egg')) {
      return AppLocale.current.shoppingCatDairy;
    }
    if (lower.startsWith('vegetable') || lower.startsWith('fruit')) {
      return AppLocale.current.shoppingCatFruitVeg;
    }
    if (lower.startsWith('grain')) {
      return AppLocale.current.shoppingCatBreadGrain;
    }
    if (lower.startsWith('spice') ||
        lower.startsWith('fat') ||
        lower.startsWith('sweetener')) {
      return AppLocale.current.shoppingCatPantry;
    }
    return AppLocale.current.shoppingCategoryOther;
  }
}
