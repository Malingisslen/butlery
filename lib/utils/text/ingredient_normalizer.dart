import 'package:butlery/constants/preparation_words.dart';
import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/utils/text/swedish_pluralization.dart';

/// Result of ingredient normalization
class NormalizationResult {
  final String normalized;
  final bool isKnown;
  final String? category;
  final List<String> removedWords;
  final String original;

  const NormalizationResult({
    required this.normalized,
    required this.isKnown,
    this.category,
    this.removedWords = const [],
    required this.original,
  });

  @override
  String toString() {
    return 'NormalizationResult('
        'original: "$original", '
        'normalized: "$normalized", '
        'isKnown: $isKnown'
        '${category != null ? ', category: $category' : ''}'
        '${removedWords.isNotEmpty ? ', removed: ${removedWords.join(", ")}' : ''}'
        ')';
  }
}

/// MODUL1 Stage 2: Normalize parsed ingredient names
///
/// Runs AFTER IngredientParser to clean ingredient names for tagging.
///
/// # What Normalization Does
///
/// 1. Removes preparation states: "hackad lök" → "lök"
/// 2. Removes size descriptors: "stort ägg" → "ägg"
/// 3. Removes type descriptors: "mjölig potatis" → "potatis"
/// 4. Removes color descriptors: "gul lök" → "lök" (except compounds like "vitpeppar")
/// 5. Handles alternatives: "gul eller röd lök" → "lök"
/// 6. Normalizes plural: "tomater" → "tomat"
/// 7. Extracts base: "tomatsås" → "tomat"
/// 8. Validates against known ingredients
///
/// # CRITICAL: Special Preservation Rules
///
/// **PRESERVED - Diet descriptors:**
/// - "glutenfri pasta" → "glutenfri pasta" ✅
/// - "sockerfri läsk" → "sockerfri läsk" ✅
/// - "laktosfri mjölk" → "laktosfri mjölk" ✅
///
/// **PRESERVED - "med [flavor]" products:**
/// - "mayo med lime och jalapeño" → "mayo med lime och jalapeño" ✅
/// - "läsk med hallonsmak" → "läsk med hallonsmak" ✅
///
/// **PRESERVED - Compound ingredient names:**
/// - "vitpeppar" → "vitpeppar" ✅ (NOT "peppar")
/// - "svartpeppar" → "svartpeppar" ✅
/// - "kryddpeppar" → "kryddpeppar" ✅
///
/// # Real-World Examples
///
/// ```dart
/// normalize("rimmat fläsk")               // → "fläsk"
/// normalize("stort ägg")                  // → "ägg"
/// normalize("mjölig potatis")             // → "potatis"
/// normalize("gul eller röd lök")          // → "lök"
/// normalize("glutenfri pasta")            // → "glutenfri pasta" (preserved!)
/// normalize("mayo med lime och jalapeño") // → "mayo med lime och jalapeño" (preserved!)
/// normalize("vitpeppar")                  // → "vitpeppar" (compound name!)
/// ```
///
/// # Integration
///
/// ```dart
/// // Full pipeline
/// final preprocessed = IngredientPreprocessor.preprocess("ca 3 dl rimmat fläsk");
/// final parsed = IngredientParser.parseIngredient(preprocessed.cleaned);
/// final normalized = IngredientNormalizer.normalize(parsed.name);
/// // → "fläsk"
/// ```
class IngredientNormalizer {
  /// Private constructor to prevent instantiation
  IngredientNormalizer._();

  /// Diet descriptors to PRESERVE (user decision)
  static const _dietDescriptors = {
    'glutenfri',
    'glutenfritt',
    'glutenfria',
    'sockerfri',
    'sockerfritt',
    'sockerfria',
    'laktosfri',
    'laktosfritt',
    'laktosfria',
    'mejerifri',
    'mejerifritt',
    'mejerifria',
    'vegansk',
    'veganskt',
    'veganska',
    'vegetarisk',
    'vegetariskt',
    'vegetariska',
    'ekologisk',
    'ekologiskt',
    'ekologiska',
  };

  /// Check if text contains "med [something]" pattern (product flavor)
  static bool _hasFlavorPattern(String text) {
    return text.contains(RegExp(r'\bmed\b'));
  }

