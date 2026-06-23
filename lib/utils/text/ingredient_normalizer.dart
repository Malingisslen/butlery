import 'package:butlery/constants/preparation_words.dart';
import 'package:butlery/constants/known_ingredients.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/parsing/ingredient_registry_service.dart';
import 'package:butlery/utils/text/compound_splitter.dart';
import 'package:butlery/utils/text/swedish_pluralization.dart';

/// Result of ingredient normalization
class NormalizationResult {
  final String normalized;
  final bool isKnown;
  final String? category;
  final List<String> removedWords;
  final String original;

  /// Alternative ingredient names from "eller" (e.g. "vetemjöl" from "vetemjöl eller dinkelmjöl")
  final List<String> alternatives;

  /// Confidence in the normalization result (0.0 to 1.0).
  /// - 1.0: Exact compound name match
  /// - 0.95: Firestore-known single ingredient match
  /// - 0.9: Diet descriptor with known rest
  /// - 0.85: Flavor pattern match ("med X")
  /// - 0.8: Normal processing, known ingredient
  /// - 0.5: Default (no strong signal)
  /// - 0.4: Standalone diet descriptor only
  /// - 0.3: Normal processing, unknown ingredient
  /// - 0.0: Empty input
  final double confidence;

  const NormalizationResult({
    required this.normalized,
    required this.isKnown,
    this.category,
    this.removedWords = const [],
    required this.original,
    this.alternatives = const [],
    this.confidence = 0.5,
  });

  @override
  String toString() {
    return 'NormalizationResult('
        'original: "$original", '
        'normalized: "$normalized", '
        'isKnown: $isKnown, '
        'confidence: $confidence'
        '${category != null ? ', category: $category' : ''}'
        '${removedWords.isNotEmpty ? ', removed: ${removedWords.join(", ")}' : ''}'
        ')';
  }
}

