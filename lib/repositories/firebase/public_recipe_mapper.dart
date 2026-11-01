import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';

/// A recipe read from `users/{ownerId}/public_recipes`, the copy the server
/// writes for a recipe its owner shows on their profile.
///
/// [ownerId] is the uid from the document's path, never the `ownerId` field:
/// only the path is what the rules checked when the copy was read.
Recipe recipeFromPublicCopy(
  String ownerId,
  String id,
  Map<String, dynamic> data,
) {
  List<String> strings(String key) => data[key] is List
      ? (data[key] as List).whereType<String>().toList()
      : const [];
  int? count(String key) =>
      data[key] is num ? (data[key] as num).toInt() : null;

  return Recipe(
    core: RecipeCore(
      id: id,
      title: SerializationUtils.safeString(data, 'title'),
      description: SerializationUtils.safeString(data, 'description'),
      portions: count('portions'),
      timeMinutes: count('timeMinutes'),
      prepTimeMinutes: count('prepTimeMinutes'),
      cookTimeMinutes: count('cookTimeMinutes'),
      ingredients: strings('ingredients'),
      structuredIngredients: RecipeIngredient.listFromJson(
        data['structuredIngredients'],
      ),
      instructions: strings('instructions'),
      mealType: SerializationUtils.safeString(data, 'mealType'),
      cuisine: SerializationUtils.safeNullableString(data, 'cuisine'),
      difficulty: SerializationUtils.safeNullableString(data, 'difficulty'),
      imageUrls: strings('imageUrls'),
      thumbnailUrl: SerializationUtils.safeNullableString(data, 'thumbnailUrl'),
      sourceUrl: SerializationUtils.safeNullableString(data, 'sourceUrl'),
      sourceAuthor: SerializationUtils.safeNullableString(data, 'sourceAuthor'),
      createdAt: SerializationUtils.safeDateTime(data, 'createdAt'),
      updatedAt: SerializationUtils.safeDateTime(data, 'updatedAt'),
      createdBy: ownerId,
      showOnProfile: false,
    ),
    type: RecipeType.personal,
  );
}
