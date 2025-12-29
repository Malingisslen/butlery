/// Test utilities for tagging system integration and performance tests.
///
/// Provides helpers for creating batch recipes, ingredient lookups,
/// and measuring performance of tag generation.
library;

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:uuid/uuid.dart';

/// Helper class for tagging integration and performance tests.
class TaggingTestHelper {
  static const _uuid = Uuid();

  /// Sample ingredient sets for varied test recipes.
  static const _ingredientSets = [
    // Swedish dinner
    ['köttfärs', 'potatis', 'lök', 'grädde', 'salt'],
    // Italian pasta
    ['pasta', 'bacon', 'ägg', 'parmesan', 'svartpeppar'],
    // Fish dish
    ['lax', 'citron', 'dill', 'smör', 'potatis'],
    // Vegetarian
    ['tofu', 'broccoli', 'morötter', 'sojasås', 'ris'],
    // Chicken
    ['kyckling', 'paprika', 'lök', 'vitlök', 'olivolja'],
    // Soup
    ['morot', 'selleri', 'potatis', 'buljong', 'grädde'],
    // Salad
    ['sallad', 'tomat', 'gurka', 'fetaost', 'oliver'],
    // Dessert
    ['ägg', 'socker', 'mjöl', 'smör', 'vanilj'],
    // Seafood
    ['räkor', 'vitlök', 'chili', 'lime', 'koriander'],
    // Pork
    ['fläskfilé', 'äpple', 'grädde', 'senap', 'timjan'],
  ];

  /// Creates [count] varied recipes for batch testing.
  ///
  /// Each recipe has different ingredients, times, and portions
  /// to test diverse tagging scenarios.
  static List<Recipe> createBatchRecipes(int count) {
    final recipes = <Recipe>[];

    for (var i = 0; i < count; i++) {
      final ingredientSet = _ingredientSets[i % _ingredientSets.length];
      final timeMinutes = 15 + (i % 6) * 15; // 15, 30, 45, 60, 75, 90
      final portions = 2 + (i % 4); // 2, 3, 4, 5

      recipes.add(Recipe(
        core: RecipeCore(
          id: _uuid.v4(),
          title: 'Test Recipe ${i + 1}',
          description: 'Batch test recipe number ${i + 1}',
          ingredients: ingredientSet,
          instructions: ['Step 1', 'Step 2', 'Step 3'],
          mealType: 'Middag',
          timeMinutes: timeMinutes,
          portions: portions,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: 'test_user',
        ),
        type: RecipeType.personal,
      ));
    }

    return recipes;
  }

  /// Creates a recipe with exactly [ingredientCount] ingredients.
  ///
  /// Used for performance testing with large ingredient lists.
  static Recipe createLargeRecipe(int ingredientCount) {
    final ingredients = List.generate(
      ingredientCount,
      (i) => 'ingredient_${i + 1}',
    );

    return Recipe(
      core: RecipeCore(
        id: _uuid.v4(),
        title: 'Large Recipe with $ingredientCount ingredients',
        description: 'Performance test recipe',
        ingredients: ingredients,
        instructions: ['Step 1', 'Step 2'],
        mealType: 'Middag',
        timeMinutes: 60,
        portions: 4,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'test_user',
      ),
      type: RecipeType.personal,
    );
  }

  /// Creates an [IngredientLookupResult] with specified coverage.
  ///
  /// [matchedCount] ingredients will be matched, and the rest
  /// ([totalCount] - [matchedCount]) will be unmatched.
  static IngredientLookupResult createLookupWithCoverage({
    required int matchedCount,
    required int totalCount,
    Set<String>? properties,
  }) {
    assert(matchedCount <= totalCount);

    final matched = List.generate(
      matchedCount,
      (i) => IngredientData(
        id: 'ingredient-$i',
        swedish: 'Ingrediens $i',
        english: 'Ingredient $i',
        group: 'test/group',
        properties: properties ?? {},
      ),
    );

    final unmatched = List.generate(
      totalCount - matchedCount,
      (i) => 'unknown_ingredient_$i',
    );

    return IngredientLookupResult.fromLists(
      matched: matched,
      unmatched: unmatched,
    );
  }

