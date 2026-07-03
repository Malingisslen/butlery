/// CanonicalPoolKey — the v1 recipe-identity key for pooled ratings
/// ("Butlery-betyget"). See tasks/pooled-ratings-plan.md (decision 1, revised
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
import 'package:butlery/services/import/cache/recipe_text_normalizer.dart';

class CanonicalPoolKey {
  CanonicalPoolKey._();

  /// Version prefix baked into the key so a future algorithm change is a
  /// distinct key space (kTagGeneratorVersion precedent). Bump on ANY change to
  /// the algorithm below.
  static const version = 'v1';

  /// Descriptive title qualifiers that vary between sources but do not change
  /// the dish. Removed before choosing the dish anchor. Stored folded
  /// (å/ä/ö→a/o) to match the folded token form.
  /// C5 follow-up: share this + [_genericAnchors] with the TS twin via one JSON
  /// asset (or a CI byte-diff) so the two languages cannot drift.
  static const _dishQualifiers = {
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
  };

  /// Generic dish-CATEGORY nouns that carry almost no disambiguating power. If
  /// the anchor reduces to one of these (a bare "Soppa", or an OCR compound
  /// split leaving "bullar" from "köttbullar"), the recipe FAILS CLOSED — it
  /// does not pool. Folded form.
  static const _genericAnchors = {
    // indefinite singular/plural
    'soppa', 'sas', 'kaka', 'kakor', 'bullar', 'bulle', 'paj', 'gryta',
    'grateng', 'sallad', 'rora', 'pytt', 'lada', 'form', 'gratin', 'mos',
    'stuvning', 'soppor', 'ratt', 'ratter', 'mat', 'middag', 'lunch', 'frukost',
    'efterratt', 'dessert', 'bakelse', 'tarta', 'paltbrod', 'brod', 'kex',
    // common definite-singular forms
    'soppan', 'sasen', 'kakan', 'grytan', 'pajen', 'salladen', 'roran',
    'tartan', 'bakelsen', 'stuvningen', 'gratengen', 'brodet', 'moset',
  };

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
    s = _repairOcrDigitsPerToken(s);
    s = s.replaceAll(RecipeTextNormalizer.leadingNumbersRe, '');
    s = s.replaceAll(_foldedApproxRe, '');
    s = s.replaceAll(_foldedUnitsRe, '');
    s = s.replaceAll(RecipeTextNormalizer.parentheticalRe, '');
    s = s.replaceAll(RecipeTextNormalizer.multiSpaceRe, ' ').trim();
    return s.length < 2 ? '' : s;
  }

  /// Folded copies of the shared unit / approximate-word lists, so unit
  /// stripping runs against the already-folded ingredient text.
  static final _foldedUnitsRe = RegExp(
    '\\b(${RecipeTextNormalizer.ingredientUnits.map(_foldDiacritics).join('|')})\\b',
    caseSensitive: false,
  );
  static final _foldedApproxRe = RegExp(
    '\\b(${RecipeTextNormalizer.approximateWords.map(_foldDiacritics).join('|')})\\b',
  );

  /// Dish anchor = longest significant title token after hashtag strip, base
  /// keyword extraction (uses diacritic stop words), folding, OCR repair, and
  /// qualifier removal. First-wins on length ties (pinned — the TS twin and the
  /// golden fixture must agree). Returns null when empty or generic.
  static String? _dishAnchor(String title) {
    final deHashed = title.replaceAll(_hashtagRe, ' ');
    final tokens = RecipeTextNormalizer.significantTitleWords(deHashed)
        .map(_foldDiacritics)
        .map(_repairOcrDigitsToken)
        .where((w) => !_dishQualifiers.contains(w))
        .toList();

    var anchor = '';
    for (final t in tokens) {
      if (t.length > anchor.length) anchor = t; // first-wins on tie
    }

    if (anchor.isEmpty || _genericAnchors.contains(anchor)) return null;
    return anchor;
  }

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
