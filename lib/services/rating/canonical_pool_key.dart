/// CanonicalPoolKey — the recipe-identity key for pooled ratings
/// ("Butlery-betyget"). See tasks/archive/pooled-ratings-plan.md (decision 1, revised
/// 2026-07-03 after the Step 0 gate + focused panel).
///
/// IMPORTANT — this is the CLIENT-SIDE HINT only. The aggregation Cloud
/// Function recomputes the key server-side (TS twin: functions/src/ratings/
/// canonical-pool-key.ts) and NEVER trusts a client-written key for pool
/// routing (pool-poisoning defense, decision 2). Any change here must be
/// mirrored in the TS twin and covered by the cross-language golden fixture
/// (condition C4) — the two MUST produce byte-identical keys.
///
/// Design (hybrid): normalized ingredient NAMES drive identity; a single "dish
/// anchor" (the longest significant title token, after folding + qualifier
/// removal) guards precision so two different dishes with the same ingredient
/// set (sockerkaka vs muffins) do not pool. Strengthened normalization
/// (diacritic folding, OCR digit repair, hashtag stripping) is applied ONLY
/// here — never in ContentFingerprint (condition C2). Fails closed: an empty or
/// generic dish anchor yields no key (the recipe does not pool) rather than
/// silently degrading to ingredient-only matching (conditions C3, T&S/Data
/// must-haves).
library;

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:butlery/services/import/cache/recipe_text_normalizer.dart';

class CanonicalPoolKey {
  CanonicalPoolKey._();

  /// Version prefix baked into the key so a future algorithm change is a
  /// distinct key space (kTagGeneratorVersion precedent). Bump on ANY change to
  /// the algorithm below.
  static const version = 'v2';

  /// Descriptive title qualifiers that vary between sources but do not change
  /// the dish. Removed before choosing the dish anchor. Stored folded
  /// (å/ä/ö→a/o) to match the folded token form.
  ///
  /// C5 drift guard (CLOSED): this list + [genericAnchors] + the three
  /// [RecipeTextNormalizer] lists are pinned IN ORDER to the shared source of
  /// truth test/fixtures/pool_key_wordlists.json by
  /// canonical_pool_key_wordlist_parity_test.dart (Dart) and
  /// pool-key-wordlist-parity.test.ts (TS server twin). Adding a word here
  /// without updating the JSON and the TS twin fails CI. Kept as a native const
  /// (not loaded from the asset) so the keyer stays synchronous.
  @visibleForTesting
  static const dishQualifiers = {
    'gammaldags',
    'tunna',
    'tunn',
    'tunt',
    'mjuk',
    'mjuka',
    'mjukt',
    'kramig',
    'kramiga',
    'saftig',
    'saftiga',
    'nyttig',
    'nyttiga',
    'festlig',
    'festliga',
    'matig',
    'matiga',
    'krispig',
    'krispiga',
    'ugnsbakad',
    'ugnsbakade',
    'grillad',
    'grillade',
    'stekt',
    'stekta',
    'kokt',
    'kokta',
    'perfekt',
    'perfekta',
    'lyxig',
    'lyxiga',
    'billig',
    'billiga',
    'vardaglig',
    'vardagliga',
    'fina',
    'godaste',
    'allra',
    'goda',
    'enkla',
    'snabba',
    'latta',
    'sma',
    'stor',
    'stora',
    'nya',
    'klassiska',
    'hemlagade',
    'extra',
    'supergoda',
    'varldens',
  };

  /// Whose recipe it is ("Mormors gryta"). Says nothing about the dish, so it
  /// must never become the anchor. Folded form. Pinned to the shared JSON — see
  /// [dishQualifiers].
  @visibleForTesting
  static const ownerWords = {
    'mormors',
    'farmors',
    'morfars',
    'farfars',
    'mammas',
    'pappas',
    'mosters',
    'fasters',
    'morbrors',
    'farbrors',
    'tantens',
    'min',
    'mina',
    'mitt',
    'vara',
    'familjens',
    'barnens',
    'husets',
    'kockens',
  };