/// MODUL1 Stage 2: Normalize parsed ingredient names
/// Runs AFTER IngredientParser to clean ingredient names for tagging.
/// # What Normalization Does
/// 1. Removes preparation states: "hackad lök" → "lök"
/// 2. Removes size descriptors: "stort ägg" → "ägg"
/// 3. Removes type descriptors: "mjölig potatis" → "potatis"
/// 4. Removes color descriptors: "gul lök" → "lök" (except compounds like "vitpeppar")
/// 5. Handles alternatives: "gul eller röd lök" → "lök"
/// 6. Normalizes plural: "tomater" → "tomat"
/// 7. Extracts base: "tomatsås" → "tomat"
/// 8. Validates against known ingredients
/// # CRITICAL: Special Preservation Rules
/// **PRESERVED - Diet descriptors (any position):**
/// - "glutenfri pasta" → "glutenfri pasta" ✅
/// - "pasta glutenfri" → "glutenfri pasta" ✅ (normalized order)
/// - "sockerfri läsk" → "sockerfri läsk" ✅
/// - "laktosfri mjölk" → "laktosfri mjölk" ✅
/// - "mjölk laktosfri" → "laktosfri mjölk" ✅
/// **PRESERVED - "med [flavor]" products:**
/// - "mayo med lime och jalapeño" → "mayo med lime och jalapeño" ✅
/// - "läsk med hallonsmak" → "läsk med hallonsmak" ✅
/// **PRESERVED - Compound ingredient names:**
/// - "vitpeppar" → "vitpeppar" ✅ (NOT "peppar")
/// - "svartpeppar" → "svartpeppar" ✅
/// - "kryddpeppar" → "kryddpeppar" ✅
/// # Real-World Examples
/// ```dart
/// normalize("rimmat fläsk")               // → "fläsk"
/// normalize("stort ägg")                  // → "ägg"
/// normalize("mjölig potatis")             // → "potatis"
/// normalize("gul eller röd lök")          // → "lök"
/// normalize("glutenfri pasta")            // → "glutenfri pasta" (preserved!)
/// normalize("mayo med lime och jalapeño") // → "mayo med lime och jalapeño" (preserved!)
/// normalize("vitpeppar")                  // → "vitpeppar" (compound name!)
/// ```
/// # Integration
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

  /// Default enriched ingredient set from Firestore via ServiceLocator.
  /// Returns null when ServiceLocator is not initialized (tests, offline).
  static Set<String>? get _defaultAdditionalKnown {
    return ServiceLocator.tryGet<IngredientRegistryService>()?.allIngredients;
  }

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

  /// Check if ingredient is known against static registry + optional enriched set.
  static bool _isKnown(String name, Set<String>? additionalKnown) {
    return KnownIngredients.isKnown(name) ||
        (additionalKnown != null && additionalKnown.contains(name));
  }

  /// Normalize ingredient name to base form.
  ///
  /// [additionalKnown] supplements [KnownIngredients] with Firestore-enriched
  /// ingredient names from [IngredientRegistryService.allIngredients].
  static NormalizationResult normalize(
    String rawName, {
    Set<String>? additionalKnown,
  }) {
    // Use Firestore-enriched set as default when caller doesn't provide one
    additionalKnown ??= _defaultAdditionalKnown;

    final original = rawName;
    final removedWords = <String>[];

    String cleaned = rawName.toLowerCase().trim();

    if (cleaned.isEmpty) {
      return NormalizationResult(
        normalized: '',
        isKnown: false,
        original: original,
        confidence: 0.0,
      );
    }

    // Step 1: Check if this is already a known ingredient (keep as-is!)
    // For single words: vitpeppar, kokosmjölk → preserve (already in vocabulary)
    // For multi-word: skip if any word is a removable prep word
    //   e.g., "torkad timjan" should NOT short-circuit — "torkad" is prep
    final isSingleWord = !cleaned.contains(' ');
    final isKnownExact =
        KnownIngredients.isKnown(cleaned) ||
        KnownIngredients.isCompoundName(cleaned);

    if (isKnownExact) {
      final hasRemovableWord =
          !isSingleWord &&
          cleaned
              .split(RegExp(r'\s+'))
              .any((w) => PreparationWords.shouldRemove(w));
      if (!hasRemovableWord) {
        // Normalize to singular so plural forms consolidate with their
        // singular counterparts (e.g. "tomater" → "tomat", "lökar" → "lök").
        // Only apply if the singular form is also a known ingredient to
        // prevent false stripping of compound names like "vitpeppar".
        final singular = SwedishPluralization.normalizeToSingular(cleaned);
        final useSingular =
            singular != cleaned && _isKnown(singular, additionalKnown);
        final normalized = useSingular ? singular : cleaned;
        return NormalizationResult(
          normalized: normalized,
          isKnown: true,
          category: KnownIngredients.getCategory(normalized),
          original: original,
          confidence: 1.0,
        );
      }
    }

    // Step 1b: Firestore-known single ingredients (e.g. "tahini", "harissa")
    // Safe to short-circuit: multi-word inputs like "hackad lök" won't match
    // because Firestore stores base ingredient names, not prep+ingredient combos
    if (additionalKnown != null && additionalKnown.contains(cleaned)) {
      return NormalizationResult(
        normalized: cleaned,
        isKnown: true,
        category: KnownIngredients.getCategory(cleaned),
        original: original,
        confidence: 0.95,
      );
    }

    // Step 2: Check if contains "med [flavor]" pattern (keep as-is!)
    if (_hasFlavorPattern(cleaned)) {
      return NormalizationResult(
        normalized: cleaned,
        isKnown: _isKnown(cleaned, additionalKnown),
        category: KnownIngredients.getCategory(cleaned),
        original: original,
        confidence: 0.85,
      );
    }

    // Step 3: Check for diet descriptor ANYWHERE in name (preserve it!)
    // M1 fix: Support both "glutenfri pasta" and "pasta glutenfri"
    final words = cleaned.split(RegExp(r'\s+'));
    final dietDescriptorIndex = words.indexWhere(
      (w) => _dietDescriptors.contains(w),
    );
    if (dietDescriptorIndex >= 0) {
      // Found diet descriptor - preserve it and process rest
      final dietDescriptor = words[dietDescriptorIndex];
      final otherWords = [...words]..removeAt(dietDescriptorIndex);
      final restOfName = otherWords.join(' ');

      if (restOfName.isNotEmpty) {
        final processedRest = _processName(
          restOfName,
          removedWords,
          additionalKnown,
        );
        final result = '$dietDescriptor $processedRest';

        return NormalizationResult(
          normalized: result,
          isKnown: _isKnown(result, additionalKnown),
          category: KnownIngredients.getCategory(result),
          removedWords: removedWords,
          original: original,
          confidence: 0.9,
        );
      } else {
        // MED-8: Just diet descriptor alone (e.g., "glutenfri" without ingredient)
        // Mark as NOT a known ingredient, but preserve the descriptor
        // Callers can check: if category == 'diet_descriptor' && !isKnown → diet descriptor only
        return NormalizationResult(
          normalized: dietDescriptor,
          isKnown: false, // Not a real ingredient - just a descriptor
          category:
              'diet_descriptor', // MED-8: Category to clarify this is a standalone descriptor
          original: original,
          confidence: 0.4,
        );
      }
    }

    // Step 4: Extract alternatives from "eller" before processing
    final alternatives = <String>[];
    if (cleaned.contains(' eller ')) {
      final ellerParts = cleaned.split(' eller ');
      // Store pre-"eller" parts as alternatives
      for (int i = 0; i < ellerParts.length - 1; i++) {
        final alt = ellerParts[i].trim();
        if (alt.isNotEmpty) alternatives.add(alt);
      }
    }

    // Normal processing (no special cases)
    cleaned = _processName(cleaned, removedWords, additionalKnown);

    // Step 5: Validate
    final isKnown = _isKnown(cleaned, additionalKnown);
    final category = KnownIngredients.getCategory(cleaned);

    return NormalizationResult(
      normalized: cleaned,
      isKnown: isKnown,
      category: category,
      removedWords: removedWords,
      original: original,
      alternatives: alternatives,
      confidence: isKnown ? 0.8 : 0.3,
    );
  }

  // L2 fix: Color descriptors that might form compound ingredient names
  static const _colorDescriptors = {
    'röd',
    'röda',
    'rött',
    'gul',
    'gula',
    'gult',
    'vit',
    'vita',
    'vitt',
    'grön',
    'gröna',
    'grönt',
    'svart',
    'svarta',
  };

  /// Common definite form mappings (Swedish: "the X" suffix)
  static const _irregularDefiniteForms = {
    'löken': 'lök',
    'mjölet': 'mjöl',
    'grädden': 'grädde',
    'sockret': 'socker',
    'vattnet': 'vatten',
    'smöret': 'smör',
    'brödet': 'bröd',
    'riset': 'ris',
    'saltet': 'salt',
    'ägget': 'ägg',
    'köttet': 'kött',
    'fisken': 'fisk',
    'osten': 'ost',
    'pastan': 'pasta',
    'mjölken': 'mjölk',
    'oljan': 'olja',
  };

  /// Strip Swedish definite form suffix (-en, -et, -n) with safety guard.
  static String _stripDefiniteForm(String name, Set<String>? additionalKnown) {
    if (_irregularDefiniteForms.containsKey(name)) {
      return _irregularDefiniteForms[name]!;
    }

    // Regular stripping: only if result is a known ingredient (prevents false positives)
    if (name.endsWith('en') && name.length > 3) {
      final stripped = name.substring(0, name.length - 2);
      if (_isKnown(stripped, additionalKnown)) return stripped;
    }
    if (name.endsWith('et') && name.length > 3) {
      final stripped = name.substring(0, name.length - 2);
      if (_isKnown(stripped, additionalKnown)) return stripped;
    }
    if (name.endsWith('n') && name.length > 2) {
      final stripped = name.substring(0, name.length - 1);
      if (_isKnown(stripped, additionalKnown)) return stripped;
    }

    return name;
  }

  /// Process name through all normalization steps
  static String _processName(
    String name,
    List<String> removedWords,
    Set<String>? additionalKnown,
  ) {
    var result = name;

    // Handle "eller" alternatives
    result = _handleAlternatives(result, removedWords);

    // Remove preparation words and descriptors
    result = _removePreparationWords(result, removedWords);

    // L2 fix: Check if removed colors + result might form a known compound.
    // This handles cases like "lök röd" → should become "rödlök" if it exists.
    // IMPORTANT: Skip this if "eller" alternatives were processed - colors removed
    // as alternatives (e.g., "gul eller röd lök") shouldn't form compounds.
    final hadAlternatives = removedWords.contains('eller');
    if (!hadAlternatives) {
      final removedColors = removedWords
          .where((w) => _colorDescriptors.contains(w))
          .toList();
      if (removedColors.isNotEmpty && result.isNotEmpty) {
        for (final color in removedColors) {
          // Try color + result as compound (e.g., "röd" + "lök" = "rödlök")
          final compound = '$color$result';
          if (KnownIngredients.isCompoundName(compound)) {
            return compound;
          }
          // Also try with base color form (e.g., "röda" → "röd")
          final baseColor = _getBaseColor(color);
          if (baseColor != color) {
            final baseCompound = '$baseColor$result';
            if (KnownIngredients.isCompoundName(baseCompound)) {
              return baseCompound;
            }
          }
        }
      }
    }

    // Strip definite form BEFORE plural normalization
    result = _stripDefiniteForm(result, additionalKnown);

    // Normalize plural to singular
    result = SwedishPluralization.normalizeToSingular(result);

    // Extract base ingredient from compounds
    result = _extractBaseIngredient(result, additionalKnown);

    return result;
  }

  /// Irregular Swedish neuter/plural color forms → base form
  static const _irregularColorBases = {
    'rött': 'röd',
    'vitt': 'vit',
    'grönt': 'grön',
    'gult': 'gul',
    'brunt': 'brun',
    'ljust': 'ljus',
    'mörkt': 'mörk',
  };

  /// Get base form of color (e.g., "röda" → "röd", "rött" → "röd")
  static String _getBaseColor(String color) {
    // Check irregular forms first (neuter -t forms)
    if (_irregularColorBases.containsKey(color)) {
      return _irregularColorBases[color]!;
    }
    // Regular plural -a suffix
    if (color.endsWith('a') && color.length > 2) {
      return color.substring(0, color.length - 1);
    }
    return color;
  }

  /// Handle "eller" alternatives
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

    // Keep the FULL last part after "eller" (not just last word)
    // "vanlig eller turkisk yoghurt" → "turkisk yoghurt"
    return parts.last.trim();
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

  /// Extract base ingredient from compound words.
  ///
  /// Uses [CompoundSplitter] for vocabulary-based splitting with genitive-s
  /// handling, falling back to static suffix stripping for coverage.
  static String _extractBaseIngredient(
    String name,
    Set<String>? additionalKnown,
  ) {
    // Short-circuit: if the full compound word is already known, keep it
    if (_isKnown(name, additionalKnown)) return name;

    // Try intelligent compound splitting first (handles genitive-s, scoring)
    final split = CompoundSplitter.extractBase(name, additionalKnown);
    if (split != name && _isKnown(split, additionalKnown)) return split;

    // Fallback: static suffix list for cases the splitter can't handle
    // (e.g. base not in known ingredients but suffix is recognizable)
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

        if (_isKnown(base, additionalKnown)) {
          return base;
        }
      }
    }

    return name;
  }

  /// Batch normalize multiple ingredients
  static List<NormalizationResult> normalizeMany(
    List<String> ingredients, {
    Set<String>? additionalKnown,
  }) {
    return ingredients
        .map((i) => normalize(i, additionalKnown: additionalKnown))
        .toList();
  }
}
