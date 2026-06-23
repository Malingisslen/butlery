import 'dart:async';

import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/tagging/tagging_service.dart';

/// CRIT-2: Automatic retagging scheduler for recipes that failed tagging.
///
/// Scans for recipes with failed or missing tags and automatically retags them
/// in batches to avoid overloading the system.
///
/// Usage:
/// ```dart
/// final scheduler = RetaggingScheduler(
///   taggingService: taggingService,
///   getRecipes: () => recipeService.getPersonalRecipes(),
///   saveRecipe: (recipe) => recipeService.updateRecipe(recipe),
/// );
/// scheduler.scheduleRetaggingCheck();
/// ```
class RetaggingScheduler with StreamManagementMixin {
  final TaggingService _taggingService;
  final Future<List<Recipe>> Function() _getRecipes;
  final Future<void> Function(Recipe) _saveRecipe;

  /// Delay before running retagging after app startup (in seconds).
  /// CRIT-15: Reduced from 30s to 5s to ensure failed recipes get retagged quickly.
  static const _startupDelaySeconds = 5;

  /// Number of recipes to process in each batch.
  static const _batchSize = 10;

  /// Delay between batches (in seconds).
  static const _batchDelaySeconds = 5;

  /// Maximum number of recipes to retag in a single session.
  static const _maxRetagsPerSession = 100;

  /// Maximum consecutive failures before skipping a recipe.
  static const _maxFailuresBeforeSkip = 3;

  /// Whether a retagging operation is currently in progress.
  bool _isRetagging = false;

  /// Tracks consecutive failure counts per recipe ID.
  /// Recipes that fail [_maxFailuresBeforeSkip]+ times are skipped
  /// until ingredient data changes (cache cleared via [resetFailureTracking]).
  final Map<String, int> _failureCounts = {};

  RetaggingScheduler({
    required TaggingService taggingService,
    required Future<List<Recipe>> Function() getRecipes,
    required Future<void> Function(Recipe) saveRecipe,
  }) : _taggingService = taggingService,
       _getRecipes = getRecipes,
       _saveRecipe = saveRecipe;

  /// Schedules a retagging check after the startup delay.
  ///
  /// Call this once when the app starts. It will wait for [_startupDelaySeconds]
  /// before checking for recipes that need retagging.
  void scheduleRetaggingCheck() {
    AppLogger.info(
      '📅 Scheduling retagging check in $_startupDelaySeconds seconds',
    );

    createTimer(
      const Duration(seconds: _startupDelaySeconds),
      () => _performRetagging(),
      name: 'startup',
    );
  }

  /// Starts periodic retagging checks.
  ///
  /// Runs a retagging check every [intervalHours] hours.
  void startPeriodicChecks({int intervalHours = 24}) {
    cancelNamedTimer('periodic');
    createPeriodicTimer(
      Duration(hours: intervalHours),
      () => _performRetagging(),
      name: 'periodic',
    );
    AppLogger.info(
      '📅 Started periodic retagging checks every $intervalHours hours',
    );
  }

  /// Stops periodic retagging checks.
  void stopPeriodicChecks() {
    cancelNamedTimer('periodic');
    AppLogger.info('📅 Stopped periodic retagging checks');
  }

  /// Performs a retagging operation for all recipes that need it.
  ///
  /// Returns the number of successfully retagged recipes.
  Future<int> _performRetagging() async {
    if (_isRetagging) {
      AppLogger.info('🔄 Retagging already in progress, skipping');
      return 0;
    }

    _isRetagging = true;
    var retaggedCount = 0;
    var failedCount = 0;

    try {
      AppLogger.info('🔄 Starting automatic retagging check...');

      final recipes = await _getRecipes();
      final recipesNeedingRetag = recipes.where(_needsRetagging).toList();

      if (recipesNeedingRetag.isEmpty) {
        AppLogger.info('✅ No recipes need retagging');
        return 0;
      }

      // Limit to prevent runaway retagging
      final recipesToProcess = recipesNeedingRetag
          .take(_maxRetagsPerSession)
          .toList();
      final totalToProcess = recipesToProcess.length;

      AppLogger.info(
        '🔄 Found ${recipesNeedingRetag.length} recipes needing retagging, '
        'processing $totalToProcess',
      );

      // Process in batches
      for (var i = 0; i < recipesToProcess.length; i += _batchSize) {
        final batchEnd = (i + _batchSize).clamp(0, recipesToProcess.length);
        final batch = recipesToProcess.sublist(i, batchEnd);

        // Process batch in parallel
        final results = await Future.wait(
          batch.map((recipe) => _retagRecipe(recipe)),
        );

        retaggedCount += results.where((success) => success).length;
        failedCount += results.where((success) => !success).length;

        AppLogger.debug(
          '🔄 Batch ${(i ~/ _batchSize) + 1}: '
          '${results.where((s) => s).length}/${batch.length} succeeded',
        );

        // Delay between batches to avoid overloading
        if (batchEnd < recipesToProcess.length) {
          await Future.delayed(const Duration(seconds: _batchDelaySeconds));
        }
      }

      AppLogger.success(
        '✅ Retagging complete: $retaggedCount succeeded, $failedCount failed',
      );
    } catch (e) {
      AppLogger.error('❌ Retagging error: $e');
    } finally {
      _isRetagging = false;
    }

    return retaggedCount;
  }