  /// Normalize ingredient name to base form
  static NormalizationResult normalize(String rawName) {
    final original = rawName;
    final removedWords = <String>[];

    String cleaned = rawName.toLowerCase().trim();

    if (cleaned.isEmpty) {
      return NormalizationResult(
        normalized: '',
        isKnown: false,
        original: original,
      );
    }

    // Step 1: Check if compound ingredient name (keep as-is!)
    if (KnownIngredients.isCompoundName(cleaned)) {
      return NormalizationResult(
        normalized: cleaned,
        isKnown: true,
        category: KnownIngredients.getCategory(cleaned),
        original: original,
      );
    }

    // Step 2: Check if contains "med [flavor]" pattern (keep as-is!)
    if (_hasFlavorPattern(cleaned)) {
      // Don't remove anything from products with flavor descriptions
      return NormalizationResult(
        normalized: cleaned,
        isKnown: KnownIngredients.isKnown(cleaned),
        category: KnownIngredients.getCategory(cleaned),
        original: original,
      );
    }

    // Step 3: Check if starts with diet descriptor (preserve it!)
    final words = cleaned.split(RegExp(r'\s+'));
    if (words.isNotEmpty && _dietDescriptors.contains(words.first)) {
      // Keep diet descriptor, but still process rest of name
      final dietDescriptor = words.first;
      final restOfName = words.skip(1).join(' ');

      if (restOfName.isNotEmpty) {
        // Process rest of name normally
        final processedRest = _processName(restOfName, removedWords);
        final result = '$dietDescriptor $processedRest';

        return NormalizationResult(
          normalized: result,
          isKnown: KnownIngredients.isKnown(result),
          category: KnownIngredients.getCategory(result),
          removedWords: removedWords,
          original: original,
        );
      } else {
        // Just diet descriptor alone
        return NormalizationResult(
          normalized: dietDescriptor,
          isKnown: false,
          category: null,
          original: original,
        );
      }
    }

    // Step 4: Normal processing (no special cases)
    cleaned = _processName(cleaned, removedWords);

    // Step 5: Validate
    final isKnown = KnownIngredients.isKnown(cleaned);
    final category = KnownIngredients.getCategory(cleaned);

    return NormalizationResult(
      normalized: cleaned,
      isKnown: isKnown,
      category: category,
      removedWords: removedWords,
      original: original,
    );
  }

  /// Process name through all normalization steps
  static String _processName(String name, List<String> removedWords) {
    var result = name;

    // Handle "eller" alternatives
    result = _handleAlternatives(result, removedWords);

    // Remove preparation words and descriptors
    result = _removePreparationWords(result, removedWords);

    // Normalize plural to singular
    result = SwedishPluralization.normalizeToSingular(result);

    // Extract base ingredient from compounds
    result = _extractBaseIngredient(result);

    return result;
  }

  /// Handle "eller" alternatives
  ///
  /// Takes the last item after "eller":
  /// - "gul eller röd lök" → "lök"
  /// - "farinsocker eller strösocker" → "strösocker"
  static String _handleAlternatives(String name, List<String> removed) {
    if (!name.contains(' eller ')) {
      return name;
    }

    final parts = name.split(' eller ');

    // Remove everything before "eller"
    for (int i = 0; i < parts.length - 1; i++) {
      final words = parts[i].trim().split(' ');
      removed.addAll(words);
    }
    removed.add('eller');

    // Take last part after "eller"
    final lastPart = parts.last.trim();
    final words = lastPart.split(' ');

    // If multiple words, remove all but last
    if (words.length > 1) {
      for (int i = 0; i < words.length - 1; i++) {
        removed.add(words[i]);
      }
      return words.last;
    }

    return lastPart;
  }

  /// Remove preparation words and descriptors
  static String _removePreparationWords(String name, List<String> removed) {
    final words = name.split(RegExp(r'\s+'));
    final kept = <String>[];

    for (final word in words) {
      if (PreparationWords.shouldRemove(word)) {
        removed.add(word);
      } else {
        kept.add(word);
      }
    }

    return kept.join(' ').trim();
  }

  /// Extract base ingredient from compound words
  ///
  /// Examples:
  /// - "tomatsås" → "tomat" (if "tomat" is known)
  /// - "kycklingfilé" → "kyckling" (if "kyckling" is known)
  /// - "köttfärs" → "kött" (if "kött" is known)
  static String _extractBaseIngredient(String name) {
    final compoundSuffixes = [
      'sås',
      'filé',
      'kött',
      'bröst',
      'lår',
      'pasta',
      'bitar',
      'tärningar',
      'skiva',
      'skivor',
      'kotlett',
      'kotletter',
      'stek',
      'färs',
      'puré',
      'passata',
      'buljong',
      'fond',
    ];

    for (final suffix in compoundSuffixes) {
      if (name.endsWith(suffix) && name.length > suffix.length + 2) {
        final base = name.substring(0, name.length - suffix.length);

        if (KnownIngredients.isKnown(base)) {
          return base;
        }
      }
    }

    return name;
  }

  /// Batch normalize multiple ingredients
  static List<NormalizationResult> normalizeMany(List<String> ingredients) {
    return ingredients.map((i) => normalize(i)).toList();
  }
}
