import 'package:butlery/constants/known_ingredients.dart';

/// Normalizes Swedish definite-form nouns to their base (indefinite) form.
///
/// Swedish adds suffixes for definite forms:
/// - -en (common gender): "löken" → "lök", "moroten" → "morot"
/// - -et (neuter gender): "smöret" → "smör", "mjölet" → "mjöl"
/// - -n (after vowels): "pastan" → "pasta", "grädden" → "grädde"
/// - -t (after vowels): "köttet" → "kött" (but -et already covers this)
/// - -na (definite plural): "äpplena" → "äpple"
/// - -erna (definite plural): "tomaterna" → "tomat"
/// - -arna (definite plural): "lökarna" → "lök"
///
/// Used by the CRF feature extractor to recognize ingredients in definite form
/// (e.g., "löken" → matches "lök" in KnownIngredients).
class SwedishDefiniteNormalizer {
  SwedishDefiniteNormalizer._();

  // Ordered longest-suffix-first so we try the most specific stripping first.
  static const _suffixRules = [
    // Definite plural forms
    _SuffixRule('erna', 0), // tomaterna → tomat
    _SuffixRule('arna', 0), // lökarna → lök
    _SuffixRule('orna', 1), // flickorna → flicka (restore -a)
    // Definite singular
    _SuffixRule('en', 0), // löken → lök
    _SuffixRule('et', 0), // smöret → smör
    _SuffixRule('na', 0), // äpplena → äpple (but check below)
    _SuffixRule('n', 0), // pastan → pasta (vowel-ending words)
    _SuffixRule('t', 0), // köttet → kött (vowel-ending neuter)
  ];

  /// Minimum word length to attempt normalization.
  static const _minLength = 4;

  /// Attempts to normalize a Swedish definite form to its base form.
  ///
  /// Returns the base form if:
  /// 1. The word is NOT already a known ingredient (no unnecessary stripping)
  /// 2. Stripping a suffix produces a word that IS a known ingredient
  ///
  /// Returns null if no valid normalization is found.
  static String? tryNormalize(String word) {
    final lower = word.toLowerCase();

    if (lower.length < _minLength) return null;

    // If the word is already known, no normalization needed
    if (KnownIngredients.isKnown(lower)) return null;

    for (final rule in _suffixRules) {
      if (!lower.endsWith(rule.suffix)) continue;

      final stripped = lower.substring(0, lower.length - rule.suffix.length);
      if (stripped.length < 2) continue;

      // Try direct strip
      if (KnownIngredients.isKnown(stripped)) return stripped;

      // Try with vowel restoration for -orna → -a pattern
      if (rule.restoreChars > 0) {
        // Not applicable for food domain currently
        continue;
      }

      // For -en suffix, try adding back -e (grädden → grädde)
      if (rule.suffix == 'en') {
        final withE = '${stripped}e';
        if (KnownIngredients.isKnown(withE)) return withE;
      }

      // For -et suffix, try adding back -e (köttet → kötte → kött not useful,
      // but smöret → smör works with direct strip above)
    }

    // Additional patterns: doubled consonant before suffix
    // "lökken" → "lök" (uncommon but possible in informal text)
    // "nötten" → "nöt" (doubled t)
    for (final suffix in ['en', 'et']) {
      if (!lower.endsWith(suffix)) continue;
      final beforeSuffix = lower.substring(0, lower.length - suffix.length);
      if (beforeSuffix.length >= 3 &&
          beforeSuffix[beforeSuffix.length - 1] ==
              beforeSuffix[beforeSuffix.length - 2]) {
        // Try removing the doubled consonant
        final undoubled = beforeSuffix.substring(0, beforeSuffix.length - 1);
        if (KnownIngredients.isKnown(undoubled)) return undoubled;
      }
    }

    return null;
  }

  /// Returns the base form if normalization succeeds, or the original word.
  static String normalize(String word) {
    return tryNormalize(word) ?? word.toLowerCase();
  }

  /// Whether a word appears to be in definite form (has a known definite suffix
  /// and its base form is a known ingredient).
  static bool isDefiniteForm(String word) {
    return tryNormalize(word) != null;
  }
}

class _SuffixRule {
  final String suffix;
  final int restoreChars;

  const _SuffixRule(this.suffix, this.restoreChars);
}