  /// Dish nouns that end a Swedish compound. A token written apart directly in
  /// front of one ("socker kaka", "choklad muffins") is joined to it, so the
  /// anchor is the dish ("sockerkaka") and not its modifier ("socker"). The
  /// [genericAnchors] are heads too. Folded form. Pinned to the shared JSON —
  /// see [dishQualifiers].
  @visibleForTesting
  static const dishHeads = {
    'muffins',
    'cupcakes',
    'pudding',
    'biffar',
    'bollar',
    'pannkaka',
    'pannkakor',
    'plattar',
    'tacos',
    'pizza',
  };

  /// Generic dish-CATEGORY nouns that carry almost no disambiguating power. If
  /// the anchor reduces to one of these (a bare "Soppa", or an OCR compound
  /// split leaving "bullar" from "köttbullar"), the recipe FAILS CLOSED — it
  /// does not pool. Folded form. Pinned to the shared JSON — see [dishQualifiers].
  @visibleForTesting
  static const genericAnchors = {
    // indefinite singular/plural
    'soppa', 'sas', 'kaka', 'kakor', 'bullar', 'bulle', 'paj', 'gryta',
    'grateng', 'sallad', 'rora', 'pytt', 'lada', 'form', 'gratin', 'mos',
    'stuvning', 'soppor', 'ratt', 'ratter', 'mat', 'middag', 'lunch', 'frukost',
    'efterratt', 'dessert', 'bakelse', 'tarta', 'paltbrod', 'brod', 'kex',
    // common definite-singular forms
    'soppan', 'sasen', 'kakan', 'grytan', 'pajen', 'salladen', 'roran',
    'tartan', 'bakelsen', 'stuvningen', 'gratengen', 'brodet', 'moset',
  };

  /// Whether a stored key was made by this version of the algorithm. A key
  /// from another version names a pool the server no longer aggregates into,
  /// so a reader recomputes instead of trusting it.
  static bool isCurrent(String? key) =>
      key != null && key.startsWith('$version:');

  /// Compute the pool key for a recipe, or null if it must not pool
  /// (too little to key on, or no usable dish anchor — fail closed).
  static String? compute({
    required String title,
    required List<String> ingredients,
  }) {
    if (ingredients.isEmpty) return null;

    final names =
        ingredients
            .map(_strengthenIngredientName)
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (names.isEmpty) return null;

    final anchor = _dishAnchor(title);
    if (anchor == null) return null; // fail closed: no usable anchor

    final raw = '$anchor::${names.take(12).join('|')}';
    final hash = sha256.convert(utf8.encode(raw)).toString().substring(0, 16);
    return '$version:$hash';
  }

  /// Strengthened ingredient name. Order matters:
  /// 1. lowercase, 2. FOLD diacritics FIRST — so the whole string is ASCII and
  ///    regex word boundaries behave uniformly (the base normalizer strips a
  ///    standalone unit 'l'/'g'; on "lök"/"vetemjöl" the non-ASCII 'ö' creates a
  ///    spurious boundary that makes 'l' look standalone and be stripped —
  ///    folding first removes that inconsistency), 3. OCR digit repair per token
  ///    ("sa1t"→"salt", "d1"→"dl"), 4. strip amounts / approx / FOLDED units /
  ///    parentheticals. Uses a folded unit+approx regex, NOT the base one.
  static String _strengthenIngredientName(String raw) {
    var s = _foldDiacritics(raw.toLowerCase().trim());
    // Strip the leading amount FIRST (decimal-aware: "1,5", "0,5", "1.5", and
    // glued "500g"→"g"). Must precede OCR repair — otherwise per-token
    // leading-digit stripping turns "1,5" into ",5" (only the integer run goes),
    // and the decimal residue then survives, fragmenting the pool for the
    // pervasive decimal-amount recipes.
    s = s.replaceAll(RecipeTextNormalizer.leadingNumbersRe, '');
    s = _repairOcrDigitsPerToken(s);
    s = s.replaceAll(_foldedApproxRe, '');
    s = s.replaceAll(_foldedUnitsRe, '');
    s = s.replaceAll(RecipeTextNormalizer.parentheticalRe, '');
    s = s.replaceAll(RecipeTextNormalizer.multiSpaceRe, ' ').trim();
    return s.length < 2 ? '' : s;
  }

