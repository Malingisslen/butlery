import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/tier_result.dart';

/// Merges results from multiple parsing tiers.
///
/// Uses confidence-weighted merging to combine the best fields from
/// different tiers into a single high-quality result.
class RecipeMerger {
  /// Minimum confidence improvement to prefer a new field value.
  static const double _confidenceThreshold = 0.1;

  /// Merge multiple tier results into a single best result.
  ///
  /// Takes the highest-confidence value for each field.
  ParsedRecipe? merge(List<TierResult> results) {
    // Filter to successful results
    final successful = results
        .where((r) => r.success && r.recipe != null)
        .toList();

    if (successful.isEmpty) return null;

    // If only one result, return it
    if (successful.length == 1) {
      return successful.first.recipe;
    }

    // Sort by quality (highest first)
    successful.sort((a, b) => b.quality.compareTo(a.quality));

    // Start with the best result
    var merged = successful.first.recipe!;

    // Merge in better fields from other results
    for (var i = 1; i < successful.length; i++) {
      final other = successful[i].recipe!;
      merged = _mergeRecipes(merged, other);
    }

    // Update metadata to reflect merging
    final tierResults = results
        .map(
          (r) => TierResult(
            tierName: r.tierName,
            recipe: null, // Don't include full recipes in metadata
            success: r.success,
            quality: r.quality,
            duration: r.duration,
            costSek: r.costSek,
            tokensUsed: r.tokensUsed,
            failureReason: r.failureReason,
          ),
        )
        .toList();

    return merged.copyWith(
      metadata: merged.metadata.copyWith(
        tierResults: tierResults,
      ),
    );
  }

  /// Merge two recipes, taking the higher-confidence value for each field.
  ParsedRecipe _mergeRecipes(ParsedRecipe primary, ParsedRecipe secondary) {
    return ParsedRecipe(
      title: _mergeField(primary.title, secondary.title),
      portions: _mergeField(primary.portions, secondary.portions),
      ingredients: _mergeIngredients(
        primary.ingredients,
        secondary.ingredients,
      ),
      instructions: _mergeField(primary.instructions, secondary.instructions),
      totalTime: _mergeField(primary.totalTime, secondary.totalTime),
      metadata: primary.metadata, // Keep primary metadata
      imageUrl: primary.imageUrl ?? secondary.imageUrl,
      description: primary.description ?? secondary.description,
    );
  }

  /// Merge a single field, preferring higher confidence.
  FieldResult<T> _mergeField<T>(
    FieldResult<T> primary,
    FieldResult<T> secondary,
  ) {
    // If primary has no value, use secondary
    if (!primary.hasValue && secondary.hasValue) {
      return secondary;
    }

    // If secondary has no value, keep primary
    if (!secondary.hasValue) {
      return primary;
    }

    // Both have values - use higher confidence
    if (secondary.confidenceScore >
        primary.confidenceScore + _confidenceThreshold) {
      return secondary;
    }

    return primary;
  }

  /// Merge ingredients with special handling for lists.
  FieldResult<List<ParsedIngredient>> _mergeIngredients(
    FieldResult<List<ParsedIngredient>> primary,
    FieldResult<List<ParsedIngredient>> secondary,
  ) {
    if (!primary.hasValue && secondary.hasValue) {
      return secondary;
    }

    if (!secondary.hasValue) {
      return primary;
    }

    // Both have values
    final primaryList = primary.value!;
    final secondaryList = secondary.value!;

    // If secondary has significantly more ingredients, prefer it
    if (secondaryList.length > primaryList.length * 1.5) {
      return secondary;
    }

    // If secondary has higher average confidence, prefer it
    final primaryAvg = _averageConfidence(primaryList);
    final secondaryAvg = _averageConfidence(secondaryList);

    if (secondaryAvg > primaryAvg + 0.2) {
      return secondary;
    }

    // Try to merge individual ingredients
    final merged = _mergeIngredientLists(primaryList, secondaryList);

    // Calculate new confidence based on merge
    final mergedAvg = _averageConfidence(merged);
    final confidence = mergedAvg > 0.7
        ? ParseConfidence.high
        : mergedAvg > 0.4
        ? ParseConfidence.medium
        : ParseConfidence.low;

    return FieldResult(
      value: merged,
      confidence: confidence,
      failureReason: null,
    );
  }

