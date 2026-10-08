import 'package:butlery/services/import/cache/recipe_text_normalizer.dart';

/// Scores how alike two recipes are, to catch duplicates from different sources
/// (e.g., the same recipe posted on multiple blogs).
class ContentFingerprint {
  // Normalization primitives (units, stop words, ingredient/title cleaning)
  // are shared with CanonicalPoolKey via RecipeTextNormalizer.

  /// Extract significant keywords from title (shared normalizer).
  List<String> _extractTitleKeywords(String title) =>
      RecipeTextNormalizer.significantTitleWords(title);

  /// Normalize an ingredient for fingerprinting (shared normalizer).
  ///
  /// Removes quantities, units, and preparation words; returns the core name.
  String _normalizeIngredient(String ingredient) =>
      RecipeTextNormalizer.normalizeIngredientName(ingredient);

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
