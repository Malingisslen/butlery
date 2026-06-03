import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Generates content-based fingerprints for recipe deduplication.
///
/// The fingerprint is based on:
/// - First 3 significant words of the title
/// - First 10 normalized ingredients (sorted alphabetically)
/// - Instruction count
///
/// This allows detection of duplicate recipes from different sources
/// (e.g., the same recipe posted on multiple blogs).
class ContentFingerprint {
  /// Swedish measurement units to strip from ingredients
  static const _units = {
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

  /// Words to skip when extracting title keywords
  static const _stopWords = {
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

  // Pre-compiled RegExp patterns for normalization hot paths
  static final _punctuationRe = RegExp(r'[^\wåäö\s]');
  static final _multiSpaceRe = RegExp(r'\s+');
  static final _leadingNumbersRe = RegExp(r'^\s*\d+[\s,./]*\d*\s*');
  static final _approximateWordsRe =
      RegExp(r'\b(ca|cirka|ungefär|about|approximately)\b');
  static final _parentheticalRe = RegExp(r'\([^)]*\)');
  static final _allUnitsRe = RegExp(
    '\\b(${_units.join('|')})\\b',
    caseSensitive: false,
  );

  /// Generate a content fingerprint for a recipe.
  ///
  /// Returns a 16-character hash string.
  /// Returns null if insufficient data for fingerprinting.
  String? generate({
    required String title,
    required List<String> ingredients,
    required int instructionCount,
  }) {
    // Need at least a title and some ingredients
    if (title.trim().isEmpty || ingredients.isEmpty) {
      return null;
    }

    // Extract title keywords
    final titleKeywords = _extractTitleKeywords(title);
    if (titleKeywords.isEmpty) {
      return null;
    }

    // Normalize and sort ingredients
    final normalizedIngredients = ingredients
        .map(_normalizeIngredient)
        .where((i) => i.isNotEmpty)
        .toSet() // Remove duplicates
        .toList()
      ..sort();

    if (normalizedIngredients.isEmpty) {
      return null;
    }

    // Build fingerprint string
    final components = [
      titleKeywords.take(3).join('_'),
      normalizedIngredients.take(10).join('|'),
      instructionCount.toString(),
    ];

    final raw = components.join(':');
    final bytes = utf8.encode(raw);
    final hash = sha256.convert(bytes);

    // Return first 16 characters (64 bits) for reasonable collision resistance
    return hash.toString().substring(0, 16);
  }

  /// Generate fingerprint from raw recipe data map.
  ///
  /// Convenience method for working with Firestore data.
  String? generateFromMap(Map<String, dynamic> recipeData) {
    final title = (recipeData['title'] as String?).orEmpty();
    final ingredients = _extractStringList(recipeData['ingredients']);
    final instructions = _extractStringList(recipeData['instructions']);

    return generate(
      title: title,
      ingredients: ingredients,
      instructionCount: instructions.length,
    );
  }

  /// Extract significant keywords from title.
  List<String> _extractTitleKeywords(String title) {
    final normalized = title
        .toLowerCase()
        .replaceAll(_punctuationRe, ' ')
        .replaceAll(_multiSpaceRe, ' ')
        .trim();

    final words = normalized.split(' ');

    // Filter out stop words and short words
    final keywords = words
        .where((w) => w.length > 2)
        .where((w) => !_stopWords.contains(w))
        .toList();

    return keywords;
  }

  /// Normalize an ingredient for fingerprinting.
  ///
  /// Removes quantities, units, and preparation words.
  /// Returns the core ingredient name.
  String _normalizeIngredient(String ingredient) {
    var normalized = ingredient.toLowerCase().trim();

    normalized = normalized.replaceAll(_leadingNumbersRe, '');
    normalized = normalized.replaceAll(_approximateWordsRe, '');
    normalized = normalized.replaceAll(_allUnitsRe, '');
    normalized = normalized.replaceAll(_parentheticalRe, '');
    normalized = normalized.replaceAll(_multiSpaceRe, ' ').trim();

    // If result is too short, it's probably not useful
    if (normalized.length < 2) {
      return '';
    }

    return normalized;
  }

  /// Safely extract a string list from a dynamic value.
  List<String> _extractStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    return [];
  }

  /// Calculate similarity score between two fingerprints (hash-based).
  ///
  /// Returns 1.0 for exact match, 0.0 for no similarity.
  /// For fuzzy comparison use [ingredientSimilarity] instead.
  double similarity(String? fingerprint1, String? fingerprint2) {
    if (fingerprint1 == null || fingerprint2 == null) {
      return 0.0;
    }
    if (fingerprint1 == fingerprint2) {
      return 1.0;
    }
    return 0.0;
  }

  /// Compute Jaccard similarity between two ingredient lists.
  ///
  /// Normalizes ingredients, builds sets, and returns |A ∩ B| / |A ∪ B|.
  /// Returns 0.0 if either list is empty.
  double ingredientSimilarity(
    List<String> ingredientsA,
    List<String> ingredientsB,
  ) {
    if (ingredientsA.isEmpty || ingredientsB.isEmpty) {
      return 0.0;
    }

    final setA = ingredientsA
        .map(_normalizeIngredient)
        .where((i) => i.isNotEmpty)
        .toSet();
    final setB = ingredientsB
        .map(_normalizeIngredient)
        .where((i) => i.isNotEmpty)
        .toSet();

    if (setA.isEmpty || setB.isEmpty) {
      return 0.0;
    }

    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;

    return intersection / union;
  }

  /// Compute overall recipe similarity combining title and ingredients.
  ///
  /// Weights: 30% title keyword overlap + 70% ingredient Jaccard.
  /// Returns a value between 0.0 and 1.0.
  double recipeSimilarity({
    required String titleA,
    required List<String> ingredientsA,
    required String titleB,
    required List<String> ingredientsB,
  }) {
    final titleScore = _titleSimilarity(titleA, titleB);
    final ingredientScore = ingredientSimilarity(ingredientsA, ingredientsB);
    const titleWeight = 0.3;
    const ingredientWeight = 0.7;
    return titleScore * titleWeight + ingredientScore * ingredientWeight;
  }

  /// Jaccard similarity on title keywords.
  double _titleSimilarity(String titleA, String titleB) {
    final keywordsA = _extractTitleKeywords(titleA).toSet();
    final keywordsB = _extractTitleKeywords(titleB).toSet();

    if (keywordsA.isEmpty || keywordsB.isEmpty) {
      return 0.0;
    }

    final intersection = keywordsA.intersection(keywordsB).length;
    final union = keywordsA.union(keywordsB).length;

    return intersection / union;
  }
}
