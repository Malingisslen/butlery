// lib/core/utils/shopping_category_mapper.dart

/// Maps ingredient groups to shopping categories.
/// Shared between service and viewmodel layers to avoid dependency inversion.
class ShoppingCategoryMapper {
  /// Map an ingredient group path to a shopping category.
  /// Used for auto-categorization when adding items without a category.
  static String categoryFromIngredientGroup(String group) {
    final lower = group.toLowerCase();
    if (lower.startsWith('protein/meat') ||
        lower.startsWith('protein/seafood')) {
      return 'Kött & fisk';
    }
    if (lower.startsWith('protein/dairy') || lower.startsWith('protein/egg')) {
      return 'Mejeri';
    }
    if (lower.startsWith('vegetable') || lower.startsWith('fruit')) {
      return 'Frukt & grönt';
    }
    if (lower.startsWith('grain')) {
      return 'Bröd & spannmål';
    }
    if (lower.startsWith('spice') ||
        lower.startsWith('fat') ||
        lower.startsWith('sweetener')) {
      return 'Skafferi';
    }
    return 'Övrigt';
  }
}
