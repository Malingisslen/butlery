/// MODUL1 Integration Wrapper - Complete ingredient processing pipeline
/// Provides unified interface for ingredient processing with three patterns:
/// - Pattern A: Full Pipeline (raw text → preprocessed → parsed → normalized)
/// - Pattern B: Parse + Normalize (clean text → parsed → normalized)
/// - Pattern C: Normalize Only (parsed name → normalized)
/// # Usage Guide
/// **Pattern A - Recipe Creation/Editing (Raw User Input)**
/// ```dart
/// // User types: "ca 3-5 dl mjölk (kall)"
/// final processed = IngredientProcessor.processRawIngredient('ca 3-5 dl mjölk (kall)');
/// // Result:
/// // - quantity: 5.0 (maximum from range)
/// // - unit: 'dl'
/// // - originalName: 'mjölk' (for display)
/// // - normalizedName: 'mjölk' (for search/tags)
/// // - cleanedText: '5 dl mjölk' (approximations and parentheses removed)
/// ```
/// **Pattern B - Shopping List Generation (Database Data)**
/// ```dart
/// // Database has: "2 dl hackad lök"
/// final processed = IngredientProcessor.parseAndNormalize('2 dl hackad lök');
/// // Result:
/// // - quantity: 2.0
/// // - unit: 'dl'
/// // - originalName: 'hackad lök' (for display)
/// // - normalizedName: 'lök' (preparation removed for grouping)
/// ```
/// **Pattern C - Tagging/Search (Already Parsed)**
/// ```dart
/// // Already have ingredient name from parser
/// final normalized = IngredientProcessor.normalizeIngredientName('hackad lök');
/// // Result: 'lök' (preparation removed)
/// ```
/// # Integration Points
/// - Recipe Form: Use Pattern A in `updateIngredient()` method
/// - Text Import: Use Pattern A in `_parseIngredientLine()` method
/// - Shopping Lists: Use Pattern B for better grouping (optional)
/// - Search/Tags: Use Pattern C for ingredient name normalization

import 'package:butlery/utils/text/ingredient_preprocessor.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
import 'package:butlery/utils/text/ingredient_normalizer.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';

/// Result of complete ingredient processing with all pipeline stages
class ProcessedIngredient {
  /// Parsed quantity (after preprocessing ranges, approximations)
  final double quantity;

  /// Parsed unit (dl, msk, g, etc.)
  final String unit;

  /// Original ingredient name from parser (for display)
  final String originalName;

  /// Normalized ingredient name (for search, tags, grouping)
  final String normalizedName;

  /// Category from known ingredients database
  final String? category;

  /// Whether ingredient is in known ingredients database
  final bool isKnown;

  /// Preprocessing result (null if Pattern B/C used)
  final PreprocessingResult? preprocessingFlags;

  /// Normalization result (null if Pattern A/B skipped normalization)
  final NormalizationResult? normalizationDetails;

  /// Original raw text before any processing (for audit trail)
  final String originalRawText;

  const ProcessedIngredient({
    required this.quantity,
    required this.unit,
    required this.originalName,
    required this.normalizedName,
    this.category,
    this.isKnown = false,
    this.preprocessingFlags,
    this.normalizationDetails,
    required this.originalRawText,
  });

  /// Get display string for UI (uses original name)
  String toDisplayString() {
    if (unit.isNotEmpty) {
      return '$quantity $unit $originalName';
    } else {
      return originalName;
    }
  }

  /// Get normalized string for search/grouping (uses normalized name)
  String toNormalizedString() {
    if (unit.isNotEmpty) {
      return '$unit $normalizedName';
    } else {
      return normalizedName;
    }
  }

  @override
  String toString() {
    return 'ProcessedIngredient('
        'quantity: $quantity, '
        'unit: "$unit", '
        'original: "$originalName", '
        'normalized: "$normalizedName"'
        '${category != null ? ', category: $category' : ''}'
        '${isKnown ? ' [known]' : ''}'
        ')';
  }
}

/// Unified ingredient processing system integrating MODUL1 pipeline
/// Provides three processing patterns for different use cases:
/// - Pattern A: Full pipeline for raw user input
/// - Pattern B: Parse + normalize for database data
/// - Pattern C: Normalize only for parsed names
/// Static utility class - no instantiation required.
class IngredientProcessor {
  /// Private constructor to prevent instantiation
  IngredientProcessor._();

