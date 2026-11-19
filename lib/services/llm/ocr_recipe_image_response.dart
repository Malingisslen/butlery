import 'dart:math' as math;

import 'package:butlery/services/llm/llm_models.dart';

/// Response from ocrRecipeImage Cloud Function.
class OcrRecipeImageResponse {
  /// The server returns at most this many recipes per photo; a longer list
  /// from a misbehaving server is cut here too.
  static const maxRecipes = 6;

  final bool success;
  final ExtractedRecipe? recipe;

  final List<ExtractedRecipe>? _recipes;

  /// Recipes the server read but could not use. An older server sends none.
  final int droppedRecipeCount;
  final String? rawText;
  final String? error;
  final double estimatedCost;
  final String? promptVersion;

  /// BUT-785: pinned Vertex model id (see StructureRecipeResponse.modelId).
  final String? modelId;

  const OcrRecipeImageResponse({
    required this.success,
    this.recipe,
    List<ExtractedRecipe>? recipes,
    this.rawText,
    this.error,
    required this.estimatedCost,
    this.promptVersion,
    this.modelId,
    this.droppedRecipeCount = 0,
  }) : _recipes = recipes;

  factory OcrRecipeImageResponse.fromJson(Map<String, dynamic> json) {
    final single = json['recipe'] != null
        ? ExtractedRecipe.fromJson(json['recipe'] as Map<String, dynamic>)
        : null;
    final raw = json['recipes'];
    return OcrRecipeImageResponse(
      success: json['success'] as bool? ?? false,
      recipe: single,
      recipes: raw is List
          ? [
              for (final e in raw)
                if (e is Map<String, dynamic>) ExtractedRecipe.fromJson(e),
            ]
          : null,
      rawText: json['rawText'] as String?,
      error: json['error'] as String?,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0.0,
      promptVersion: json['promptVersion'] as String?,
      modelId: json['modelId'] as String?,
      droppedRecipeCount: math.max(
        0,
        (json['droppedRecipeCount'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  /// Every recipe on the photo, in reading order, at most [maxRecipes].
  /// An older server sends none, and then this is `[recipe]`.
  List<ExtractedRecipe> get recipes {
    final all = _recipes;
    if (all != null && all.isNotEmpty) return all.take(maxRecipes).toList();
    final single = recipe;
    return single == null ? const [] : [single];
  }
}
