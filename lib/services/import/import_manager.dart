/// Import manager with strategy pattern for multi-format imports (text, archive, URL, file) and batch processing.
/// ```dart
/// final im = ImportManager(ops); await im.autoImport(text);

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/archive_import_strategy.dart';
import 'package:butlery/services/import/file_import_strategy.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/import/photo_import_strategy.dart';
import 'package:butlery/services/import/youtube/youtube_import_strategy.dart';
import 'package:butlery/services/import/pipelines/tiktok_pipeline.dart';
import 'package:butlery/services/import/cache/global_recipe_cache.dart';
import 'package:butlery/services/import/cache/cache_entry.dart';
import 'package:butlery/services/import/cache/url_normalizer.dart';
import 'package:butlery/services/import/import_manager_result.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:http/http.dart' as http;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

export 'package:butlery/services/import/import_manager_result.dart';

/// Import manager coordinating multiple import strategies with auto-selection, fallback, and batch processing.
class ImportManager {
  final PersonalRecipeOperations _personalOperations;
  final List<ImportStrategy> _strategies = [];

  /// Lazily initialized cache reference
  GlobalRecipeCache? _cache;
  UrlNormalizer? _urlNormalizer;

  ImportManager(this._personalOperations) {
    _initializeStrategies();
  }

  /// Get the global recipe cache (lazy initialization with graceful fallback)
  GlobalRecipeCache? get _globalCache {
    if (_cache != null) return _cache;
    try {
      _cache = ServiceLocator.get<GlobalRecipeCache>();
      return _cache;
    } catch (e) {
      AppLogger.debug('ImportManager: GlobalRecipeCache not available: $e');
      return null;
    }
  }

  /// Get the URL normalizer (lazy initialization with graceful fallback)
  UrlNormalizer? get _normalizer {
    if (_urlNormalizer != null) return _urlNormalizer;
    try {
      _urlNormalizer = ServiceLocator.get<UrlNormalizer>();
      return _urlNormalizer;
    } catch (e) {
      AppLogger.debug('ImportManager: UrlNormalizer not available: $e');
      return null;
    }
  }

  /// Get the YouTube import strategy (lazy initialization with graceful fallback)
  YouTubeImportStrategy? get _youtubeStrategy {
    try {
      return ServiceLocator.get<YouTubeImportStrategy>();
    } catch (e) {
      AppLogger.debug('ImportManager: YouTubeImportStrategy not available: $e');
      return null;
    }
  }

  /// Get the TikTok import pipeline (lazy initialization with graceful fallback)
  TikTokPipeline? get _tiktokPipeline {
    try {
      return ServiceLocator.get<TikTokPipeline>();
    } catch (e) {
      AppLogger.debug('ImportManager: TikTokPipeline not available: $e');
      return null;
    }
  }

  /// Get the tagging service (lazy initialization with graceful fallback)
  TaggingService? get _taggingService {
    try {
      return ServiceLocator.get<TaggingService>();
    } catch (e) {
      AppLogger.warning(
        '⚠️ TaggingService unavailable during import: $e. '
        'Recipes will be saved without allergen/dietary tagging.',
      );
      return null;
    }
  }

  void _initializeStrategies() {
    // Register available import strategies in priority order
    _strategies.addAll([
      ArchiveImportStrategy(), // 1. Try archive first (fast, pre-validated)
      UrlImportStrategy(
        httpClient: ServiceLocator.tryGet<http.Client>(),
      ), // 2. Try URL import (web scraping)
      TextImportStrategy(), // 3. Try text parsing (fallback for plain text)
      FileImportStrategy(), // 4. File import (explicit file selection)
      PhotoImportStrategy(), // 5. Photo import (OCR extraction)
    ]);
  }

  /// Get all available import strategies
  List<ImportStrategy> get availableStrategies =>
      List.unmodifiable(_strategies);

