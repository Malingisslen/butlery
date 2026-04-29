/// Recipe field-level diff utilities for analytics (BUT-569).
///
/// Computes which top-level recipe fields changed between two [Recipe]
/// snapshots. Used to instrument the `post_import_edit` event so we can see
/// which fields users most often correct after an import — a signal that
/// drives parser-quality investments.
library;

import 'package:flutter/foundation.dart' show listEquals;

import 'package:butlery/models/recipe_unified.dart';

/// Top-level field names emitted by [diffRecipeFields]. Snake_case to match
/// other analytics parameters.
class RecipeDiffField {
  static const String title = 'title';
  static const String description = 'description';
  static const String mealType = 'meal_type';
  static const String portions = 'portions';
  static const String timeMinutes = 'time_minutes';
  static const String prepTimeMinutes = 'prep_time_minutes';
  static const String cookTimeMinutes = 'cook_time_minutes';
  static const String ingredients = 'ingredients';
  static const String instructions = 'instructions';
  static const String imageUrls = 'image_urls';
  static const String sourceUrl = 'source_url';
  static const String cuisine = 'cuisine';
  static const String difficulty = 'difficulty';
}

/// Returns the snake_case field names of top-level recipe fields whose values
/// differ between [before] and [after]. Order is stable across calls so the
/// resulting list is safe to log directly without de-duping.
///
/// Comparison rules:
/// - Strings, ints, doubles: standard `==`.
/// - Lists (ingredients/instructions/imageUrls): order-sensitive deep equality
///   — reordering counts as a change because users typically edit one step at
///   a time, and that signal is exactly what we want to capture.
/// - Nulls: a null on either side counts as different from a non-null.
List<String> diffRecipeFields(Recipe before, Recipe after) {
  final changed = <String>[];

  if (before.title != after.title) changed.add(RecipeDiffField.title);
  if (before.description != after.description) {
    changed.add(RecipeDiffField.description);
  }
  if (before.mealType != after.mealType) changed.add(RecipeDiffField.mealType);
  if (before.portions != after.portions) changed.add(RecipeDiffField.portions);
  if (before.timeMinutes != after.timeMinutes) {
    changed.add(RecipeDiffField.timeMinutes);
  }
  if (before.prepTimeMinutes != after.prepTimeMinutes) {
    changed.add(RecipeDiffField.prepTimeMinutes);
  }
  if (before.cookTimeMinutes != after.cookTimeMinutes) {
    changed.add(RecipeDiffField.cookTimeMinutes);
  }
  if (!listEquals(before.ingredients, after.ingredients)) {
    changed.add(RecipeDiffField.ingredients);
  }
  if (!listEquals(before.instructions, after.instructions)) {
    changed.add(RecipeDiffField.instructions);
  }
  if (!listEquals(before.imageUrls, after.imageUrls)) {
    changed.add(RecipeDiffField.imageUrls);
  }
  if (before.sourceUrl != after.sourceUrl) {
    changed.add(RecipeDiffField.sourceUrl);
  }
  if (before.cuisine != after.cuisine) changed.add(RecipeDiffField.cuisine);
  if (before.difficulty != after.difficulty) {
    changed.add(RecipeDiffField.difficulty);
  }

  return changed;
}
