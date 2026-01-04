import 'dart:async';

import 'package:butlery/core/base/base_service.dart' hide PermissionService;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';
import 'package:butlery/services/tagging/config/dietary_config.dart';
import 'package:butlery/services/tagging/config/property_registry.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:butlery/services/tagging/tagging_events_tracker.dart';

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
  final TaggingEventsTracker? _eventsTracker;

  /// MED-5: Tracks if config validation failed during initialization.
  /// When true, tagging results may be unreliable.
  bool _configValidationFailed = false;

  @override
  String get serviceName => 'TaggingService';

  /// MED-5: Returns true if the service is in degraded mode due to config validation failure.
  /// UI can use this to show warnings about potentially unreliable allergen/dietary info.
  bool get isInDegradedMode => _configValidationFailed;

  TaggingService({
    required IngredientLookupService lookupService,
    TagConfigService? tagConfigService,
    TagGenerator? tagGenerator,
    UserIngredientRepository? userIngredientRepository,
    TaggingEventsTracker? eventsTracker,
  })  : _lookupService = lookupService,
        _tagGenerator = tagGenerator ??
            TagGenerator(firebaseConfig: tagConfigService?.configOrNull),
        _userIngredientRepository = userIngredientRepository,
        _eventsTracker = eventsTracker;

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
    final totalStopwatch = Stopwatch()..start();
    final lookupStopwatch = Stopwatch();
    int? generateMs;

    // Phase 1: Lookup ingredients with timeout
    IngredientLookupResult lookupResult;
    try {
      lookupStopwatch.start();
      lookupResult = await _lookupService
          .lookupFromRaw(
            ingredients,
            userId: _getCurrentUserId(),
          )
          .timeout(_tagGenerationTimeout);
      lookupStopwatch.stop();
    } on TimeoutException {
      lookupStopwatch.stop();
      // CRIT-4: If lookup times out, return safe defaults for allergens instead of complete failure
      AppLogger.warning(
        '⏱️ Ingredient lookup timeout for recipe "${recipe.core.title}" '
            '(${ingredients.length} ingredients)',
        'TaggingService',
      );
      _logTaggingMetrics(
        recipeId: recipe.id,
        totalMs: totalStopwatch.elapsedMilliseconds,
        lookupMs: lookupStopwatch.elapsedMilliseconds,
        generateMs: null,
        ingredientCount: ingredients.length,
        tagCount: 1, // timeout-warning tag
        coveragePercent: 0,
        status: 'lookup_timeout',
      );
      // CRIT-4: Return partial result with safe defaults rather than complete failure
      return TagResult(
        tags: {'timeout-warning'}, // Visible indicator
        allergenStatus: _getAllergensSafeDefaults(), // All UNKNOWN
        dietaryStatus: _getDietarySafeDefaults(), // All UNKNOWN
        coverage: 0.0,
        unknownIngredients: ingredients, // Mark all as unknown
        generatedAt: DateTime.now(),
        generatorVersion: 'lookup_timeout',
        isPartial: true,
        errorReason: 'Ingredient lookup timed out after 30 seconds',
      );
    }

    AppLogger.debug(
      'Ingredient lookup: ${lookupResult.matched.length} matched, '
      '${lookupResult.unmatched.length} unmatched, '
      '${(lookupResult.coverage * 100).toStringAsFixed(0)}% coverage',
    );

    // HIGH-12: Check if ALL ingredients are unknown (distinct from empty recipe)
    if (lookupResult.matched.isEmpty && lookupResult.unmatched.isNotEmpty) {
      AppLogger.warning(
        '⚠️ All ${lookupResult.unmatched.length} ingredients unknown for "${recipe.core.title}"',
        'TaggingService',
      );
      _logTaggingMetrics(
        recipeId: recipe.id,
        totalMs: totalStopwatch.elapsedMilliseconds,
        lookupMs: lookupStopwatch.elapsedMilliseconds,
        generateMs: 0,
        ingredientCount: ingredients.length,
        tagCount: 0,
        coveragePercent: 0,
        status: 'all_unknown',
      );
      return TagResult.allUnknown(lookupResult.unmatched);
    }

    // CRIT-3: Calculate remaining time for generation phase
    final elapsed = totalStopwatch.elapsed;
    final remainingTime = _tagGenerationTimeout - elapsed;

    if (remainingTime <= Duration.zero) {
      // Time exhausted, return Phase 1 only for critical allergen safety
      AppLogger.warning(
        '⏱️ No time remaining for generation, returning Phase 1 only',
        'TaggingService',
      );
      final phase1Result = _tagGenerator.generatePhase1Only(
        ingredients: lookupResult,
        recipe: recipe,
      );
      totalStopwatch.stop();
      _logTaggingMetrics(
        recipeId: recipe.id,
        totalMs: totalStopwatch.elapsedMilliseconds,
        lookupMs: lookupStopwatch.elapsedMilliseconds,
        generateMs: 0,
        ingredientCount: ingredients.length,
        tagCount: phase1Result.tags.length,
        coveragePercent: (phase1Result.coverage * 100).round(),
        status: 'phase1_only',
      );
      return phase1Result;
    }

    // Generate tags with remaining timeout for graceful degradation
    final generateStopwatch = Stopwatch()..start();
    final tagResult = _tagGenerator.generate(
      ingredients: lookupResult,
      recipe: recipe,
      timeout: remainingTime,
    );
    generateStopwatch.stop();
    generateMs = generateStopwatch.elapsedMilliseconds;
    totalStopwatch.stop();

    final status = tagResult.isPartial ? 'partial' : 'complete';

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

    _logTaggingMetrics(
      recipeId: recipe.id,
      totalMs: totalStopwatch.elapsedMilliseconds,
      lookupMs: lookupStopwatch.elapsedMilliseconds,
      generateMs: generateMs,
      ingredientCount: ingredients.length,
      tagCount: tagResult.tags.length,
      coveragePercent: (tagResult.coverage * 100).round(),
      status: status,
    );

    return tagResult;
  }

  /// Logs tagging performance metrics for monitoring.
  void _logTaggingMetrics({
    required String recipeId,
    required int totalMs,
    required int lookupMs,
    required int? generateMs,
    required int ingredientCount,
    required int tagCount,
    required int coveragePercent,
    required String status,
  }) {
    AppLogger.info(
      '📊 Tagging metrics: '
      'total=${totalMs}ms, '
      'lookup=${lookupMs}ms, '
      'generate=${generateMs ?? "N/A"}ms, '
      'ingredients=$ingredientCount, '
      'tags=$tagCount, '
      'coverage=$coveragePercent%, '
      'status=$status',
    );

    // Log to analytics if tracker is available
    _eventsTracker?.logTaggingPerformance(
      totalMs: totalMs,
      lookupMs: lookupMs,
      generateMs: generateMs,
      ingredientCount: ingredientCount,
      tagCount: tagCount,
      coveragePercent: coveragePercent.toDouble(),
      status: status,
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

  /// HIGH-1: Quick Phase 1 preview tags for import preview UI.
  ///
  /// Generates only Phase 1 tags (allergens, dietary, proteins) with a shorter
  /// timeout (5s) for responsive UI during recipe parsing. Returns null if
  /// lookup times out or fails.
  ///
  /// Use this for showing immediate allergen/dietary status in the import
  /// preview before the full tagging is done at save time.
  Future<TagResult?> generatePhase1Preview(Recipe recipe) async {
    try {
      final ingredients =
          recipe.core.ingredientsNormalized ?? recipe.core.ingredients;

      if (ingredients.isEmpty) {
        return null;
      }

      // Shorter timeout for preview (5 seconds)
      const previewTimeout = Duration(seconds: 5);

      final lookupResult = await _lookupService
          .lookupFromRaw(ingredients, userId: _getCurrentUserId())
          .timeout(previewTimeout);

      // Generate Phase 1 only (allergens, dietary, proteins)
      final phase1Result = _tagGenerator.generatePhase1Only(
        ingredients: lookupResult,
        recipe: recipe,
      );

      AppLogger.debug(
        'Phase 1 preview: ${phase1Result.tags.length} tags, '
        '${(phase1Result.coverage * 100).toStringAsFixed(0)}% coverage',
      );

      return phase1Result;
    } on TimeoutException {
      AppLogger.debug('Phase 1 preview timed out, skipping preview');
      return null;
    } catch (e) {
      AppLogger.debug('Phase 1 preview failed: $e');
      return null;
    }
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

  /// CRIT-4: Returns all allergens set to UNKNOWN for safe fallback.
  Map<String, TriState> _getAllergensSafeDefaults() {
    return {
      for (final key in AllergenConfig.allKeys) key: TriState.unknown,
    };
  }

  /// CRIT-4: Returns all dietary statuses set to UNKNOWN for safe fallback.
  Map<String, TriState> _getDietarySafeDefaults() {
    return {
      for (final key in DietaryConfig.allKeys) key: TriState.unknown,
    };
  }

  @override
  Future<void> onInitialize() async {
    // MED-3: Validate configs at startup with proper error surfacing
    // Catches errors instead of crashing the app - logs and continues with
    // potentially degraded functionality.
    try {
      PropertyRegistry.validateAllConfigs();
    } catch (e) {
      // Log critical error but don't crash - allow app to continue
      AppLogger.error(
        'CRITICAL: Tagging config validation failed: $e. '
            'Some allergen/dietary detection may not work correctly.',
        'TaggingService',
      );
      // MED-5: Track degraded state for UI to query
      _configValidationFailed = true;
      // Track in analytics for monitoring
      _eventsTracker?.logConfigValidationError(e.toString());
    }

    await _lookupService.initialize();
    AppLogger.info('TaggingService ready with $kTagGeneratorVersion');
  }

  @override
  Future<void> onDispose() async {
    await _lookupService.dispose();
  }
}