  /// Pattern A: Full Pipeline - Raw user input → Complete processing
  /// Use for:
  /// - Recipe creation/editing (manual user input)
  /// - Text import (pasted recipes)
  /// - OCR import (photo/screenshot recipes)
  /// - Any raw recipe text from external sources
  /// Processing steps:
  /// 1. Preprocessing: Remove approximations, ranges, parentheses, instructions
  /// 2. Parsing: Extract quantity, unit, ingredient name
  /// 3. Normalization: Clean ingredient name, validate against known ingredients
  /// Example:
  /// ```dart
  /// final input = "ca 3-5 dl glutenfri mjölk (kall) till gröten";
  /// final result = IngredientProcessor.processRawIngredient(input);
  /// // Result:
  /// // - quantity: 5.0 (max from range)
  /// // - unit: 'dl'
  /// // - originalName: 'glutenfri mjölk'
  /// // - normalizedName: 'glutenfri mjölk' (diet descriptor preserved!)
  /// ```
  static ProcessedIngredient processRawIngredient(String rawText) {
    // Step 1: Preprocess - Clean up messy recipe text
    final preprocessed = IngredientPreprocessor.preprocess(rawText);

    // Step 2: Parse - Extract quantity, unit, name
    final parsed = IngredientParser.parseIngredient(preprocessed.cleaned);

    // Step 3: Normalize - Clean ingredient name for tagging
    final normalized = IngredientNormalizer.normalize(parsed.name);

    return ProcessedIngredient(
      quantity: parsed.quantity,
      unit: parsed.unit,
      originalName: parsed.name, // Keep parsed name for display
      normalizedName: normalized.normalized, // Use normalized for search/tags
      category: normalized.category,
      isKnown: normalized.isKnown,
      preprocessingFlags: preprocessed,
      normalizationDetails: normalized,
      originalRawText: rawText,
    );
  }

  /// Pattern B: Parse + Normalize - Clean text → Structured + Normalized
  /// Use for:
  /// - Shopping list generation from database recipes
  /// - Recipe display where you want better grouping
  /// - Any scenario with existing clean ingredient strings
  /// Skips preprocessing (assumes data already clean).
  /// Example:
  /// ```dart
  /// final dbIngredient = "2 dl hackad lök";
  /// final result = IngredientProcessor.parseAndNormalize(dbIngredient);
  /// // Result:
  /// // - quantity: 2.0
  /// // - unit: 'dl'
  /// // - originalName: 'hackad lök' (for display)
  /// // - normalizedName: 'lök' (preparation removed for grouping)
  /// ```
  static ProcessedIngredient parseAndNormalize(String cleanText) {
    // Skip preprocessing (data already clean)
    final parsed = IngredientParser.parseIngredient(cleanText);
    final normalized = IngredientNormalizer.normalize(parsed.name);

    return ProcessedIngredient(
      quantity: parsed.quantity,
      unit: parsed.unit,
      originalName: parsed.name,
      normalizedName: normalized.normalized,
      category: normalized.category,
      isKnown: normalized.isKnown,
      normalizationDetails: normalized,
      originalRawText: cleanText,
    );
  }

  /// Pattern C: Normalize Only - Parsed name → Normalized name
  /// Use for:
  /// - When you already have parsed data
  /// - Quick normalization for search/tagging
  /// - Categorization of ingredient names
  /// Returns just the normalization result.
  /// Example:
  /// ```dart
  /// final parsedName = "hackad lök";
  /// final normalized = IngredientProcessor.normalizeIngredientName(parsedName);
  /// // Returns: 'lök'
  /// ```
  static NormalizationResult normalizeIngredientName(String parsedName) {
    return IngredientNormalizer.normalize(parsedName);
  }

  /// Batch process multiple raw ingredients (Pattern A)
  /// Efficient processing of ingredient lists with full pipeline.
  /// Example:
  /// ```dart
  /// final rawList = [
  ///   "ca 3 dl mjölk",
  ///   "2-3 ägg",
  ///   "1 msk smör",
  /// ];
  /// final processed = IngredientProcessor.processRawIngredients(rawList);
  /// ```
  static List<ProcessedIngredient> processRawIngredients(
    List<String> rawIngredients,
  ) {
    return rawIngredients.map((raw) => processRawIngredient(raw)).toList();
  }

  /// Batch parse and normalize (Pattern B)
  /// Efficient processing of clean ingredient lists.
  static List<ProcessedIngredient> parseAndNormalizeMany(
    List<String> cleanIngredients,
  ) {
    return cleanIngredients
        .map((clean) => parseAndNormalize(clean))
        .toList();
  }

  /// Batch normalize ingredient names (Pattern C)
  /// Quick normalization of parsed ingredient names.
  static List<NormalizationResult> normalizeIngredientNames(
    List<String> parsedNames,
  ) {
    return parsedNames
        .map((name) => normalizeIngredientName(name))
        .toList();
  }

  /// Helper: Get just the cleaned text without full processing
  /// Useful when you only need preprocessing without parsing.
  /// Example:
  /// ```dart
  /// final raw = "ca 3-5 dl mjölk (kall)";
  /// final cleaned = IngredientProcessor.preprocessOnly(raw);
  /// // Returns: "5 dl mjölk"
  /// ```
  static String preprocessOnly(String rawText) {
    return IngredientPreprocessor.preprocess(rawText).cleaned;
  }

