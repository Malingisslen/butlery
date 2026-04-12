/// Lexicon abstraction for the menu constraint parser.
///
/// Sprint 1: only [CodeLexiconProvider] exists; the lexicon is shipped as code.
/// Sprint 2 (BUT-360) will add `FirestoreLexiconProvider` that overlays
/// operator-edited Google-Sheet data on top of the code defaults. The parser
/// only ever sees a [Lexicon] snapshot; it doesn't know or care where the
/// data came from.
library;

/// Categories of lexical data the parser needs.
///
/// Each category maps a Swedish stem (key) to a canonical key (value) used
/// downstream — e.g. dietary stems map to [DietaryConfig] keys, allergen
/// stems map to [AllergenConfig] keys, cuisines map to [CuisineConfig] keys.
enum LexiconCategory {
  numbers,
  vagueQuantity,
  everydayPhrases,
  mealStems,
  dietaryStems,
  allergenFreeStems,
  allergenNounStems,
  negationWords,
  cuisineStems,
  formatStems,
  verbObjectMap,
  themeStems,
  timeKeywords,
  dayNames,
  dayIdioms,
  subdivisionWords,
  politePreamble,
  skipFrukostMarkers,
}

/// Immutable lexicon snapshot. Built once per app session by a
/// [LexiconProvider] and passed by value to the parser.
class Lexicon {
  final Map<LexiconCategory, Map<String, String>> _entries;

  const Lexicon(Map<LexiconCategory, Map<String, String>> entries)
      : _entries = entries;

  /// Empty lexicon — useful for tests that want to verify graceful failure.
  const Lexicon.empty() : _entries = const {};

  /// Look up the map for a category. Returns an empty map if absent.
  Map<String, String> of(LexiconCategory category) =>
      _entries[category] ?? const {};

  /// Sprint 2 will use this to overlay Firestore data on top of code
  /// defaults: keys present in [overlay] win, everything else from `this`
  /// passes through. Per-category shallow merge.
  Lexicon mergedWith(Lexicon overlay) {
    final merged = <LexiconCategory, Map<String, String>>{};
    final allCategories = {..._entries.keys, ...overlay._entries.keys};
    for (final cat in allCategories) {
      merged[cat] = {
        ..._entries[cat] ?? const {},
        ...overlay._entries[cat] ?? const {},
      };
    }
    return Lexicon(merged);
  }
}

/// Loads a [Lexicon]. Implementations: [CodeLexiconProvider] (sprint 1),
/// `FirestoreLexiconProvider` (sprint 2, not yet implemented).
abstract class LexiconProvider {
  Future<Lexicon> load();
}
