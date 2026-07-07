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
/// matching the `mjöl` substring in the dry-goods rule. Oils are checked
/// before dry-goods so `olivolja` does not fall through to `other`.
///
/// BUT-1004: meat/fish and fruit/veg are now resolved to the fine-grained
/// `meat`/`fish` and `fruit`/`veg` buckets. The legacy `meatFish`/`fruitVeg`
/// constants remain for back-compat with stored documents but are no longer
/// produced by this routine.
class IngredientCategorizer {
  const IngredientCategorizer._();

  /// Returns a [ShoppingCategory] constant for [ingredientName],
  /// or [ShoppingCategory.other] when no rule matches.
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

    // BUT-1004: meat-only — fish split into its own bucket below.
    if (name.contains('kött') ||
        name.contains('fläsk') ||
        name.contains('nöt') ||
        name.contains('kyckling') ||
        name.contains('korv') ||
        name.contains('bacon') ||
        name.contains('skinka')) {
      return ShoppingCategory.meat;
    }

    // BUT-1004: fish-only.
    if (name.contains('fisk') ||
        name.contains('lax') ||
        name.contains('räk') ||
        name.contains('torsk') ||
        name.contains('sill') ||
        name.contains('makrill') ||
        name.contains('tonfisk')) {
      return ShoppingCategory.fish;
    }

    // BUT-1004: fruit-only — separated from veg below.
    if (name.contains('äpple') ||
        name.contains('banan') ||
        name.contains('citron') ||
        name.contains('lime') ||
        name.contains('päron') ||
        name.contains('druva') ||
        name.contains('apelsin') ||
        name.contains('jordgubb') ||
        name.contains('hallon') ||
        name.contains('blåbär')) {
      return ShoppingCategory.fruit;
    }

    // BUT-1004: veg-only.
    if (name.contains('tomat') ||
        name.contains('lök') ||
        name.contains('vitlök') ||
        name.contains('potatis') ||
        name.contains('morot') ||
        name.contains('gurka') ||
        name.contains('paprika') ||
        name.contains('sallad') ||
        name.contains('broccoli') ||
        name.contains('blomkål') ||
        name.contains('zucchini') ||
        name.contains('spenat')) {
      return ShoppingCategory.veg;
    }

    // BUT-1004: oils route to dry_goods/pantry so they no longer fall
    // through to `other`. Checked BEFORE the dry-goods rule because the
    // substring 'olja' is the canonical token for cooking oils.
    if (name.contains('olja') ||
        name.contains('rapsolja') ||
        name.contains('olivolja') ||
        name.contains('solrosolja')) {
      return ShoppingCategory.dryGoods;
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