  /// Checks if a recipe needs retagging.
  bool _needsRetagging(Recipe recipe) {
    final tagResult = recipe.core.tagResult;

    // No tags at all
    if (tagResult == null) return true;

    // Skip all_unknown recipes — retagging will produce the same result
    // until new ingredients are added to the database
    if (tagResult.isAllUnknown) return false;

    // Skip recipes that have failed too many times consecutively
    final failures = _failureCounts[recipe.id] ?? 0;
    if (failures >= _maxFailuresBeforeSkip) return false;

    // Explicitly marked as failed
    if (tagResult.hasFailed) return true;

    // Lookup timeout (safe defaults, but should retry)
    if (tagResult.isLookupTimeout) return true;

    // Use the TagResult's own needsRetagging check
    return tagResult.needsRetagging;
  }

  /// Retags a single recipe.
  ///
  /// Returns true if retagging succeeded, false otherwise.
  /// Tracks consecutive failures per recipe to avoid wasting budget.
  Future<bool> _retagRecipe(Recipe recipe) async {
    try {
      final tagResult = await _taggingService.generateTags(recipe);

      if (tagResult == null) {
        _recordFailure(recipe.id);
        AppLogger.warning('⚠️ Retagging returned null for: ${recipe.id}');
        return false;
      }

      // Check if this is still a failure result
      if (tagResult.hasFailed || tagResult.isLookupTimeout) {
        _recordFailure(recipe.id);
        AppLogger.warning(
          '⚠️ Retagging still failed for: ${recipe.title} '
          '(${tagResult.generatorVersion})',
        );
        return false;
      }

      // Success — clear failure tracking
      _failureCounts.remove(recipe.id);

      // Create updated recipe with new tags
      final updatedRecipe = Recipe(
        core: recipe.core.copyWith(tagResult: tagResult),
        type: recipe.type,
        socialData: recipe.socialData,
        realtimeData: recipe.realtimeData,
        offlineData: recipe.offlineData,
      );

      await _saveRecipe(updatedRecipe);

      AppLogger.debug(
        '✅ Retagged "${recipe.title}" with ${tagResult.tags.length} tags '
        '(${(tagResult.coverage * 100).toStringAsFixed(0)}% coverage)',
      );

      return true;
    } catch (e) {
      _recordFailure(recipe.id);
      AppLogger.warning('⚠️ Failed to retag "${recipe.id}": $e');
      return false;
    }
  }

  void _recordFailure(String recipeId) {
    _failureCounts[recipeId] = (_failureCounts[recipeId] ?? 0) + 1;
    final count = _failureCounts[recipeId]!;
    if (count >= _maxFailuresBeforeSkip) {
      AppLogger.info(
        '⏭️ Recipe $recipeId skipped after $_maxFailuresBeforeSkip consecutive failures',
      );
    }
  }

  /// Resets failure tracking, allowing previously-skipped recipes to retry.
  /// Call when ingredient data changes (e.g., new ingredients added to DB).
  void resetFailureTracking() {
    _failureCounts.clear();
    AppLogger.info('🔄 Retagging failure tracking reset');
  }

  /// Manually triggers a retagging operation.
  ///
  /// Useful for testing or when the user explicitly requests a retag.
  Future<int> triggerManualRetagging() async {
    return await _performRetagging();
  }

  /// Disposes of resources.
  void dispose() {
    disposeStreamResources();
  }
}
