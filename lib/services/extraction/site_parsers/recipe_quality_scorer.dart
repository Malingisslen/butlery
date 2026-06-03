/// Recipe quality scoring system for validation and success rate measurement
/// Calculates completeness scores based on field presence and quality.
/// Used to determine if an extraction meets success criteria (>90% or >95%).
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Quality score for an extracted recipe
class RecipeQualityScore {
  /// Recipe has a valid title (not empty, not default)
  final bool hasTitle;

  /// Recipe has ingredients (3+ items minimum for good quality)
  final bool hasIngredients;

  /// Recipe has instructions (2+ steps minimum for good quality)
  final bool hasInstructions;

  /// Recipe has portions/servings information
  final bool hasPortions;

  /// Recipe has time information
  final bool hasTime;

  /// Recipe has image(s)
  final bool hasImage;

  /// Number of ingredients found
  final int ingredientCount;

  /// Number of instruction steps found
  final int instructionCount;

  RecipeQualityScore({
    required this.hasTitle,
    required this.hasIngredients,
    required this.hasInstructions,
    required this.hasPortions,
    required this.hasTime,
    required this.hasImage,
    required this.ingredientCount,
    required this.instructionCount,
  });

  /// Completeness score (0.0 to 1.0)
  /// **Weights:**
  /// - Title: 20% (required)
  /// - Ingredients: 30% (required)
  /// - Instructions: 30% (required)
  /// - Portions: 10% (nice-to-have)
  /// - Time: 5% (nice-to-have)
  /// - Image: 5% (nice-to-have)
  double get completeness {
    double score = 0.0;

    if (hasTitle) score += 0.20;
    if (hasIngredients) score += 0.30;
    if (hasInstructions) score += 0.30;
    if (hasPortions) score += 0.10;
    if (hasTime) score += 0.05;
    if (hasImage) score += 0.05;

    return score;
  }

  /// Meets high quality threshold (>95% completeness)
  /// Used for "95% success rate" target (ICA.se, Arla.se)
  bool get meetsHighQuality => completeness >= 0.95;

  /// Meets acceptable quality threshold (>90% completeness)
  /// Used for "90% success rate" target (Köket.se)
  bool get meetsAcceptableQuality => completeness >= 0.90;

  /// Meets minimum quality threshold (>80% completeness)
  /// Minimum bar for considering extraction successful.
  /// Below this, recipe is too incomplete to be useful.
  bool get meetsMinimumQuality => completeness >= 0.80;

  /// Human-readable quality description
  String get qualityLevel {
    if (completeness >= 0.95) return 'Excellent';
    if (completeness >= 0.90) return 'Good';
    if (completeness >= 0.80) return 'Acceptable';
    if (completeness >= 0.50) return 'Poor';
    return 'Very Poor';
  }

  @override
  String toString() {
    return 'RecipeQualityScore('
        'completeness: ${(completeness * 100).toStringAsFixed(1)}%, '
        'quality: $qualityLevel, '
        'title: $hasTitle, '
        'ingredients: $hasIngredients ($ingredientCount), '
        'instructions: $hasInstructions ($instructionCount), '
        'portions: $hasPortions, '
        'time: $hasTime, '
        'image: $hasImage)';
  }
}

/// Static utility for scoring recipe quality
class RecipeQualityScorer {
  /// Score a recipe based on field completeness
  /// **Input:** Recipe data as `Map<String, dynamic>` (schema.org format)
  /// **Returns:** Quality score with completeness percentage
  /// **Example:**
  /// ```dart
  /// final recipe = {
  ///   'name': 'Köttbullar',
  ///   'recipeIngredient': ['500 g köttfärs', '1 ägg', '2 dl ströbröd'],
  ///   'recipeInstructions': ['Blanda allt', 'Stek bullarna'],
  ///   'recipeYield': '4 portioner',
  ///   'totalTime': 'PT40M',
  ///   'image': 'https://example.com/kottbullar.jpg',
  /// };
  /// final score = RecipeQualityScorer.score(recipe);
  /// print(score.completeness); // 1.0 (100%)
  /// print(score.meetsHighQuality); // true
  /// ```
  static RecipeQualityScore score(Map<String, dynamic> recipe) {
    // Check title
    final title = (recipe['name']?.toString().trim()).orEmpty();
    final hasTitle = title.isNotEmpty &&
        title != 'Importerat recept' &&
        title != 'Imported Recipe' &&
        title.length >= 3;

    // Check ingredients
    final ingredients = _extractList(recipe['recipeIngredient']);
    final hasIngredients = ingredients.length >= 3;
    final ingredientCount = ingredients.length;

    // Check instructions
    final instructions = _extractInstructions(recipe['recipeInstructions']);
    final hasInstructions = instructions.length >= 2;
    final instructionCount = instructions.length;

    // Check portions
    final portions = recipe['recipeYield'];
    final hasPortions = portions != null &&
        portions.toString().trim().isNotEmpty &&
        _containsNumber(portions.toString());

    // Check time
    final totalTime = recipe['totalTime'];
    final prepTime = recipe['prepTime'];
    final cookTime = recipe['cookTime'];
    final hasTime = totalTime != null || prepTime != null || cookTime != null;

    // Check image
    final image = recipe['image'];
    final hasImage = image != null &&
        (image is String && image.trim().isNotEmpty ||
            image is List && image.isNotEmpty ||
            image is Map && image['url'] != null);

    return RecipeQualityScore(
      hasTitle: hasTitle,
      hasIngredients: hasIngredients,
      hasInstructions: hasInstructions,
      hasPortions: hasPortions,
      hasTime: hasTime,
      hasImage: hasImage,
      ingredientCount: ingredientCount,
      instructionCount: instructionCount,
    );
  }

  /// Extract list of strings from various formats
  static List<String> _extractList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }

    return [];
  }

  /// Extract instructions from various formats
  static List<String> _extractInstructions(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      final steps = <String>[];

      for (final instruction in value) {
        if (instruction is String) {
          steps.add(instruction.trim());
        } else if (instruction is Map) {
          // HowToStep format
          final text = instruction['text'];
          if (text != null && text.toString().trim().isNotEmpty) {
            steps.add(text.toString().trim());
          }
        }
      }

      return steps.where((s) => s.isNotEmpty).toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return [value.trim()];
    }

    return [];
  }

  /// Check if string contains a number
  static bool _containsNumber(String text) {
    return RegExp(r'\d+').hasMatch(text);
  }
}
