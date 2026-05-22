import 'package:butlery/models/unified/unified_shopping_item.dart';

/// Categorizes a Swedish ingredient name into one of the
/// [ShoppingCategory] buckets used by the shopping list UI.
///
/// Pure-compute / no I/O — promoted from the previously-private
/// `ShoppingListGenerator._categorizeIngredient` so the LLM golden-set
/// runner (BUT-784 / BUT-888) can exercise the same logic the runtime
/// shopping list uses.
///
/// Rule order matters: the first matching rule wins. Dairy is checked
/// before dry goods so that `mjölk` resolves to dairy rather than
/// matching the `mjöl` substring in the dry-goods rule.
class IngredientCategorizer {
  const IngredientCategorizer._();

  /// Returns a [ShoppingCategory] constant for [ingredientName],
  /// or [ShoppingCategory.other] when no rule matches.
  ///
  /// Categorization is best-effort and intentionally coarse — see
  /// `BUT-1004` for the planned enhancement (Swedish-localized labels,
  /// meat/fish split, fruit/veg split, oils → pantry).
  static String categorize(String ingredientName) {
    final name = ingredientName.toLowerCase().trim();

    if (name.contains('mjölk') ||
        name.contains('grädde') ||
        RegExp(r'\bfil\b').hasMatch(name) ||
        name.contains('yoghurt') ||
        name.contains('ost') ||
        name.contains('smör') ||
        name.contains('ägg')) {
      return ShoppingCategory.dairy;
    }

    if (name.contains('kött') ||
        name.contains('fläsk') ||
        name.contains('nöt') ||
        name.contains('kyckling') ||
        name.contains('fisk') ||
        name.contains('lax') ||
        name.contains('räk') ||
        name.contains('korv') ||
        name.contains('bacon') ||
        name.contains('skinka')) {
      return ShoppingCategory.meatFish;
    }

    if (name.contains('tomat') ||
        name.contains('lök') ||
        name.contains('vitlök') ||
        name.contains('potatis') ||
        name.contains('morot') ||
        name.contains('gurka') ||
        name.contains('paprika') ||
        name.contains('sallad') ||
        name.contains('äpple') ||
        name.contains('banan') ||
        name.contains('citron') ||
        name.contains('lime')) {
      return ShoppingCategory.fruitVeg;
    }

    if (name.contains('mjöl') ||
        name.contains('socker') ||
        name.contains('salt') ||
        name.contains('pasta') ||
        name.contains('ris') ||
        name.contains('bröd') ||
        name.contains('havr') ||
        name.contains('müsli')) {
      return ShoppingCategory.dryGoods;
    }

    if (name.contains('peppar') ||
        name.contains('krydda') ||
        name.contains('basilika') ||
        name.contains('oregano') ||
        name.contains('timjan') ||
        name.contains('rosmarin') ||
        name.contains('paprika') ||
        name.contains('curry')) {
      return ShoppingCategory.spices;
    }

    if (name.contains('konserv') ||
        name.contains('burk') ||
        name.contains('tomatpuré') ||
        name.contains('kokosmjölk') ||
        name.contains('bönor')) {
      return ShoppingCategory.canned;
    }

    return ShoppingCategory.other;
  }
}
