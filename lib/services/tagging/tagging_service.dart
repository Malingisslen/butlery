import 'package:clock/clock.dart';
import 'dart:async';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/tagging/config/property_registry.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/tag_config_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import 'package:butlery/services/tagging/tagging_events_tracker.dart';
import 'package:butlery/services/tagging/tagging_pipeline_runner.dart';

/// Main entry point for the automatic tagging system.
///
/// Orchestrates ingredient lookup and tag generation.
/// Supports user overrides for unknown ingredients.
class TaggingService extends BaseService {
  final IngredientLookupService _lookupService;
  final TagGenerator _tagGenerator;
  final UserIngredientRepository? _userIngredientRepository;
  final TaggingEventsTracker? _eventsTracker;

  /// BUT-553: per-phase budgeted pipeline. Replaces the previous single
  /// 30s wrapper-timeout so a slow Phase doesn't starve downstream phases.
  /// Built lazily after lookup service is initialised.
  late final TaggingPipelineRunner _pipelineRunner = TaggingPipelineRunner(
    lookupService: _lookupService,
    generator: _tagGenerator,
  );

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
  }) : _lookupService = lookupService,
       _tagGenerator =
           tagGenerator ??
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
      () => _generateTagsCore(recipe),
      operationName: 'Generate tags',
      requiresAuth: false, // Tagging doesn't require auth
    );
  }

  /// Core tag generation without error wrapping.
  /// Used directly by retagUserRecipes to get actionable error messages
  /// instead of silent nulls from executeServiceOperation.
  Future<TagResult> _generateTagsCore(Recipe recipe) async {
    AppLogger.info('🏷️ Generating tags for: ${recipe.core.title}');

    final ingredients =
        recipe.core.ingredientsNormalized ?? recipe.core.ingredients;

    if (ingredients.isEmpty) {
      AppLogger.warning('No ingredients found for recipe');
      return TagResult.empty();
    }

    return await _generateTagsWithBudgets(recipe, ingredients);
  }

  /// BUT-553: Runs the per-phase-budgeted pipeline (lookup + Phase 1..5)
  /// via [TaggingPipelineRunner]. Each phase has its own timeout budget,
  /// so a slow phase no longer starves downstream phases. Replaces the
  /// previous single 30s wrapper-timeout that fell back to
  /// `generatePhase1Only` whenever any phase exceeded its share.
  ///
  /// Phase budgets live in `tagging_phase_budgets.dart` so they can be
  /// tuned without touching orchestration code.
  Future<TagResult> _generateTagsWithBudgets(
    Recipe recipe,
    List<String> ingredients,
  ) async {
    final totalStopwatch = Stopwatch()..start();

    final pipelineResult = await _pipelineRunner.run(
      recipe: recipe,
      ingredients: ingredients,
      userId: _getCurrentUserId(),
    );

    totalStopwatch.stop();
    final tagResult = pipelineResult.tagResult;
    final lookupOutcome = pipelineResult.outcomes.firstWhere(
      (o) => o.phaseIndex == 0,
      orElse: () => const TaggingPhaseOutcome(
        phaseName: 'lookup',
        phaseIndex: 0,
        elapsedMs: 0,
        budgetMs: 0,
        result: 'unknown',
      ),
    );
    final generateMs = pipelineResult.outcomes
        .where((o) => o.phaseIndex >= 1)
        .fold<int>(0, (sum, o) => sum + o.elapsedMs);

    // Map outcome → legacy status string so the metrics dashboard keeps
    // working without a schema change.
    final status = _statusFromPipeline(pipelineResult);

    if (tagResult.isPartial) {
      AppLogger.warning(
        '⏱️ Tag generation partial '
            '(elapsed ${totalStopwatch.elapsedMilliseconds}ms, status=$status) '
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
      lookupMs: lookupOutcome.elapsedMs,
      generateMs: generateMs,
      ingredientCount: ingredients.length,
      tagCount: tagResult.tags.length,
      coveragePercent: (tagResult.coverage * 100).round(),
      status: status,
    );

    // Wire analytics events for recipe tagging and unknown ingredients
    _eventsTracker?.logRecipeTagged(
      recipeId: recipe.id,
      tagCount: tagResult.tags.length,
      coverage: tagResult.coverage,
      hasAllergens: tagResult.allergenStatus.isNotEmpty,
      hasDietary: tagResult.dietaryStatus.isNotEmpty,
    );
    if (tagResult.unknownIngredients.isNotEmpty) {
      _eventsTracker?.logUnknownIngredients(
        unknownIngredients: tagResult.unknownIngredients,
        totalIngredients: ingredients.length,
      );
    }

    return tagResult;
  }

  /// Maps a pipeline trace to the legacy status string set
  /// (`complete`, `partial`, `lookup_timeout`, `phase1_only`,
  /// `all_unknown`). Keeps `_logTaggingMetrics` schema unchanged so the
  /// existing dashboard queries still resolve.
  String _statusFromPipeline(TaggingPipelineResult pipeline) {
    final lookup = pipeline.outcomes
        .where((o) => o.phaseIndex == 0)
        .firstOrNull;
    if (lookup != null && lookup.result == 'timeout') {
      return 'lookup_timeout';
    }
    if (lookup != null && lookup.result == 'error') {
      return 'lookup_error';
    }
    final tags = pipeline.tagResult.tags;
    if (tags.length == 1 && tags.contains('timeout-warning')) {
      return 'lookup_timeout';
    }
    if (pipeline.tagResult.coverage == 0 &&
        pipeline.tagResult.unknownIngredients.isNotEmpty &&
        tags.isEmpty) {
      return 'all_unknown';
    }
    return pipeline.tagResult.isPartial ? 'partial' : 'complete';
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
      () => _lookupService.lookupFromRaw(
        ingredients,
        userId: _getCurrentUserId(),
      ),
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

        // Invalidate LRU cache so the new ingredient is found immediately
        _lookupService.clearLookupCache();

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
  /// Delegates to TagResult.needsRetagging for consistent behavior
  /// between the UI banner and the retag-all service operation.
  bool needsRetagging(Recipe recipe) {
    final existingResult = recipe.core.tagResult;
    if (existingResult == null) return true;
    return existingResult.needsRetagging;
  }

  /// Re-tags all recipes for a user.
  ///
  /// Use after ingredient database updates or when user requests retag.
  /// Processes in batches of 50 for scalability.
  ///
  /// [forceRetag] skips the needsRetagging filter, retagging ALL recipes.
  /// Use when the user explicitly requests a full retag (e.g. from settings).
  /// [onProgress] is called with (current, total) counts after each batch.
  Future<int> retagUserRecipes({
    required String userId,
    required Future<List<Recipe>> Function() getRecipes,
    required Future<void> Function(Recipe) saveRecipe,
    void Function(int current, int total)? onProgress,
    bool forceRetag = false,
  }) async {
    // Don't use executeServiceOperation here — errors must propagate
    // to the RetagProgressDialog so the user sees what went wrong
    // instead of a silent "0 recept omtaggade"
    final recipes = await getRecipes();
    AppLogger.info(
      'Retag: fetched ${recipes.length} recipes for user ${userId.maskedUserId}'
          ' (forceRetag: $forceRetag)',
      'TaggingService',
    );
    final recipesToRetag = forceRetag
        ? recipes
        : recipes.where(needsRetagging).toList();
    final total = recipesToRetag.length;

    if (total == 0) {
      AppLogger.info(
        'No recipes need retagging for user ${userId.maskedUserId}',
      );
      onProgress?.call(0, 0);
      return 0;
    }

    var retaggedCount = 0;
    const batchSize = 10;

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
            // Use _generateTagsCore directly to bypass executeServiceOperation
            // so errors propagate instead of being silently swallowed as null
            final tagResult = await _generateTagsCore(recipe);
            // MED-9: Validate tagResult before saving to prevent corrupt data
            if (_isValidTagResult(tagResult)) {
              final updatedRecipe = Recipe(
                core: recipe.core.copyWith(tagResult: tagResult),
                type: recipe.type,
                socialData: recipe.socialData,
                realtimeData: recipe.realtimeData,
                offlineData: recipe.offlineData,
              );
              await saveRecipe(updatedRecipe);
              return true;
            } else if (!_isValidTagResult(tagResult)) {
              AppLogger.warning(
                'MED-9: Invalid tagResult for recipe ${recipe.id}, skipping',
                'TaggingService',
              );
            }
            // M9: Track failed recipe
            failedRecipes.add(recipe.id);
            return false;
          } catch (e) {
            // M9: Log individual recipe failures with browser-visible output
            final msg = 'Failed to retag recipe ${recipe.id}: $e';
            AppLogger.warning(msg, 'TaggingService');
            failedRecipes.add(recipe.id);
            return false;
          }
        }),
      );

      retaggedCount += results.where((success) => success).length;
      // H12: Report actual completed count, not batch end position
      onProgress?.call(retaggedCount, total);

      // Delay between batches to avoid Firestore write spikes
      if (i + batchSize < recipesToRetag.length) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    // M9: Log summary of failures
    if (failedRecipes.isNotEmpty) {
      AppLogger.warning(
        'Retagging completed with ${failedRecipes.length} failures: ${failedRecipes.take(5).join(', ')}${failedRecipes.length > 5 ? '...' : ''}',
        'TaggingService',
      );
    }

    // Surface total failure to user instead of silent "0 recept omtaggade"
    if (retaggedCount == 0 && failedRecipes.isNotEmpty) {
      throw Exception(
        'All ${failedRecipes.length} recipes failed to retag',
      );
    }

    AppLogger.info(
      'Retagged $retaggedCount recipes for user ${userId.maskedUserId}',
    );
    return retaggedCount;
  }

  /// MED-9: Basic validation of TagResult before saving.
  /// Checks for obvious issues that would indicate corrupt/invalid data.
  bool _isValidTagResult(TagResult result) {
    // Coverage must be in valid range (already clamped by constructor, but check anyway)
    if (result.coverage < 0.0 || result.coverage > 1.0) {
      return false;
    }

    // generatedAt should be reasonable (not in future, not too old)
    final now = clock.now();
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