  /// Auto-detects strategy and parses recipe WITHOUT saving (for preview/validation).
  /// ```dart
  /// final r = await im.autoParseOnly(text); if (r.isSuccess) showPreview(r.recipe!);
  Future<ImportManagerResult> autoParseOnly(
    String input, {
    ImportStrategy? preferredStrategy,
    Map<String, dynamic>? options,
  }) async {
    try {
      // Try preferred strategy first if provided
      if (preferredStrategy != null && preferredStrategy.canHandle(input)) {
        final result =
            await _parseWithStrategy(preferredStrategy, input, options);
        if (result.isSuccess) {
          return result;
        }
      }

      // Try all compatible strategies
      for (final strategy in _strategies) {
        if (strategy.canHandle(input)) {
          final result = await _parseWithStrategy(strategy, input, options);
          if (result.isSuccess) {
            return result;
          }
        }
      }

      // No strategy could handle the input
      return ImportManagerResult.failure(
        'No import strategy could handle the provided input',
        availableStrategies: _strategies.map((s) => s.strategyName).toList(),
      );
    } catch (e) {
      return ImportManagerResult.failure(
        'Import manager error: $e',
        availableStrategies: _strategies.map((s) => s.strategyName).toList(),
      );
    }
  }

  /// Auto-detects strategy and imports recipe with fallback (tries all compatible strategies).
  /// ```dart
  /// final r = await im.autoImport(content, preferredStrategy: textStrategy);
  Future<ImportManagerResult> autoImport(
    String input, {
    ImportStrategy? preferredStrategy,
    Map<String, dynamic>? options,
  }) async {
    try {
      final cacheResult = await _checkCacheForUrl(input);
      if (cacheResult != null) {
        return cacheResult;
      }

      final youtubeStrategy = _youtubeStrategy;
      if (youtubeStrategy != null && youtubeStrategy.canHandle(input)) {
        final result =
            await _parseWithStrategy(youtubeStrategy, input, options);

        // Handle all YouTube results - don't fall back to WebScraper for YouTube URLs
        if (result.isSuccess || result.needsAssistance) {
          await _saveToCacheIfUrl(input, result);
          return result;
        }

        // Check for "needs screenshot" case - this is a valid result, not a fallback-worthy failure
        if (result.metadata?['needsScreenshot'] == true) {
          // Convert to user-assisted import with helpful message
          return ImportManagerResult.assistance(
            extractedText:
                result.errorMessage ?? AppLocale.current.errorVideoNoSubtitles,
            suggestedTitle: null,
            sourceUrl: result.metadata?['url'] as String?,
            thumbnailUrl: result.metadata?['thumbnailUrl'] as String?,
            strategy: 'youtube',
            metadata: result.metadata,
          );
        }

        // YouTube strategy failed, continue with other strategies
      }

      final tiktokPipeline = _tiktokPipeline;
      if (tiktokPipeline != null && tiktokPipeline.canHandle(input)) {
        final result = await _parseWithStrategy(tiktokPipeline, input, options);
        if (result.isSuccess || result.needsAssistance) {
          await _saveToCacheIfUrl(input, result);
          return result;
        }
        // TikTok pipeline failed, continue with other strategies
      }

      if (preferredStrategy != null && preferredStrategy.canHandle(input)) {
        final result =
            await _parseWithStrategy(preferredStrategy, input, options);
        if (result.isSuccess) {
          // Save to cache on success
          await _saveToCacheIfUrl(input, result);
          return result;
        }
      }

      for (final strategy in _strategies) {
        if (strategy.canHandle(input)) {
          final result = await _parseWithStrategy(strategy, input, options);
          if (result.isSuccess) {
            // Save to cache on success
            await _saveToCacheIfUrl(input, result);
            return result;
          }
        }
      }

      // No strategy could handle the input
      return ImportManagerResult.failure(
        'No import strategy could handle the provided input',
        availableStrategies: _strategies.map((s) => s.strategyName).toList(),
      );
    } catch (e) {
      return ImportManagerResult.failure(
        'Import manager error: $e',
        availableStrategies: _strategies.map((s) => s.strategyName).toList(),
      );
    }
  }

