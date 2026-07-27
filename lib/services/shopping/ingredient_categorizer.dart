import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/utils/text/swedish_word_boundary.dart';

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

  /// BUT-1666: 'ost' (cheese) is too short to match as a bare substring —
  /// "rostad", "rostbiff" and "grillrostad" all carry it mid-word and were
  /// landing in dairy. Dart's `\b` is ASCII-only, so the boundary is spelled
  /// out with explicit Swedish-aware lookarounds.
  ///
  /// Cheese legitimately sits at either end of a Swedish compound
  /// ("ostskiva", "parmesanost"), so the rule is "at least one word
  /// boundary" rather than "both".
  static final RegExp _cheesePattern = RegExp(
    '${SwedishWordBoundary.before}ost|ost${SwedishWordBoundary.after}',
  );

  /// BUT-1666: 'nöt' (beef) only ever LEADS a compound — "nötkött",
  /// "nötfärs", "nötstek". The identical three letters trail the compound for
  /// nuts ("jordnöt", "kokosnöt", "valnöt") or take the nut plural
  /// ("nötter", "nötkärnor"), which is why a bare substring rule was filing
  /// nuts under meat.
  static final RegExp _beefPattern = RegExp(
    '${SwedishWordBoundary.before}nöt(?!ter|kärn)',
  );

  /// BUT-1666: paprika as a GROUND SPICE, in every spelling a Swedish shopping
  /// line uses. Allowlisting the two closed compounds was not enough — the
  /// spice jar is most often written open ("rökt paprika", "malen paprika"),
  /// and those were falling through to fresh produce.
  ///
  /// Matched before the veg rule, which claims any name containing 'paprika'.
  static final RegExp _groundPaprikaPattern = RegExp(
    r'paprikapulver|paprikakrydda|'
    r'(?:rökt|rökta|malen|mald|malda|torkad|torkade|söt)\s+paprika',
  );

  /// 'fil' (soured milk) needs a boundary, but `\b` is ASCII-only and treats
  /// `é` as a non-word character — so `\bfil\b` matched "filé" and filed
  /// "lax filé" under dairy, because the dairy rule runs before fish.
  /// `é` is added to the boundary class alongside å/ä/ö for that reason.
  /// `gräddfil` is spelled in as an alternative rather than by relaxing the
  /// leading boundary: it is `grädd` + `fil`, so `contains('grädde')` misses it
  /// and a preceding `d` blocks the bare-word rule. Neither this pattern nor
  /// the ASCII `\b` it replaced ever caught it — Swedish sour cream has been
  /// landing in `other` all along.
  static final RegExp _souredMilkPattern = RegExp(
    'gräddfil|${SwedishWordBoundary.beforeWith('é')}fil'
    '${SwedishWordBoundary.afterWith('é')}',
  );

  /// Returns a [ShoppingCategory] constant for [ingredientName],
  /// or [ShoppingCategory.other] when no rule matches.
  static String categorize(String ingredientName) {
    final name = ingredientName.toLowerCase().trim();

    // BUT-1666: compounds whose HEAD noun decides the aisle, resolved before
    // the broad substring rules that would otherwise shadow them. Coconut milk
    // is a canned pantry good, not dairy ('mjölk'), and ground paprika is a
    // spice, not fresh produce ('paprika').
    if (name.contains('kokosmjölk')) {
      return ShoppingCategory.canned;
    }

    if (_groundPaprikaPattern.hasMatch(name)) {
      return ShoppingCategory.spices;
    }

    if (name.contains('mjölk') ||
        name.contains('grädde') ||
        _souredMilkPattern.hasMatch(name) ||
        name.contains('yoghurt') ||
        _cheesePattern.hasMatch(name) ||
        name.contains('smör') ||
        name.contains('ägg')) {
      return ShoppingCategory.dairy;
    }

    // BUT-1004: meat-only — fish split into its own bucket below.
    // BUT-1666: 'rostbiff' is named in the ticket. Removing 'ost' from its
    // middle stopped it landing in dairy but left it in `other` — it is meat,
    // and no other rule here reaches it ('biff' alone would also catch
    // "biffar"/"lövbiff", so it earns its own place in this list).
    if (name.contains('kött') ||
        name.contains('fläsk') ||
        name.contains('biff') ||
        _beefPattern.hasMatch(name) ||
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
        // 'paprika' is deliberately absent: the veg rule above claims every
        // name containing it, so the ground-spice forms are resolved by
        // _groundPaprikaPattern at the top instead (BUT-1666 — listing it
        // here was unreachable).
        name.contains('curry')) {
      return ShoppingCategory.spices;
    }

    // 'kokosmjölk' is deliberately absent here too: the dairy rule's 'mjölk'
    // claimed it long before this block, which is why BUT-1666 hoisted it to
    // the head-noun check at the top. Leaving a copy here would be dead code.
    if (name.contains('konserv') ||
        name.contains('burk') ||
        name.contains('tomatpuré') ||
        name.contains('bönor')) {
      return ShoppingCategory.canned;
    }

    return ShoppingCategory.other;
  }
}
