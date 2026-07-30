/// Shared recipe text normalization primitives.
///
/// Extracted verbatim from [ContentFingerprint] (plan decision 3 / condition
/// C2) so that BOTH the live GlobalRecipeCache fingerprint and the new
/// CanonicalPoolKey build on one normalization core. This file contains ONLY
/// the base (cache-compatible) logic — the pooled-ratings "strengthened"
/// transforms (diacritic folding, OCR digit repair, hashtag stripping) live on
/// the CanonicalPoolKey path alone and must NEVER be added here, or they would
/// silently change the persisted cache fingerprint (see
/// content_fingerprint_golden_test.dart, which fails on any such drift).
///
/// Behavior-preserving extraction: the constants, regexes, and method bodies
/// are moved unchanged. Do not "improve" them here without treating it as a
/// cache-invalidating change.
library;

import 'package:butlery/utils/text/swedish_word_boundary.dart';

class RecipeTextNormalizer {
  RecipeTextNormalizer._();

  /// Swedish measurement units stripped from ingredient lines.
  static const ingredientUnits = {
    'dl',
    'msk',
    'tsk',
    'krm',
    'g',
    'kg',
    'ml',
    'l',
    'cl',
    'st',
    'stk',
    'port',
    'portion',
    'portioner',
    'nypa',
    'nypor',
    'bit',
    'bitar',
    'skiva',
    'skivor',
    'klyfta',
    'klyftor',
    'kvist',
    'kvistar',
    'blad',
    'paket',
    'burk',
    'burkar',
    'påse',
    'påsar',
    'ask',
    'askar',
  };

  /// Words skipped when extracting significant title keywords.
  static const titleStopWords = {
    // Swedish common words
    'och',
    'med',
    'på',
    'i',
    'till',
    'för',
    'av',
    'en',
    'ett',
    'den',
    'det',
    'de',
    'som',
    'från',
    // English common words
    'and',
    'with',
    'the',
    'a',
    'an',
    'of',
    'for',
    'to',
    'in',
    'on',
    // Recipe qualifiers (less significant)
    'enkel',
    'enkelt',
    'lätt',
    'snabb',
    'snabbt',
    'god',
    'gott',
    'bästa',
    'klassisk',
    'klassiskt',
    'hemlagad',
    'hemlagat',
    'äkta',
  };

  /// Approximate-quantity words stripped from ingredient lines.
  static const approximateWords = {
    'ca',
    'cirka',
    'ungefär',
    'about',
    'approximately',
  };

  // Pre-compiled RegExp patterns for normalization hot paths. Public so the
  // pooled-ratings CanonicalPoolKey path can reuse the amount/parenthetical
  // patterns (which are diacritic-agnostic) while building its OWN folded unit
  // regex — it must NOT reuse [_allUnitsRe], which is bounded for un-folded
  // Swedish text while that path folds diacritics first (see the fold-first
  // note in canonical_pool_key.dart).
  static final punctuationRe = RegExp(r'[^\wåäö\s]');
  static final multiSpaceRe = RegExp(r'\s+');
  static final leadingNumbersRe = RegExp(r'^\s*\d+[\s,./]*\d*\s*');
  // ASCII `\b` here is assessed and deliberate (BUT-1713): no member of
  // [approximateWords] starts or ends with å/ä/ö, so neither the missing- nor
  // the phantom-boundary failure can fire, and re-bounding it would move the
  // persisted fingerprint a second time for no behaviour change.
  static final approximateWordsRe = RegExp(
    '\\b(${approximateWords.join('|')})\\b',
  );
  static final parentheticalRe = RegExp(r'\([^)]*\)');

  /// BUT-1713: bounded with [SwedishWordBoundary], never ASCII `\b`. Dart's
  /// `\b` treats å/ä/ö as non-word characters, so it opened a phantom boundary
  /// right before a trailing consonant: `\bl\b` matched the last letter of
  /// "mjöl", "vitkål" and "lök", and `\bst\b` the tail of "höst". The unit was
  /// then deleted from the middle of a real ingredient name — "2 dl mjöl"
  /// fingerprinted as "mjö", "1 gul lök" as "gul ök". The boundary is one-sided
  /// nowhere here: a unit is a standalone token, so both edges must hold.
  static final _allUnitsRe = SwedishWordBoundary.boundedRegExp(
    ingredientUnits.join('|'),
    caseSensitive: false,
  );

  /// Significant keywords from a recipe title (stop words + short words removed).
  static List<String> significantTitleWords(String title) {
    final normalized = title
        .toLowerCase()
        .replaceAll(punctuationRe, ' ')
        .replaceAll(multiSpaceRe, ' ')
        .trim();

    final words = normalized.split(' ');

    return words
        .where((w) => w.length > 2)
        .where((w) => !titleStopWords.contains(w))
        .toList();
  }

  /// Core ingredient name with quantities, units, and parentheticals removed.
  /// Returns an empty string if nothing useful remains.
  static String normalizeIngredientName(String ingredient) {
    var normalized = ingredient.toLowerCase().trim();

    // BUT-1739: the approximate word goes FIRST. [leadingNumbersRe] is anchored
    // at `^`, so on "ca 2 dl grädde" it found no leading digit (the line starts
    // with "ca"), and stripping "ca" afterwards left the amount stranded —
    // "2 grädde". Removing the qualifier first exposes the amount to the same
    // anchored regex, so the quantity is stripped whether or not a qualifier
    // preceded it. Order is the whole fix; neither regex changed.
    normalized = normalized.replaceAll(approximateWordsRe, '');
    normalized = normalized.replaceAll(leadingNumbersRe, '');
    normalized = normalized.replaceAll(_allUnitsRe, '');
    normalized = normalized.replaceAll(parentheticalRe, '');
    normalized = normalized.replaceAll(multiSpaceRe, ' ').trim();

    if (normalized.length < 2) {
      return '';
    }

    return normalized;
  }
}