  /// Import using a specific strategy
  Future<ImportManagerResult> importWithStrategy(
    String strategyName,
    String input, {
    Map<String, dynamic>? options,
  }) async {
    final strategy =
        _strategies.where((s) => s.strategyName == strategyName).firstOrNull;

    if (strategy == null) {
      return ImportManagerResult.failure(
        'Strategy not found: $strategyName',
        availableStrategies: _strategies.map((s) => s.strategyName).toList(),
      );
    }

    return await _parseWithStrategy(strategy, input, options);
  }

  /// Processes multiple recipe imports in batch with comprehensive progress tracking and error aggregation.
  /// This method provides efficient batch processing for multiple recipe imports with individual strategy
  /// selection, comprehensive error collection, and detailed result reporting. It processes each input
  /// independently while aggregating results for comprehensive batch operation feedback and analytics.
  /// [inputs] List of recipe content in various supported formats for batch processing
  /// [preferredStrategy] Optional strategy to prefer for all imports in the batch
  /// [options] Optional configuration parameters applied to all import operations
  /// Returns [BatchImportResult] with individual results, success statistics, and error aggregation
  /// **Batch Processing Features:**
  /// - **Individual Processing**: Each input processed independently with optimal strategy selection
  /// - **Error Isolation**: Failed imports don't affect successful imports in the same batch
  /// - **Progress Tracking**: Detailed statistics on success/failure rates and processing progress
  /// - **Result Aggregation**: Comprehensive collection of successful recipes and error information
  /// - **Strategy Analytics**: Tracking of strategy usage and success rates across batch operations
  /// **Performance Optimization:**
  /// - Sequential processing prevents resource contention and ensures stability
  /// - Memory-efficient processing with immediate result collection and cleanup
  /// - Strategy reuse across batch items for optimal performance
  /// - Comprehensive error handling prevents batch failure from individual errors
  /// **Result Management:**
  /// - Separate collections for successful recipes and error messages
  /// - Detailed statistics including success rate and processing counts
  /// - Individual result preservation for detailed analysis and debugging
  /// - Strategy tracking for batch operation analytics and optimization
  /// **Usage Examples:**
  /// ```dart
  /// // Batch import with progress tracking
  /// final batchResult = await importManager.batchImport(recipeTexts);
  /// // Display batch results
  /// print('Imported ${batchResult.successCount}/${batchResult.totalProcessed} recipes');
  /// print('Success rate: ${(batchResult.successRate * 100).toInt()}%');
  /// // Handle successful imports
  /// for (final recipe in batchResult.successfulRecipes) {
  ///   addToRecipeCollection(recipe);
  /// }
  /// // Handle errors with detailed feedback
  /// if (batchResult.hasErrors) {
  ///   showBatchErrors(batchResult.errors);
  /// }
  /// ```
  /// HIGH-3: Concurrency limit for parallel batch processing.
  /// Processing 5 recipes at a time balances speed and resource usage.
  static const _batchConcurrencyLimit = 5;

  Future<BatchImportResult> batchImport(
    List<String> inputs, {
    ImportStrategy? preferredStrategy,
    Map<String, dynamic>? options,
  }) async {
    final results = <ImportManagerResult>[];
    final recipes = <Recipe>[];
    final errors = <String>[];

    // HIGH-3: Process in parallel batches instead of sequentially
    for (var i = 0; i < inputs.length; i += _batchConcurrencyLimit) {
      final batchEnd = (i + _batchConcurrencyLimit).clamp(0, inputs.length);
      final batch = inputs.sublist(i, batchEnd);

      // Process this batch in parallel
      final batchResults = await Future.wait(
        batch.map((input) => autoImport(
              input,
              preferredStrategy: preferredStrategy,
              options: options,
            )),
      );

      for (final result in batchResults) {
        results.add(result);

        if (result.isSuccess && result.recipe != null) {
          recipes.add(result.recipe!);
        } else {
          errors.add(result.errorMessage ?? 'Unknown error');
        }
      }

      AppLogger.debug(
        'Batch import progress: ${results.length}/${inputs.length} processed',
      );
    }

    return BatchImportResult(
      results: results,
      successfulRecipes: recipes,
      errors: errors,
      totalProcessed: inputs.length,
      successCount: recipes.length,
      failureCount: errors.length,
    );
  }