  /// Helper: Check if preprocessing would modify the text
  /// Useful for validation or user feedback.
  /// Example:
  /// ```dart
  /// if (IngredientProcessor.needsPreprocessing("ca 3 dl mjölk")) {
  ///   // Show user that text will be cleaned
  /// }
  /// ```
  static bool needsPreprocessing(String rawText) {
    final result = IngredientPreprocessor.preprocess(rawText);
    return result.cleaned != rawText;
  }

  /// Helper: Get preprocessing changes for user feedback
  /// Returns what changes would be made by preprocessing.
  /// Example:
  /// ```dart
  /// final changes = IngredientProcessor.getPreprocessingChanges("ca 3-5 dl mjölk");
  /// // Returns: {
  /// //   'hadApproximation': true,
  /// //   'hadRange': true,
  /// //   'before': 'ca 3-5 dl mjölk',
  /// //   'after': '5 dl mjölk'
  /// // }
  /// ```
  static Map<String, dynamic> getPreprocessingChanges(String rawText) {
    final result = IngredientPreprocessor.preprocess(rawText);
    return {
      'hadApproximation': result.hadApproximation,
      'hadRange': result.hadRange,
      'hadOptionalMarker': result.hadOptionalMarker,
      'hadParentheses': result.hadParentheses,
      'hadInstruction': result.hadInstruction,
      'before': result.original,
      'after': result.cleaned,
    };
  }

  /// Auto-populate normalized ingredients for a recipe
  /// Takes a list of raw ingredient strings and returns normalized versions
  /// ready for database storage in the ingredientsNormalized field.
  /// Uses Pattern B (Parse + Normalize) to extract core ingredient names
  /// without preparation words, enabling better search, filtering, and
  /// shopping list grouping.
  /// Handles failures gracefully - if an ingredient can't be normalized,
  /// it uses the original ingredient as fallback to prevent data loss.
  /// Returns null if input is null (for backward compatibility).
  /// Returns empty list if input is empty list.
  /// Example:
  /// ```dart
  /// final ingredients = ["2 dl hackad lök", "3 st stora ägg", "glutenfri pasta"];
  /// final normalized = IngredientProcessor.normalizeIngredientsForRecipe(ingredients);
  /// // Returns: ["lök", "ägg", "glutenfri pasta"]
  /// // - "hackad" removed (preparation word)
  /// // - "stora" removed (preparation word)
  /// // - "glutenfri" preserved (diet descriptor)
  /// ```
  static List<String>? normalizeIngredientsForRecipe(List<String>? ingredients) {
    if (ingredients == null) return null;
    if (ingredients.isEmpty) return [];

    final normalized = <String>[];

    for (final ingredient in ingredients) {
      if (ingredient.trim().isEmpty) continue;

      try {
        // Use Pattern B: Parse + Normalize for database ingredients
        final processed = parseAndNormalize(ingredient);
        normalized.add(processed.normalizedName);
      } catch (e) {
        // Log warning but continue processing with fallback
        AppLogger.warning('Failed to normalize ingredient "$ingredient": $e');
        // Fallback: use original ingredient to prevent data loss
        normalized.add(ingredient.trim());
      }
    }

    return normalized;
  }

  /// Check if recipe needs normalized ingredients populated
  /// Returns true if the recipe's ingredientsNormalized field needs to be
  /// populated or refreshed. This happens when:
  /// - ingredientsNormalized is null (never populated)
  /// - Length mismatch between ingredients and normalized (edited without update)
  /// Returns false if:
  /// - Both ingredients and normalized are empty (nothing to normalize)
  /// - Lengths match (already normalized, may be up-to-date)
  /// Note: This is a basic check. For thorough validation, you could
  /// compare the actual normalized values, but that's more expensive.
  /// Example:
  /// ```dart
  /// final recipe = Recipe(
  ///   core: RecipeCore(
  ///     ingredients: ["2 dl mjölk", "3 ägg"],
  ///     ingredientsNormalized: null, // Not populated
  ///   ),
  /// );
  /// if (IngredientProcessor.needsNormalization(recipe)) {
  ///   // Populate the field before saving
  /// }
  /// ```
  static bool needsNormalization(Recipe recipe) {
    final ingredients = recipe.core.ingredients;
    final normalized = recipe.core.ingredientsNormalized;

    // If normalized is null, definitely needs population
    if (normalized == null) return true;

    // If both empty, no normalization needed
    if (ingredients.isEmpty && normalized.isEmpty) return false;

    // If length mismatch, needs update
    if (ingredients.length != normalized.length) return true;

    // Lengths match - assume already normalized
    // (Could add deeper validation here if needed)
    return false;
  }
}