  /// Creates a lookup result with specific allergen properties.
  static IngredientLookupResult createLookupWithAllergens({
    required Set<String> allergenProperties,
    int matchedCount = 5,
  }) {
    final matched = <IngredientData>[];

    // First ingredient has the allergens
    matched.add(IngredientData(
      id: 'allergen-ingredient',
      swedish: 'Allergen Ingrediens',
      english: 'Allergen Ingredient',
      group: 'test/allergen',
      properties: allergenProperties,
    ));

    // Rest are neutral
    for (var i = 1; i < matchedCount; i++) {
      matched.add(IngredientData(
        id: 'ingredient-$i',
        swedish: 'Ingrediens $i',
        english: 'Ingredient $i',
        group: 'test/neutral',
        properties: const {},
      ));
    }

    return IngredientLookupResult.fromLists(
      matched: matched,
      unmatched: [],
    );
  }

  /// Creates a lookup with dietary-specific ingredients.
  static IngredientLookupResult createVegetarianLookup() {
    return IngredientLookupResult.fromLists(
      matched: [
        const IngredientData(
          id: 'tofu',
          swedish: 'Tofu',
          english: 'Tofu',
          group: 'protein/plant',
          properties: {},
        ),
        const IngredientData(
          id: 'broccoli',
          swedish: 'Broccoli',
          english: 'Broccoli',
          group: 'vegetable/green',
          properties: {},
        ),
        const IngredientData(
          id: 'rice',
          swedish: 'Ris',
          english: 'Rice',
          group: 'grain',
          properties: {},
        ),
      ],
      unmatched: [],
    );
  }

  /// Creates a lookup with meat ingredients.
  static IngredientLookupResult createMeatLookup() {
    return IngredientLookupResult.fromLists(
      matched: [
        const IngredientData(
          id: 'chicken',
          swedish: 'Kyckling',
          english: 'Chicken',
          group: 'protein/meat/poultry',
          properties: {'meat', 'poultry'},
        ),
        const IngredientData(
          id: 'potato',
          swedish: 'Potatis',
          english: 'Potato',
          group: 'vegetable/root',
          properties: {},
        ),
      ],
      unmatched: [],
    );
  }

  /// Creates a lookup with gluten-containing ingredients.
  static IngredientLookupResult createGlutenLookup() {
    return IngredientLookupResult.fromLists(
      matched: [
        const IngredientData(
          id: 'pasta',
          swedish: 'Pasta',
          english: 'Pasta',
          group: 'grain/pasta-bread',
          properties: {'contains-gluten', 'pasta-base'},
        ),
        const IngredientData(
          id: 'tomato',
          swedish: 'Tomat',
          english: 'Tomato',
          group: 'vegetable/fruit',
          properties: {},
        ),
      ],
      unmatched: [],
    );
  }

  /// Measures execution time for tag generation.
  ///
  /// Returns the duration and generated [TagResult].
  static Future<TagGenerationResult> measureTagGeneration({
    required TagGenerator generator,
    required IngredientLookupResult lookup,
    required Recipe recipe,
  }) async {
    final stopwatch = Stopwatch()..start();

    final result = generator.generate(
      ingredients: lookup,
      recipe: recipe,
    );

    stopwatch.stop();

    return TagGenerationResult(
      duration: stopwatch.elapsed,
      result: result,
    );
  }

  /// Creates a [TagResult] for testing.
  static TagResult createTagResult({
    Set<String>? tags,
    Map<String, TriState>? allergenStatus,
    Map<String, TriState>? dietaryStatus,
    double coverage = 1.0,
    List<String>? unknownIngredients,
    String generatorVersion = '1.0.0',
  }) {
    return TagResult(
      tags: tags ?? {'test-tag'},
      allergenStatus: allergenStatus ?? {},
      dietaryStatus: dietaryStatus ?? {},
      coverage: coverage,
      unknownIngredients: unknownIngredients ?? [],
      generatedAt: DateTime.now(),
      generatorVersion: generatorVersion,
    );
  }

  /// Creates a [TagResult] that needs retagging (outdated version).
  static TagResult createOutdatedTagResult() {
    return TagResult(
      tags: {'old-tag'},
      allergenStatus: {},
      dietaryStatus: {},
      coverage: 1.0,
      unknownIngredients: [],
      generatedAt: DateTime.now().subtract(const Duration(days: 30)),
      generatorVersion: '0.9.0', // Old version
    );
  }
}

/// Result of measuring tag generation performance.
class TagGenerationResult {
  /// Time taken to generate tags.
  final Duration duration;

  /// The generated tag result.
  final TagResult result;

  const TagGenerationResult({
    required this.duration,
    required this.result,
  });

  /// Duration in milliseconds.
  int get milliseconds => duration.inMilliseconds;

  /// Whether generation was under the target time.
  bool isUnder(Duration target) => duration < target;
}
