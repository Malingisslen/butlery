import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';

/// A parsed recipe with per-field confidence tracking.
///
/// This model enables smart merging of results from multiple parsing tiers
/// and targeted LLM patching of only low-confidence fields.
class ParsedRecipe {
  /// Recipe title.
  final FieldResult<String> title;

  /// Number of portions/servings.
  final FieldResult<int> portions;

  /// Parsed ingredients.
  final FieldResult<List<ParsedIngredient>> ingredients;

  /// Cooking instructions.
  final FieldResult<List<String>> instructions;

  /// Total cooking time.
  final FieldResult<Duration> totalTime;

  /// Parsing metadata.
  final ParseMetadata metadata;

  /// Recipe image URL, if found.
  final String? imageUrl;

  /// Recipe description, if found.
  final String? description;

  const ParsedRecipe({
    required this.title,
    required this.portions,
    required this.ingredients,
    required this.instructions,
    required this.totalTime,
    required this.metadata,
    this.imageUrl,
    this.description,
  });

  /// Creates an empty recipe with failed fields.
  factory ParsedRecipe.empty({required ParseMetadata metadata}) => ParsedRecipe(
        title: FieldResult.failed('No title'),
        portions: FieldResult.failed('No portions'),
        ingredients: FieldResult.failed('No ingredients'),
        instructions: FieldResult.failed('No instructions'),
        totalTime: FieldResult.failed('No time'),
        metadata: metadata,
      );

  /// Overall quality score (0.0-1.0) based on field confidence.
  ///
  /// Weighted:
  /// - Title: 15%
  /// - Portions: 10%
  /// - Ingredients: 40%
  /// - Instructions: 30%
  /// - Time: 5%
  double get overallQuality {
    const weights = {
      'title': 0.15,
      'portions': 0.10,
      'ingredients': 0.40,
      'instructions': 0.30,
      'totalTime': 0.05,
    };

    return (title.confidenceScore * weights['title']!) +
        (portions.confidenceScore * weights['portions']!) +
        (ingredients.confidenceScore * weights['ingredients']!) +
        (instructions.confidenceScore * weights['instructions']!) +
        (totalTime.confidenceScore * weights['totalTime']!);
  }

  /// Whether this recipe is complete (all essential fields have values).
  bool get isComplete =>
      title.hasValue && ingredients.hasValue && instructions.hasValue;

  /// Whether this recipe needs user review.
  bool get needsReview =>
      title.needsReview || ingredients.needsReview || instructions.needsReview;

  /// List of fields that have low confidence and may need LLM patching.
  List<String> get fieldsNeedingImprovement {
    final fields = <String>[];
    if (title.confidenceScore < 0.5) fields.add('title');
    if (portions.confidenceScore < 0.5) fields.add('portions');
    if (ingredients.confidenceScore < 0.5) fields.add('ingredients');
    if (instructions.confidenceScore < 0.5) fields.add('instructions');
    if (totalTime.confidenceScore < 0.5) fields.add('totalTime');
    return fields;
  }

  /// Count of structured ingredients (with quantity or unit).
  int get structuredIngredientCount {
    if (!ingredients.hasValue) return 0;
    return ingredients.value!.where((i) => i.isStructured).length;
  }

  /// Ratio of structured to total ingredients.
  double get ingredientStructureRatio {
    if (!ingredients.hasValue || ingredients.value!.isEmpty) return 0.0;
    return structuredIngredientCount / ingredients.value!.length;
  }

  /// Creates a copy with updated fields.
  ///
  /// Pass null to keep the existing value.
  ParsedRecipe copyWith({
    FieldResult<String>? title,
    FieldResult<int>? portions,
    FieldResult<List<ParsedIngredient>>? ingredients,
    FieldResult<List<String>>? instructions,
    FieldResult<Duration>? totalTime,
    ParseMetadata? metadata,
    String? imageUrl,
    String? description,
  }) =>
      ParsedRecipe(
        title: title ?? this.title,
        portions: portions ?? this.portions,
        ingredients: ingredients ?? this.ingredients,
        instructions: instructions ?? this.instructions,
        totalTime: totalTime ?? this.totalTime,
        metadata: metadata ?? this.metadata,
        imageUrl: imageUrl ?? this.imageUrl,
        description: description ?? this.description,
      );

  /// Converts to a simple Map for storage or conversion to Recipe model.
  Map<String, dynamic> toRecipeData() => {
        if (title.hasValue) 'title': title.value,
        if (portions.hasValue) 'portions': portions.value,
        if (ingredients.hasValue)
          'ingredients': ingredients.value!.map((i) => i.originalLine).toList(),
        if (instructions.hasValue) 'instructions': instructions.value,
        if (totalTime.hasValue) 'timeMinutes': totalTime.value!.inMinutes,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (description != null) 'description': description,
        'parseMetadata': metadata.toJson(),
      };

  /// Converts to JSON including confidence data.
  Map<String, dynamic> toJson() => {
        'title': title.toJson(),
        'portions': portions.toJson(),
        'ingredients': ingredients.toJson(
          (list) => list.map((i) => i.toJson()).toList(),
        ),
        'instructions': instructions.toJson(),
        'totalTime': totalTime.toJson(
          (duration) => duration.inMinutes,
        ),
        'metadata': metadata.toJson(),
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (description != null) 'description': description,
      };

  /// Creates from JSON.
  factory ParsedRecipe.fromJson(Map<String, dynamic> json) => ParsedRecipe(
        title: FieldResult.fromJson(
          json['title'] as Map<String, dynamic>,
          (v) => v as String,
        ),
        portions: FieldResult.fromJson(
          json['portions'] as Map<String, dynamic>,
          (v) => v as int,
        ),
        ingredients: FieldResult.fromJson(
          json['ingredients'] as Map<String, dynamic>,
          (v) => (v as List)
              .map((i) => ParsedIngredient.fromJson(i as Map<String, dynamic>))
              .toList(),
        ),
        instructions: FieldResult.fromJson(
          json['instructions'] as Map<String, dynamic>,
          (v) => (v as List).cast<String>(),
        ),
        totalTime: FieldResult.fromJson(
          json['totalTime'] as Map<String, dynamic>,
          (v) => Duration(minutes: v as int),
        ),
        metadata: ParseMetadata.fromJson(
          json['metadata'] as Map<String, dynamic>,
        ),
        imageUrl: json['imageUrl'] as String?,
        description: json['description'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedRecipe &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          ingredients == other.ingredients;

  @override
  int get hashCode => Object.hash(title, ingredients);

  @override
  String toString() => 'ParsedRecipe(title: ${title.value ?? "none"}, '
      'quality: ${(overallQuality * 100).toStringAsFixed(0)}%, '
      'complete: $isComplete)';
}
