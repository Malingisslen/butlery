/// Extension on Recipe for computing completeness score and identifying missing fields.
import 'package:butlery/models/recipe_unified.dart';

/// Fields that contribute to recipe completeness.
enum RecipeField { title, ingredients, instructions, portions, time, image }

/// Threshold below which a recipe is considered incomplete.
const double incompleteThreshold = 0.7;

extension RecipeCompleteness on Recipe {
  /// Completeness score from 0.0 to 1.0 using the same weights as RecipeQualityScorer.
  double get completenessScore {
    var score = 0.0;
    if (title.trim().length >= 3) score += 0.20;
    if (ingredients.length >= 3) score += 0.30;
    if (instructions.length >= 2) score += 0.30;
    if (portions != null && portions! > 0) score += 0.10;
    if (timeMinutes != null && timeMinutes! > 0) score += 0.05;
    if (imageUrls.isNotEmpty) score += 0.05;
    return score;
  }

  /// List of missing fields as typed enum values.
  List<RecipeField> get missingFields {
    final missing = <RecipeField>[];
    if (title.trim().length < 3) missing.add(RecipeField.title);
    if (ingredients.length < 3) missing.add(RecipeField.ingredients);
    if (instructions.length < 2) missing.add(RecipeField.instructions);
    if (portions == null || portions! <= 0) missing.add(RecipeField.portions);
    if (timeMinutes == null || timeMinutes! <= 0) missing.add(RecipeField.time);
    if (imageUrls.isEmpty) missing.add(RecipeField.image);
    return missing;
  }
}
