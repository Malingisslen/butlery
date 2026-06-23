/// Lexicon abstraction for the menu constraint parser.
///
/// Three implementations: [CodeLexiconProvider] (hardcoded defaults),
/// [FirestoreLexiconProvider] (Firestore overlay, BUT-370), and
/// [CompositeLexiconProvider] (merges both). The parser only ever sees
/// a [Lexicon] snapshot; it doesn't know or care where the data came from.
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

  /// Overlays Firestore data on top of code defaults: keys present in
  /// [overlay] win, everything else from `this` passes through.
  /// Per-category shallow merge.
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

/// Loads a [Lexicon]. Implementations: [CodeLexiconProvider],
/// [FirestoreLexiconProvider], [CompositeLexiconProvider].
abstract class LexiconProvider {
  Future<Lexicon> load();
}