  /// Folded copies of the shared unit / approximate-word lists, so unit
  /// stripping runs against the already-folded ingredient text.
  static final _foldedUnitsRe = RegExp(
    // swedish-boundary-ok: the entries are folded to ASCII by _foldDiacritics
    '\\b(${RecipeTextNormalizer.ingredientUnits.map(_foldDiacritics).join('|')})\\b',
    caseSensitive: false,
  );
  static final _foldedApproxRe = RegExp(
    // swedish-boundary-ok: the entries are folded to ASCII by _foldDiacritics
    '\\b(${RecipeTextNormalizer.approximateWords.map(_foldDiacritics).join('|')})\\b',
  );

  /// Dish anchor = longest title token after hashtag strip, stop-word removal,
  /// folding, OCR repair, qualifier and owner-word removal, and joining a token
  /// to a [dishHeads]/[genericAnchors] noun written apart right after it.
  /// First-wins on length ties (pinned — the TS twin and the golden fixture must
  /// agree). Returns null when empty or generic.
  static String? _dishAnchor(String title) {
    final words = title
        .replaceAll(_hashtagRe, ' ')
        .toLowerCase()
        .replaceAll(RecipeTextNormalizer.punctuationRe, ' ')
        .replaceAll(RecipeTextNormalizer.multiSpaceRe, ' ')
        .trim()
        .split(' ');

    // A word that was dropped breaks adjacency, so only words that stood next to
    // each other in the title are joined.
    final tokens = <String>[];
    var lastKept = -2;
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.length <= 2 || RecipeTextNormalizer.titleStopWords.contains(w)) {
        continue;
      }
      final t = _repairOcrDigitsToken(_foldDiacritics(w));
      if (t.isEmpty || dishQualifiers.contains(t) || ownerWords.contains(t)) {
        continue;
      }
      // Two category words written apart ("middag gryta") stay apart, so the
      // title still fails closed as generic.
      if (lastKept == i - 1 &&
          _isHead(t) &&
          !genericAnchors.contains(tokens.last)) {
        tokens[tokens.length - 1] = tokens.last + t;
      } else {
        tokens.add(t);
      }
      lastKept = i;
    }

    var anchor = '';
    for (final t in tokens) {
      if (t.length > anchor.length) anchor = t; // first-wins on tie
    }

    if (anchor.isEmpty || genericAnchors.contains(anchor)) return null;
    return anchor;
  }

  static bool _isHead(String t) =>
      dishHeads.contains(t) || genericAnchors.contains(t);

  // `\w` is ASCII even with the unicode flag, so include åäö explicitly or a
  // Swedish-letter hashtag ("#kött") leaves a remnant ("ött") that can hijack
  // the anchor.
  static final _hashtagRe = RegExp(r'#[\wåäö]+');
  static final _hasLetterRe = RegExp(r'[a-zåäö]');
  static final _leadingDigitsRe = RegExp(r'^\d+');

  static String _foldDiacritics(String s) =>
      s.replaceAll('å', 'a').replaceAll('ä', 'a').replaceAll('ö', 'o');

  /// Repair OCR digit/letter confusions INSIDE an alphabetic token only
  /// ('sa1t'→'salt', 'd1'→'dl'). A leading numeric run is stripped FIRST so a
  /// glued quantity+unit ('500g', '2dl') is not turned into letters ('5oog')
  /// before it can be recognized as an amount; pure quantities collapse to ''.
  static String _repairOcrDigitsToken(String token) {
    final stripped = token.replaceFirst(_leadingDigitsRe, '');
    if (!_hasLetterRe.hasMatch(stripped)) return stripped;
    return stripped.replaceAll('0', 'o').replaceAll('1', 'l');
  }

  static String _repairOcrDigitsPerToken(String line) =>
      line.split(' ').map(_repairOcrDigitsToken).join(' ');
}
