import 'package:butlery/constants/known_ingredients.dart';

/// Splits Swedish compound words into constituent parts.
///
/// Swedish frequently forms compound words by concatenation:
/// "vitlökspress" → "vitlök" + "s" + "press"
/// "lingonsylt" → "lingon" + "sylt"
/// "jordnötssmör" → "jordnöt" + "s" + "smör"
///
/// Uses suffix-based decomposition: tries progressively shorter suffixes,
/// checking if both the suffix and prefix (with optional joining 's')
/// are known ingredients or food-related words.
class SwedishCompoundSplitter {
  SwedishCompoundSplitter._();

  /// Minimum prefix/suffix length to consider a valid split.
  static const _minPartLength = 3;

  /// Known food-related suffixes that appear in compound ingredient names.
  /// These improve hit rate by catching non-ingredient components
  /// like "press", "kvarn", "pulver" that form food-tool compounds.
  static const _foodSuffixes = {
    'sås', 'buljong', 'fond', 'mjölk', 'grädde', 'olja', 'smör',
    'ost', 'pulver', 'flingor', 'gryn', 'frön', 'kärnor', 'nötter',
    'bär', 'sylt', 'juice', 'vatten', 'kross', 'puré', 'pasta',
    'socker', 'sirap', 'vinäger', 'peppar', 'krydda', 'salt',
    'mjöl', 'deg', 'bröd', 'kaka', 'färs', 'filé', 'kotlett',
    'korv', 'skinka', 'fläsk', 'kött', 'fisk', 'lök',
    // Tool/container suffixes for compound food items
    'press', 'kvarn', 'mos',
  };

  /// Common joining characters in Swedish compounds.
  /// "s" is the most common (bindnings-s), "o" appears rarely.
  static const _joiners = ['s', ''];

  /// Attempts to split a compound word into (prefix, suffix) parts.
  ///
  /// Returns the split as `(prefix, suffix)` if both parts are recognized,
  /// or `null` if the word is not a recognizable compound.
  ///
  /// Skips words that are already in the known compound names list
  /// (they should be kept intact, e.g. "vitpeppar").
  static (String, String)? trySplit(String word) {
    final lower = word.toLowerCase();

    // Don't split words shorter than 2 * minPartLength
    if (lower.length < _minPartLength * 2) return null;

    // Don't split already-known compound names (e.g. "vitpeppar")
    if (KnownIngredients.isCompoundName(lower)) return null;

    // Don't split words that are themselves known ingredients
    if (KnownIngredients.isKnown(lower)) return null;

    // Try splits from longest suffix to shortest
    for (var suffixLen = lower.length - _minPartLength;
        suffixLen >= _minPartLength;
        suffixLen--) {
      final suffix = lower.substring(lower.length - suffixLen);

      // Suffix must be a known ingredient or food suffix
      if (!_isKnownFoodPart(suffix)) continue;

      final prefixPart = lower.substring(0, lower.length - suffixLen);

      for (final joiner in _joiners) {
        if (!prefixPart.endsWith(joiner)) continue;

        final prefix = joiner.isEmpty
            ? prefixPart
            : prefixPart.substring(0, prefixPart.length - joiner.length);

        if (prefix.length < _minPartLength) continue;

        // Prefix should be a known ingredient or food part
        if (_isKnownFoodPart(prefix)) {
          return (prefix, suffix);
        }
      }
    }

    return null;
  }

  /// Whether a word is a known compound (has recognized parts).
  static bool isCompound(String word) => trySplit(word) != null;

  /// Gets the food-relevant suffix of a compound word, if any.
  ///
  /// For "lingonsylt" returns "sylt", for "vitlökspress" returns "press".
  /// Returns null if the word is not a compound.
  static String? compoundSuffix(String word) => trySplit(word)?.$2;

  static bool _isKnownFoodPart(String part) {
    return KnownIngredients.isKnown(part) || _foodSuffixes.contains(part);
  }
}
