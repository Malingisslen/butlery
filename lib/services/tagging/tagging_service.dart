import 'dart:async';

import 'package:butlery/core/base/base_service.dart' hide PermissionService;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/tagging/config/property_registry.dart';
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

  /// CRIT-3: Internal method with timeout that preserves partial results.
  ///
  /// Uses a two-phase timeout approach:
  /// 1. Lookup phase: async, can be interrupted by timeout
  /// 2. Generate phase: sync with internal timeout, returns partial results
  Future<TagResult> _generateTagsWithTimeout(
    Recipe recipe,
    List<String> ingredients,
  ) async {
    final stopwatch = Stopwatch()..start();

    // Phase 1: Lookup ingredients with timeout
    IngredientLookupResult lookupResult;
    try {
      lookupResult = await _lookupService
          .lookupFromRaw(
            ingredients,
            userId: _getCurrentUserId(),
          )
          .timeout(_tagGenerationTimeout);
    } on TimeoutException {
      // CRIT-3: If lookup times out, return empty result with error reason
      AppLogger.warning(
        '⏱️ Ingredient lookup timeout for recipe "${recipe.core.title}" '
            '(${ingredients.length} ingredients)',
        'TaggingService',
      );
      return TagResult.failed(reason: 'Lookup timeout');
    }

    AppLogger.debug(
      'Ingredient lookup: ${lookupResult.matched.length} matched, '
      '${lookupResult.unmatched.length} unmatched, '
      '${(lookupResult.coverage * 100).toStringAsFixed(0)}% coverage',
    );

    // CRIT-3: Calculate remaining time for generation phase
    final elapsed = stopwatch.elapsed;
    final remainingTime = _tagGenerationTimeout - elapsed;

    if (remainingTime <= Duration.zero) {
      // Time exhausted, return Phase 1 only for critical allergen safety
      AppLogger.warning(
        '⏱️ No time remaining for generation, returning Phase 1 only',
        'TaggingService',
      );
      return _tagGenerator.generatePhase1Only(
        ingredients: lookupResult,
        recipe: recipe,
      );
    }

    // Generate tags with remaining timeout for graceful degradation
    final tagResult = _tagGenerator.generate(
      ingredients: lookupResult,
      recipe: recipe,
      timeout: remainingTime,
    );

    if (tagResult.isPartial) {
      AppLogger.warning(
        '⏱️ Tag generation partial (timeout after ${elapsed.inMilliseconds}ms) '
            'for recipe "${recipe.core.title}"',
        'TaggingService',
      );
    } else {
      AppLogger.info(
        '✅ Generated ${tagResult.tags.length} tags '
        '(coverage: ${(tagResult.coverage * 100).toStringAsFixed(0)}%)',
      );
    }

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

        // M2: Pass userId for user-defined ingredient lookup
        final lookupResult = await _lookupService.lookupFromRaw(
          ingredients,
          userId: _getCurrentUserId(),
        );

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
      // M2: Pass userId for user-defined ingredient lookup
      () => _lookupService.lookupFromRaw(ingredients,
          userId: _getCurrentUserId()),
      operationName: 'Lookup ingredients',
      requiresAuth: false,
    );
  }

  /// M2: Gets the current user ID from PermissionService for user-defined ingredient lookup.
  String? _getCurrentUserId() {
    try {
      return ServiceLocator.get<PermissionService>().currentUser?.uid;
    } catch (e) {
      // ServiceLocator not available or PermissionService not registered
      return null;
    }
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

        // M9: Track failures for debugging
        final failedRecipes = <String>[];

        // Process in batches for scalability
        for (var i = 0; i < recipesToRetag.length; i += batchSize) {
          final batchEnd = (i + batchSize).clamp(0, recipesToRetag.length);
          final batch = recipesToRetag.sublist(i, batchEnd);

          // Process batch in parallel
          final results = await Future.wait(
            batch.map((recipe) async {
              try {
                final tagResult = await generateTags(recipe);
                // MED-9: Validate tagResult before saving to prevent corrupt data
                if (tagResult != null && _isValidTagResult(tagResult)) {
                  final updatedRecipe = Recipe(
                    core: recipe.core.copyWith(tagResult: tagResult),
                    type: recipe.type,
                    socialData: recipe.socialData,
                    realtimeData: recipe.realtimeData,
                    offlineData: recipe.offlineData,
                  );
                  await saveRecipe(updatedRecipe);
                  return true;
                } else if (tagResult != null && !_isValidTagResult(tagResult)) {
                  AppLogger.warning(
                    'MED-9: Invalid tagResult for recipe ${recipe.id}, skipping',
                    'TaggingService',
                  );
                }
                // M9: Track failed recipe
                failedRecipes.add(recipe.id);
                return false;
              } catch (e) {
                // M9: Log individual recipe failures
                AppLogger.warning(
                  'Failed to retag recipe ${recipe.id}: $e',
                  'TaggingService',
                );
                failedRecipes.add(recipe.id);
                return false;
              }
            }),
          );

          retaggedCount += results.where((success) => success).length;
          // H12: Report actual completed count, not batch end position
          onProgress?.call(retaggedCount, total);
        }

        // M9: Log summary of failures
        if (failedRecipes.isNotEmpty) {
          AppLogger.warning(
            '⚠️ Retagging completed with ${failedRecipes.length} failures: ${failedRecipes.take(5).join(', ')}${failedRecipes.length > 5 ? '...' : ''}',
            'TaggingService',
          );
        }

        AppLogger.info('🔄 Retagged $retaggedCount recipes for user $userId');
        return retaggedCount;
      },
      operationName: 'Retag user recipes',
      requiresAuth: true,
    );

    return result ?? 0;
  }

  /// MED-9: Basic validation of TagResult before saving.
  /// Checks for obvious issues that would indicate corrupt/invalid data.
  bool _isValidTagResult(TagResult result) {
    // Coverage must be in valid range (already clamped by constructor, but check anyway)
    if (result.coverage < 0.0 || result.coverage > 1.0) {
      return false;
    }

    // generatedAt should be reasonable (not in future, not too old)
    final now = DateTime.now();
    if (result.generatedAt.isAfter(now.add(const Duration(minutes: 1)))) {
      return false; // Future date indicates clock issue
    }

    // generatorVersion should be present for non-empty results
    if (result.generatorVersion == null && result.tags.isNotEmpty) {
      return false;
    }

    return true;
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
    // C1: Validate configs at startup - fail fast on typos
    PropertyRegistry.validateAllConfigs();

    await _lookupService.initialize();
    AppLogger.info('TaggingService ready with $kTagGeneratorVersion');
  }

  @override
  Future<void> onDispose() async {
    await _lookupService.dispose();
  }
}