  double _averageConfidence(List<ParsedIngredient> ingredients) {
    if (ingredients.isEmpty) return 0.0;
    final total = ingredients
        .map((i) => i.confidence.score)
        .reduce((a, b) => a + b);
    return total / ingredients.length;
  }

  /// Merge two ingredient lists, preferring more structured versions.
  List<ParsedIngredient> _mergeIngredientLists(
    List<ParsedIngredient> primary,
    List<ParsedIngredient> secondary,
  ) {
    final merged = <ParsedIngredient>[];
    final usedSecondaryIndices = <int>{};

    for (final p in primary) {
      // Try to find matching ingredient in secondary
      var bestMatch = p;
      var bestMatchIndex = -1;

      for (var i = 0; i < secondary.length; i++) {
        if (usedSecondaryIndices.contains(i)) continue;

        final s = secondary[i];
        if (_ingredientsSimilar(p, s)) {
          // Use the more structured one
          if (s.confidence.score > p.confidence.score) {
            bestMatch = s;
            bestMatchIndex = i;
          }
          break;
        }
      }

      merged.add(bestMatch);
      if (bestMatchIndex >= 0) {
        usedSecondaryIndices.add(bestMatchIndex);
      }
    }

    // Add any secondary ingredients that weren't matched
    for (var i = 0; i < secondary.length; i++) {
      if (!usedSecondaryIndices.contains(i)) {
        // Only add if it's unique
        final s = secondary[i];
        if (!merged.any((m) => _ingredientsSimilar(m, s))) {
          merged.add(s);
        }
      }
    }

    return merged;
  }

  /// Check if two ingredients are likely the same.
  bool _ingredientsSimilar(ParsedIngredient a, ParsedIngredient b) {
    // Exact name match
    if (a.name.toLowerCase() == b.name.toLowerCase()) {
      return true;
    }

    // Original line match
    if (a.originalLine.toLowerCase() == b.originalLine.toLowerCase()) {
      return true;
    }

    // Word-set matching to prevent false positives (e.g. "salt" vs "basalt")
    final aLower = a.name.toLowerCase();
    final bLower = b.name.toLowerCase();
    final aWords = aLower.split(RegExp(r'\s+')).toSet();
    final bWords = bLower.split(RegExp(r'\s+')).toSet();
    final shorter = aWords.length <= bWords.length ? aWords : bWords;
    final longer = aWords.length <= bWords.length ? bWords : aWords;
    if (shorter.isNotEmpty && longer.containsAll(shorter)) {
      return true;
    }

    return false;
  }

  /// Patch weak fields in a recipe using another recipe's stronger fields.
  ParsedRecipe patchWeakFields(
    ParsedRecipe base,
    ParsedRecipe patch, {
    double threshold = 0.5,
  }) {
    return ParsedRecipe(
      title: base.title.confidenceScore < threshold && patch.title.hasValue
          ? patch.title
          : base.title,
      portions:
          base.portions.confidenceScore < threshold && patch.portions.hasValue
          ? patch.portions
          : base.portions,
      ingredients:
          base.ingredients.confidenceScore < threshold &&
              patch.ingredients.hasValue
          ? patch.ingredients
          : base.ingredients,
      instructions:
          base.instructions.confidenceScore < threshold &&
              patch.instructions.hasValue
          ? patch.instructions
          : base.instructions,
      totalTime:
          base.totalTime.confidenceScore < threshold && patch.totalTime.hasValue
          ? patch.totalTime
          : base.totalTime,
      metadata: base.metadata,
      imageUrl: base.imageUrl ?? patch.imageUrl,
      description: base.description ?? patch.description,
    );
  }
}
