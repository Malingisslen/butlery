import 'dart:async';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart';

/// Timeout duration for tag generation operations.
const Duration _tagGenerationTimeout = Duration(seconds: 30);

/// Main entry point for the automatic tagging system.
///
/// Orchestrates ingredient lookup and tag generation.
/// Supports user overrides for unknown ingredients.
class TaggingService extends BaseService {
  final IngredientLookupService _lookupService;
  final TagGenerator _tagGenerator;
  final UserIngredientRepository? _userIngredientRepository;

  @override
  String get serviceName => 'TaggingService';

  TaggingService({
    required IngredientLookupService lookupService,
    TagGenerator? tagGenerator,
    UserIngredientRepository? userIngredientRepository,
  })  : _lookupService = lookupService,
        _tagGenerator = tagGenerator ?? TagGenerator(),
        _userIngredientRepository = userIngredientRepository;

  /// Generates tags for a recipe.
  ///
  /// Returns [TagResult] with:
  /// - Generated tags from all 4 phases
  /// - Allergen status (tri-valued)
  /// - Dietary status
  /// - Coverage percentage
  /// - List of unknown ingredients
  ///
  /// Throws [TimeoutException] if generation takes longer than 30 seconds.
  Future<TagResult?> generateTags(Recipe recipe) async {
    return await executeServiceOperation(
      () async {
        AppLogger.info('🏷️ Generating tags for: ${recipe.core.title}');

        // Get normalized ingredients (or use raw if not available)
        final ingredients =
            recipe.core.ingredientsNormalized ?? recipe.core.ingredients;

        if (ingredients.isEmpty) {
          AppLogger.warning('No ingredients found for recipe');
          return TagResult.empty();
        }

        // Wrap in timeout to prevent hanging on complex recipes
        return await _generateTagsWithTimeout(recipe, ingredients);
      },
      operationName: 'Generate tags',
      requiresAuth: false, // Tagging doesn't require auth
    );
  }

  /// Internal method with timeout wrapper.
  Future<TagResult> _generateTagsWithTimeout(
    Recipe recipe,
    List<String> ingredients,
  ) async {
    return await Future.any([
      _performTagGeneration(recipe, ingredients),
      Future.delayed(_tagGenerationTimeout, () {
        throw TimeoutException(
          'Tag generation timed out after ${_tagGenerationTimeout.inSeconds} seconds',
          _tagGenerationTimeout,
        );
      }),
    ]);
  }

  /// Performs the actual tag generation.
  Future<TagResult> _performTagGeneration(
    Recipe recipe,
    List<String> ingredients,
  ) async {
    // Lookup ingredients in database
    final lookupResult = await _lookupService.lookupFromRaw(ingredients);

    AppLogger.debug(
      'Ingredient lookup: ${lookupResult.matched.length} matched, '
      '${lookupResult.unmatched.length} unmatched, '
      '${(lookupResult.coverage * 100).toStringAsFixed(0)}% coverage',
    );

    // Generate tags using the 4-phase generator
    final tagResult = _tagGenerator.generate(
      ingredients: lookupResult,
      recipe: recipe,
    );

    AppLogger.info(
      '✅ Generated ${tagResult.tags.length} tags '
      '(coverage: ${(tagResult.coverage * 100).toStringAsFixed(0)}%)',
    );

    return tagResult;
  }

  /// Generates a quick preview with only Phase 1 tags.
  ///
  /// Useful for real-time feedback while editing.
  Future<TagResult?> generatePreview(Recipe recipe) async {
    return await executeServiceOperation(
      () async {
        final ingredients =
            recipe.core.ingredientsNormalized ?? recipe.core.ingredients;

        if (ingredients.isEmpty) {
          return TagResult.empty();
        }

        final lookupResult = await _lookupService.lookupFromRaw(ingredients);

        return _tagGenerator.generatePhase1Only(
          ingredients: lookupResult,
          recipe: recipe,
        );
      },
      operationName: 'Generate preview',
      requiresAuth: false,
    );
  }

  /// Looks up ingredients without generating tags.
  ///
  /// Useful for showing unknown ingredients to the user.
  Future<IngredientLookupResult?> lookupIngredients(
    List<String> ingredients,
  ) async {
    return await executeServiceOperation(
      () => _lookupService.lookupFromRaw(ingredients),
      operationName: 'Lookup ingredients',
      requiresAuth: false,
    );
  }

