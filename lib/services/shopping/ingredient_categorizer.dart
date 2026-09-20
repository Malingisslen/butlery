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

  /// BUT-1890: `limpa` is a loaf, but `köttlimpa` and `leverlimpa` are
  /// meatloaf. The bread rule that owns this word sits BELOW meat, which
  /// settles the first of those; `lever` is not a meat keyword, so the second
  /// needs the lookbehind.
  static final RegExp _loafPattern = RegExp('(?<!lever)limpa');

  /// BUT-1890: cabbage. `kål` is three letters and rides the tail of `skål`
  /// (a bowl) and every compound ending in one — "salladsskål", "tvättskål".
  /// A full leading boundary would be too strict: `vitkål`, `rödkål` and
  /// `grönkål` are the commonest spellings and all continue a word, so the
  /// rule excludes exactly the letter that makes a bowl.
  static final RegExp _cabbagePattern = RegExp('(?<!s)kål');

  /// BUT-1890: jam, which is a head noun — `jordgubbssylt` is a pantry good,
  /// not fruit. `syltlök` is a pickled onion and keeps its own head.
  static final RegExp _jamPattern = RegExp('sylt(?!lök)');

  /// BUT-1890: pork. It has to LEAD its compound: the same four letters trail
  /// `bordsvin` and `husvin`, which are wines and are answered by the drinks
  /// rule further down. That boundary cannot tell `vildsvin` from `bordsvin`,
  /// so wild boar is spelled into the meat list beside this pattern — the same
  /// move `_beerPattern` makes for `starköl`.
  static final RegExp _porkPattern = RegExp(
    '${SwedishWordBoundary.before}svin',
  );

  /// BUT-1890: `mango` is the fruit; `mangold` is chard, and it reaches the
  /// veg rule below on its own name.
  static final RegExp _mangoPattern = RegExp('mango(?!ld)');

  /// BUT-1890: `druv` covers both `druva` and the plural `druvor` the old
  /// shopping-dialog map listed. `druvsocker` is glucose, not fruit.
  static final RegExp _grapePattern = RegExp('druv(?!socker)');

  /// BUT-1890: the loan letters a Swedish menu word carries. They are absent
  /// from [SwedishWordBoundary.letters], so without them a boundary treats an
  /// accent as the END of a word and fires inside one: a bare-bounded `te`
  /// matched "cô-te" and filed a steak under drinks. `_souredMilkPattern`
  /// above hit the same thing with `é` in "filé".
  ///
  /// `te` is the measured case and has its own test. The three patterns below
  /// carry the same class because the failure is a property of the boundary,
  /// not of the token — but no Swedish grocery word has been found that
  /// exercises it for `anka`, `öl` or `vin`.
  static const String _loanLetters = 'éèêëáàâíîóôúûüç';

  /// BUT-1890: `anka` is duck, but the three letters sit inside "planka" and
  /// "banka", so it takes both boundaries.
  static final RegExp _duckPattern = RegExp(
    SwedishWordBoundary.bounded('anka', extraLetters: _loanLetters),
  );

  /// BUT-1890: the three beverage words that are too short to match bare.
  /// `te` is the one that filed a dishbrush ("diskbors-te") under drinks in
  /// the dialog's old map, so it takes both boundaries. `öl` rides inside
  /// `mjöl`, which is why it does too — and why the beer compounds a Swedish
  /// shopping line actually uses are spelled out instead. `vin` is bounded on
  /// the right only: that rejects `vinäger` and `vinbär` while keeping
  /// `rödvin`, `vitvin`, `bordsvin` and `husvin`, which a left boundary would
  /// have cost. Pork ("svin") is kept out of the wines by the meat rule, which
  /// runs above drinks.
  static final RegExp _teaPattern = RegExp(
    SwedishWordBoundary.bounded('te', extraLetters: _loanLetters),
  );
  static final RegExp _beerPattern = RegExp(
    'starköl|lättöl|folköl|mellanöl|'
    '${SwedishWordBoundary.bounded('öl', extraLetters: _loanLetters)}',
  );
  static final RegExp _winePattern = RegExp(
    'vin${SwedishWordBoundary.afterWith(_loanLetters)}',
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

    // BUT-1890: `bröd` is a head noun in Swedish, so anything carrying it is
    // bread whatever the first element says — `korvbröd` is a hot-dog roll,
    // not sausage. It sits up here with the other head-noun rules because the
    // meat rule below claims `korv`.
    if (name.contains('bröd')) {
      return ShoppingCategory.breadGrain;
    }

    // BUT-1890: the same head-noun argument, for the three aisles the engine
    // gained at the same time. `apelsinjuice` is a drink and `potatischips`
    // are crisps, but the fruit and veg rules below claim the first element of
    // both. `syltlök` is the exception that shapes the third: it is a pickled
    // onion, so jam takes the head-noun slot only when nothing follows it.
    if (name.contains('juice')) {
      return ShoppingCategory.drinks;
    }

    if (name.contains('chips')) {
      return ShoppingCategory.snacks;
    }

    if (_jamPattern.hasMatch(name)) {
      return ShoppingCategory.pantry;
    }

    if (name.contains('mjölk') ||
        name.contains('grädde') ||
        _souredMilkPattern.hasMatch(name) ||
        name.contains('yoghurt') ||
        _cheesePattern.hasMatch(name) ||
        name.contains('smör') ||
        name.contains('ägg') ||
        // BUT-1890: the named cheeses and fresh-dairy products the shopping
        // dialog's old map carried. None of them contains `ost`, so the cheese
        // pattern above never reached them.
        name.contains('crème fraiche') ||
        name.contains('crème fraîche') ||
        name.contains('kvarg') ||
        name.contains('keso') ||
        name.contains('parmesan') ||
        name.contains('mozzarella') ||
        name.contains('cheddar') ||
        name.contains('brie') ||
        name.contains('cream cheese') ||
        name.contains('ricotta') ||
        name.contains('mascarpone') ||
        name.contains('feta')) {
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
        name.contains('skinka') ||
        _porkPattern.hasMatch(name) ||
        name.contains('vildsvin') ||
        // BUT-1890: cuts and birds from the shopping dialog's old map.
        name.contains('lamm') ||
        name.contains('kalkon') ||
        name.contains('entrecote') ||
        name.contains('entrecôte') ||
        name.contains('kotlett') ||
        _duckPattern.hasMatch(name)) {
      return ShoppingCategory.meat;
    }

    // BUT-1004: fish-only.
    if (name.contains('fisk') ||
        name.contains('lax') ||
        name.contains('räk') ||
        name.contains('torsk') ||
        name.contains('sill') ||
        name.contains('makrill') ||
        name.contains('tonfisk') ||
        // BUT-1890: shellfish from the shopping dialog's old map. `mussl`
        // rather than `musslor` so the singular counts too.
        name.contains('mussl') ||
        name.contains('krabb') ||
        name.contains('hummer')) {
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
        name.contains('blåbär') ||
        // BUT-1890: fruit from the shopping dialog's old map. `melon` also
        // keeps `vattenmelon` out of the drinks rule's `vatten` below.
        name.contains('ananas') ||
        name.contains('persika') ||
        name.contains('plommon') ||
        name.contains('kiwi') ||
        name.contains('avokado') ||
        name.contains('melon') ||
        _mangoPattern.hasMatch(name) ||
        _grapePattern.hasMatch(name)) {
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
        name.contains('spenat') ||
        // BUT-1890: vegetables from the shopping dialog's old map. `mangold`
        // is named because the fruit rule above deliberately refuses it.
        name.contains('aubergine') ||
        name.contains('champinjon') ||
        name.contains('svamp') ||
        name.contains('selleri') ||
        name.contains('rödbet') ||
        name.contains('mangold') ||
        _cabbagePattern.hasMatch(name)) {
      return ShoppingCategory.veg;
    }

    // BUT-1890: the rest of the bread aisle, BELOW meat, fish, fruit and veg so
    // the compounds whose first element decides the aisle keep their answer —
    // `köttbullar`, `fiskbullar` and `potatisbullar` are not buns. `limpa`
    // carries its own guard because `lever` is not a meat keyword.
    if (_loafPattern.hasMatch(name) ||
        name.contains('frall') ||
        name.contains('bull') ||
        name.contains('croissant') ||
        name.contains('bagel') ||
        name.contains('tortilla')) {
      return ShoppingCategory.breadGrain;
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
        name.contains('havr') ||
        name.contains('müsli') ||
        // BUT-1890: dry staples from the shopping dialog's old map. `kikärt`
        // rather than a plural so both `kikärtor` and `kikärter` count.
        name.contains('spaghetti') ||
        name.contains('nudlar') ||
        name.contains('flingor') ||
        name.contains('linser') ||
        name.contains('kikärt')) {
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

    // BUT-1890: the condiments and liquid pantry goods from the shopping
    // dialog's old map. They sit after `canned` so `sojabönor` stays a tin,
    // and after fruit so `honungsmelon` stays a melon.
    if (name.contains('ketchup') ||
        name.contains('senap') ||
        name.contains('majonnäs') ||
        name.contains('soja') ||
        name.contains('vinäger') ||
        name.contains('honung') ||
        name.contains('buljong') ||
        name.contains('fond')) {
      return ShoppingCategory.pantry;
    }

    // BUT-1890: three aisles the engine had no rule for at all, so everything
    // in them answered `other`. `frys` covers fryst/frysta/frysvaror/fryspizza
    // in one token.
    if (name.contains('frys') || name.contains('glass')) {
      return ShoppingCategory.frozen;
    }

    // `nötter` reaches this rule because _beefPattern above refuses the nut
    // plural outright — the beef rule sees `nöt` and steps aside.
    if (name.contains('nötter') ||
        name.contains('popcorn') ||
        name.contains('godis') ||
        name.contains('choklad') ||
        name.contains('kex') ||
        name.contains('kakor')) {
      return ShoppingCategory.snacks;
    }

    // Drinks run LAST of the new rules: three of its words are short enough to
    // ride inside other groceries, and the bounded patterns that fix that are
    // documented where they are declared.
    if (name.contains('läsk') ||
        name.contains('vatten') ||
        name.contains('kaffe') ||
        name.contains('cider') ||
        name.contains('smoothie') ||
        _teaPattern.hasMatch(name) ||
        _beerPattern.hasMatch(name) ||
        _winePattern.hasMatch(name)) {
      return ShoppingCategory.drinks;
    }

    return ShoppingCategory.other;
  }
}