  /// Get strategies that can handle the given input
  List<ImportStrategy> getCompatibleStrategies(String input) {
    return _strategies.where((strategy) => strategy.canHandle(input)).toList();
  }

  /// Validate input for import
  bool validateInput(String input, {ImportStrategy? strategy}) {
    if (strategy != null) {
      return strategy.validateInput(input);
    }

    // Check if any strategy can validate the input
    return _strategies.any((s) => s.validateInput(input));
  }

  /// Get import suggestions for input
  List<ImportSuggestion> getImportSuggestions(String input) {
    final suggestions = <ImportSuggestion>[];

    for (final strategy in _strategies) {
      if (strategy.canHandle(input)) {
        suggestions.add(ImportSuggestion(
          strategy: strategy,
          confidence: _calculateConfidence(strategy, input),
          description: strategy.description,
        ));
      }
    }

    // Sort by confidence (highest first)
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));

    return suggestions;
  }

  /// Get text import strategy for direct usage
  TextImportStrategy getTextImportStrategy() {
    final textStrategy =
        _strategies.whereType<TextImportStrategy>().firstOrNull;

    if (textStrategy == null) {
      throw StateError('TextImportStrategy not found in available strategies');
    }

    return textStrategy;
  }

  /// Save imported recipe using PersonalRecipeOperations.
  /// Automatically generates tags for the recipe before saving.
  Future<ImportManagerResult> saveImportedRecipe(Recipe recipe) async {
    try {
      // Auto-generate tags for imported recipe
      Recipe recipeToSave = recipe;
      final taggingService = _taggingService;

      if (taggingService != null && recipe.tagResult == null) {
        AppLogger.info('🏷️ Auto-tagging imported recipe: ${recipe.title}');

        final tagResult = await taggingService.generateTags(recipe);

        if (tagResult != null) {
          // Create new Recipe with updated core containing tagResult
          recipeToSave = Recipe(
            core: recipe.core.copyWith(tagResult: tagResult),
            type: recipe.type,
            socialData: recipe.socialData,
            realtimeData: recipe.realtimeData,
            offlineData: recipe.offlineData,
          );
          AppLogger.success(
            '✅ Generated ${tagResult.tags.length} tags '
            '(coverage: ${(tagResult.coverage * 100).toStringAsFixed(0)}%)',
          );
        } else {
          // CRIT-1: Mark recipe as needing retagging instead of saving without marker
          AppLogger.warning('⚠️ Tagging returned null for: ${recipe.title}');
          recipeToSave = Recipe(
            core: recipe.core.copyWith(
              tagResult:
                  TagResult.failed(reason: 'Tagging service returned null'),
            ),
            type: recipe.type,
            socialData: recipe.socialData,
            realtimeData: recipe.realtimeData,
            offlineData: recipe.offlineData,
          );
        }
      }

      final saveResult =
          await _personalOperations.addUnifiedRecipe(recipeToSave);

      if (saveResult.isSuccess) {
        return ImportManagerResult.success(
          recipeToSave,
          strategy: 'direct_save',
        );
      } else {
        return ImportManagerResult.failure(
          'Failed to save recipe: ${saveResult.message}',
          strategy: 'direct_save',
        );
      }
    } catch (e) {
      return ImportManagerResult.failure(
        'Error saving recipe: $e',
        strategy: 'direct_save',
      );
    }
  }

  /// Parse with strategy without saving - returns recipe in memory only
  Future<ImportManagerResult> _parseWithStrategy(
    ImportStrategy strategy,
    String input,
    Map<String, dynamic>? options,
  ) async {
    try {
      // Execute import strategy to parse recipe
      final importResult = await strategy.import(input, options: options);

      if (!importResult.isSuccess) {
        return ImportManagerResult.failure(
          importResult.errorMessage ?? 'Parse failed',
          strategy: strategy.strategyName,
          warnings: importResult.warnings,
        );
      }

      if (importResult.recipe == null) {
        return ImportManagerResult.failure(
          'Parse successful but no recipe returned',
          strategy: strategy.strategyName,
        );
      }

      // HIGH-1: Generate preview tags for immediate allergen/dietary display
      var recipeWithPreview = importResult.recipe!;
      if (_taggingService != null && recipeWithPreview.tagResult == null) {
        final previewTags =
            await _taggingService!.generatePhase1Preview(recipeWithPreview);
        if (previewTags != null) {
          recipeWithPreview = Recipe(
            core: recipeWithPreview.core.copyWith(tagResult: previewTags),
            type: recipeWithPreview.type,
            socialData: recipeWithPreview.socialData,
            realtimeData: recipeWithPreview.realtimeData,
            offlineData: recipeWithPreview.offlineData,
          );
        }
      }

      // Return parsed recipe WITHOUT saving to storage
      return ImportManagerResult.success(
        recipeWithPreview,
        strategy: strategy.strategyName,
        warnings: importResult.warnings,
        metadata: importResult.metadata,
      );
    } catch (e) {
      return ImportManagerResult.failure(
        'Parse execution error: $e',
        strategy: strategy.strategyName,
      );
    }
  }

  double _calculateConfidence(ImportStrategy strategy, String input) {
    // Basic confidence calculation - can be enhanced
    if (!strategy.canHandle(input)) return 0.0;

    // Archive import has highest confidence for known IDs
    if (strategy is ArchiveImportStrategy) {
      return 0.9;
    }

    // Text import is flexible but lower confidence
    if (strategy is TextImportStrategy) {
      return 0.6;
    }

    return 0.5; // Default confidence
  }

  /// Check if input looks like a URL and return cached result if available.
  Future<ImportManagerResult?> _checkCacheForUrl(String input) async {
    final cache = _globalCache;
    final normalizer = _normalizer;

    if (cache == null || normalizer == null) {
      return null; // Cache not available
    }

    // Only check cache for URL-like inputs
    if (!normalizer.looksLikeUrl(input)) {
      return null;
    }

    try {
      final cacheEntry = await cache.findByUrl(input);

      if (cacheEntry == null) {
        return null; // Cache miss
      }

      // Create recipe from cached data
      var recipe = _recipeFromCacheEntry(cacheEntry);
      if (recipe == null) {
        AppLogger.warning('ImportManager: Invalid recipe data in cache');
        return null;
      }

      // HIGH-2: Check if cached recipe needs retagging
      final needsRetagging = _cachedRecipeNeedsRetagging(recipe, cacheEntry);
      if (needsRetagging) {
        AppLogger.info(
          'ImportManager: Cache hit but needs retagging '
          '(age: ${cacheEntry.ageInDays} days)',
        );
        recipe = await _retagCachedRecipe(recipe);
      }

      // Note: Recipe is NOT saved here - user will save after reviewing in editor

      AppLogger.info(
        'ImportManager: Loaded from cache '
        '(source: ${cacheEntry.sourceType}, domain: ${cacheEntry.domain})',
      );

      return ImportManagerResult.success(
        recipe,
        strategy: 'cache',
        metadata: {
          'fromCache': true,
          'cacheAge': cacheEntry.ageInDays,
          'originalPipeline': cacheEntry.extractionMeta.pipeline,
          'originalTier': cacheEntry.extractionMeta.tier,
          'originalMethod': cacheEntry.extractionMeta.method,
          'retagged': needsRetagging,
        },
      );
    } catch (e) {
      AppLogger.debug('ImportManager: Cache lookup failed: $e');
      return null; // Continue with normal import on cache error
    }
  }

  /// Save successful import result to cache if input is a URL.
  Future<void> _saveToCacheIfUrl(
    String input,
    ImportManagerResult result,
  ) async {
    final cache = _globalCache;
    final normalizer = _normalizer;

    if (cache == null || normalizer == null) {
      return; // Cache not available
    }

    // Only cache URL-based imports
    if (!normalizer.looksLikeUrl(input)) {
      return;
    }

    // Don't cache if already from cache
    if (result.metadata?['fromCache'] == true) {
      return;
    }

    if (result.recipe == null) {
      return;
    }

    try {
      final recipeData = result.recipe!.toJson();

      // Determine source type based on strategy
      final sourceType = _sourceTypeFromStrategy(result.strategy);

      // Create extraction metadata
      final extractionMeta = ExtractionMeta(
        pipeline: sourceType,
        tier: 0, // Phase 4 will add proper tier tracking
        method: result.strategy ?? 'unknown',
        confidence: 0.8, // Default confidence for now
      );

      await cache.save(
        input: input,
        recipeData: recipeData,
        extractionMeta: extractionMeta,
        sourceType: sourceType,
      );

      AppLogger.debug(
        'ImportManager: Saved to cache (source: $sourceType)',
      );
    } catch (e) {
      // Don't fail import if cache save fails
      AppLogger.debug('ImportManager: Cache save failed: $e');
    }
  }

  /// Create a Recipe from cache entry data.
  Recipe? _recipeFromCacheEntry(CacheEntry entry) {
    try {
      return Recipe.fromJson(entry.recipe);
    } catch (e) {
      AppLogger.warning('ImportManager: Failed to parse cached recipe: $e');
      return null;
    }
  }

  /// Determine source type from strategy name.
  String _sourceTypeFromStrategy(String? strategy) {
    if (strategy == null) return 'unknown';

    final lower = strategy.toLowerCase();
    if (lower.contains('url')) return 'website';
    if (lower.contains('youtube')) return 'youtube';
    if (lower.contains('tiktok')) return 'tiktok';
    if (lower.contains('instagram')) return 'instagram';
    if (lower.contains('photo') || lower.contains('ocr')) return 'ocr';
    if (lower.contains('text')) return 'text';
    if (lower.contains('archive')) return 'archive';

    return 'website'; // Default for URL imports
  }

  /// HIGH-2: Checks if a cached recipe needs retagging.
  ///
  /// Returns true if:
  /// - Cache entry is older than 30 days
  /// - Recipe has no tags
  /// - Recipe's tagResult indicates it needs retagging
  bool _cachedRecipeNeedsRetagging(Recipe recipe, CacheEntry cacheEntry) {
    // Age-based retagging (> 30 days)
    if (cacheEntry.ageInDays > 30) {
      return true;
    }

    // No tags at all
    final tagResult = recipe.tagResult;
    if (tagResult == null) {
      return true;
    }

    // Check if tagResult indicates it needs retagging
    return tagResult.needsRetagging;
  }

  /// HIGH-2: Retags a cached recipe.
  ///
  /// Returns the recipe with updated tags, or the original recipe if
  /// tagging fails.
  Future<Recipe> _retagCachedRecipe(Recipe recipe) async {
    final taggingService = _taggingService;
    if (taggingService == null) {
      return recipe; // Can't retag without service
    }

    try {
      final tagResult = await taggingService.generateTags(recipe);
      if (tagResult != null) {
        AppLogger.success(
          '✅ Retagged cached recipe with ${tagResult.tags.length} tags '
          '(coverage: ${(tagResult.coverage * 100).toStringAsFixed(0)}%)',
        );
        return Recipe(
          core: recipe.core.copyWith(tagResult: tagResult),
          type: recipe.type,
          socialData: recipe.socialData,
          realtimeData: recipe.realtimeData,
          offlineData: recipe.offlineData,
        );
      }
    } catch (e) {
      AppLogger.warning('Failed to retag cached recipe: $e');
    }

    return recipe; // Return original on failure
  }
}