  /// Saves a user-defined ingredient for unknown ingredient handling.
  ///
  /// Requires [userId] and [_userIngredientRepository] to be configured.
  Future<void> saveUserIngredient({
    required String userId,
    required String ingredientName,
    required Set<String> properties,
    String? group,
  }) async {
    if (_userIngredientRepository == null) {
      AppLogger.warning('User ingredient repository not configured');
      return;
    }

    await executeServiceOperation(
      () async {
        final ingredient = IngredientData(
          id: _generateIngredientId(ingredientName),
          swedish: ingredientName,
          english: ingredientName,
          group: group ?? 'unknown',
          properties: properties,
        );

        await _userIngredientRepository.create(userId, ingredient);

        AppLogger.info('💾 Saved user ingredient: $ingredientName');
      },
      operationName: 'Save user ingredient',
      requiresAuth: true,
    );
  }

  /// Gets unknown ingredients from a recipe.
  ///
  /// Returns ingredients that couldn't be matched in the database.
  Future<List<String>> getUnknownIngredients(Recipe recipe) async {
    final result = await lookupIngredients(
      recipe.core.ingredientsNormalized ?? recipe.core.ingredients,
    );

    return result?.unmatched.toList() ?? [];
  }

  /// Checks if a recipe needs retagging.
  ///
  /// Returns true if:
  /// - Recipe has no tags
  /// - Tag generator version has changed
  /// - Ingredients have changed since last tagging
  bool needsRetagging(Recipe recipe) {
    final existingResult = recipe.core.tagResult;

    // No existing tags
    if (existingResult == null) return true;

    // Version mismatch
    if (existingResult.generatorVersion != kTagGeneratorVersion) {
      return true;
    }

    // Could add ingredient hash comparison here for change detection

    return false;
  }

  /// Re-tags all recipes for a user.
  ///
  /// Use after ingredient database updates.
  /// Processes in batches of 50 for scalability.
  ///
  /// [onProgress] is called with (current, total) counts after each batch.
  Future<int> retagUserRecipes({
    required String userId,
    required Future<List<Recipe>> Function() getRecipes,
    required Future<void> Function(Recipe) saveRecipe,
    void Function(int current, int total)? onProgress,
  }) async {
    final result = await executeServiceOperation(
      () async {
        final recipes = await getRecipes();
        final recipesToRetag = recipes.where(needsRetagging).toList();
        final total = recipesToRetag.length;

        if (total == 0) {
          AppLogger.info('No recipes need retagging for user $userId');
          onProgress?.call(0, 0);
          return 0;
        }

        var retaggedCount = 0;
        const batchSize = 50;

        // Process in batches for scalability
        for (var i = 0; i < recipesToRetag.length; i += batchSize) {
          final batchEnd = (i + batchSize).clamp(0, recipesToRetag.length);
          final batch = recipesToRetag.sublist(i, batchEnd);

          // Process batch in parallel
          final results = await Future.wait(
            batch.map((recipe) async {
              final tagResult = await generateTags(recipe);
              if (tagResult != null) {
                final updatedRecipe = Recipe(
                  core: recipe.core.copyWith(tagResult: tagResult),
                  type: recipe.type,
                  socialData: recipe.socialData,
                  realtimeData: recipe.realtimeData,
                  offlineData: recipe.offlineData,
                );
                await saveRecipe(updatedRecipe);
                return true;
              }
              return false;
            }),
          );

          retaggedCount += results.where((success) => success).length;
          onProgress?.call(batchEnd, total);
        }

        AppLogger.info('🔄 Retagged $retaggedCount recipes for user $userId');
        return retaggedCount;
      },
      operationName: 'Retag user recipes',
      requiresAuth: true,
    );

    return result ?? 0;
  }

  String _generateIngredientId(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[åä]'), 'a')
        .replaceAll('ö', 'o')
        .replaceAll(RegExp(r'[^a-z0-9]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  @override
  Future<void> onInitialize() async {
    await _lookupService.initialize();
    AppLogger.info('TaggingService ready with $kTagGeneratorVersion');
  }

  @override
  Future<void> onDispose() async {
    await _lookupService.dispose();
  }
}
