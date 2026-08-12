/// Import manager with strategy pattern for multi-format imports (text, archive, URL, file) and batch processing.
/// ```dart
/// final im = ImportManager(ops); await im.autoImport(text);

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/layout/frame_trim.dart';
import 'package:butlery/services/import/multi_recipe_splitter.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:butlery/services/import/archive_import_strategy.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/import/photo_import_strategy.dart';
import 'package:butlery/services/import/voice_import_strategy.dart';
import 'package:butlery/services/import/youtube/youtube_import_strategy.dart';
import 'package:butlery/services/import/pipelines/tiktok_pipeline.dart';
import 'package:butlery/services/import/pipelines/instagram_pipeline.dart';
import 'package:butlery/services/import/cache/global_recipe_cache.dart';
import 'package:butlery/services/import/cache/cache_entry.dart';
import 'package:butlery/services/import/cache/url_normalizer.dart';
import 'package:butlery/services/import/import_manager_result.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/parsing/parse_event_logger.dart';
import 'package:http/http.dart' as http;
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

export 'package:butlery/services/import/import_manager_result.dart';

/// Import manager coordinating multiple import strategies with auto-selection, fallback, and batch processing.
class ImportManager {
  final PersonalRecipeOperations _personalOperations;
  final List<ImportStrategy> _strategies = [];

  /// BUT-1470: server-side parse-event logger. Injectable so the logging can
  /// be exercised in unit tests without a live Firebase app. Lazy on Firebase
  /// at construction (see ParseEventLogger), so the default is test-safe too.
  final ParseEventLogger _eventLogger;

  /// Lazily initialized cache reference
  GlobalRecipeCache? _cache;
  UrlNormalizer? _urlNormalizer;

  ImportManager(this._personalOperations, {ParseEventLogger? eventLogger})
    : _eventLogger = eventLogger ?? ParseEventLogger() {
    _initializeStrategies();
  }

  /// Test-only constructor that accepts pre-built strategies, avoiding
  /// Firebase/network initialisation that `_initializeStrategies` triggers.
  @visibleForTesting
  ImportManager.withStrategies(
    this._personalOperations,
    List<ImportStrategy> strategies, {
    ParseEventLogger? eventLogger,
  }) : _eventLogger = eventLogger ?? ParseEventLogger() {
    _strategies.addAll(strategies);
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

  InstagramPipeline? get _instagramPipeline {
    try {
      return ServiceLocator.get<InstagramPipeline>();
    } catch (e) {
      AppLogger.debug('ImportManager: InstagramPipeline not available: $e');
      return null;
    }
  }

  /// Get the rate limiter (lazy initialization with graceful fallback)
  ImportRateLimiter? get _rateLimiter {
    try {
      return ServiceLocator.get<ImportRateLimiter>();
    } catch (e) {
      AppLogger.debug('ImportManager: ImportRateLimiter not available: $e');
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
    // Register available import strategies in priority order.
    // FileImportStrategy is deliberately NOT registered: its canHandle()
    // always returns false (file import is picker-driven, not text-driven),
    // so it was unreachable in the auto loops (BUT-1487). The picker path
    // constructs it directly via FileImportViewModel.
    _strategies.addAll([
      ArchiveImportStrategy(), // 1. Try archive first (fast, pre-validated)
      UrlImportStrategy(
        httpClient: ServiceLocator.tryGet<http.Client>(),
      ), // 2. Try URL import (web scraping)
      TextImportStrategy(), // 3. Try text parsing (fallback for plain text)
      PhotoImportStrategy(), // 4. Photo import (OCR extraction)
      // 5. Voice dictation — canHandle() always false (explicitly launched
      // from the voice wizard, never auto-selected); registered so
      // importVoiceTranscript flows through _parseWithStrategy and gets
      // parse-event telemetry under its own 'voice' source tag.
      VoiceImportStrategy(),
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
        final result = await _parseWithStrategy(
          preferredStrategy,
          input,
          options,
        );
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
    void Function(String phase)? onProgress,
  }) async {
    try {
      // Rate limit check for basic imports
      final rateLimiter = _rateLimiter;
      final operation = ImportOperation.basic('auto');
      if (rateLimiter != null) {
        final limitResult = await rateLimiter.checkLimit(operation);
        if (limitResult is RateLimitDenied) {
          // BUT-1144: surface the structured denial so the VM can render
          // the real retryAfter / limitType / suggestedAction.
          return ImportManagerResult.rateLimit(limitResult);
        }
      }

      // Phase: fetching — cache check and strategy selection
      onProgress?.call('fetching');

      final cacheResult = await _checkCacheForUrl(input);
      if (cacheResult != null) {
        return cacheResult;
      }

      final youtubeStrategy = _youtubeStrategy;
      if (youtubeStrategy != null && youtubeStrategy.canHandle(input)) {
        // Phase: analyzing — about to parse via YouTube strategy
        onProgress?.call('analyzing');
        final result = await _parseWithStrategy(
          youtubeStrategy,
          input,
          options,
        );

        // Handle all YouTube results - don't fall back to WebScraper for YouTube URLs
        if (result.isSuccess || result.needsAssistance) {
          onProgress?.call('creating');
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
        onProgress?.call('analyzing');
        final result = await _parseWithStrategy(tiktokPipeline, input, options);
        if (result.isSuccess || result.needsAssistance) {
          onProgress?.call('creating');
          await _saveToCacheIfUrl(input, result);
          return result;
        }
        // TikTok pipeline failed, continue with other strategies
      }

      final instagramPipeline = _instagramPipeline;
      if (instagramPipeline != null && instagramPipeline.canHandle(input)) {
        onProgress?.call('analyzing');
        final result = await _parseWithStrategy(
          instagramPipeline,
          input,
          options,
        );
        if (result.isSuccess || result.needsAssistance) {
          onProgress?.call('creating');
          await _saveToCacheIfUrl(input, result);
          return result;
        }
      }

      if (preferredStrategy != null && preferredStrategy.canHandle(input)) {
        onProgress?.call('analyzing');
        final result = await _parseWithStrategy(
          preferredStrategy,
          input,
          options,
        );
        if (result.isSuccess) {
          onProgress?.call('creating');
          await _saveToCacheIfUrl(input, result);
          return result;
        }
        // Tier-7: an assisted-import result is a terminal outcome, not a
        // fallback-worthy miss — return it instead of trying other strategies.
        if (result.needsAssistance) {
          return result;
        }
      }

      for (final strategy in _strategies) {
        if (strategy.canHandle(input)) {
          onProgress?.call('analyzing');
          final result = await _parseWithStrategy(strategy, input, options);
          if (result.isSuccess) {
            onProgress?.call('creating');
            await _saveToCacheIfUrl(input, result);
            return result;
          }
          if (result.needsAssistance) {
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

  /// BUT-1460: single-image import for the handwritten opt-in (LLM-vision).
  ///
  /// Unlike [autoImport], this does NOT run the multi-strategy fallback loop.
  /// The handwritten flow is a single image processed by one strategy (photo /
  /// LLM-vision) whose result — success, assistance, OR failure — is TERMINAL:
  /// handwriting has no viable char-OCR fallback, so a failure here is the real
  /// answer, not a "try the next strategy" miss. [autoImport]'s loop only early-
  /// returns on `isSuccess`/`needsAssistance`, so a terminal photo FAILURE falls
  /// through to the generic "No import strategy could handle the provided input"
  /// message — discarding the strategy's real failure text and, critically, the
  /// structured rate-limit retry message (BUT-1144). This method returns the
  /// strategy's result directly so that message survives to the ViewModel.
  ///
  /// The rate-limit CHECK mirrors [autoImport] (same local `basic('auto')` check
  /// → structured `rateLimit(denied)` on denial). It does not record basic-bucket
  /// usage on success — the cost is metered on the LLM vision bucket, same as the
  /// normal multi-page photo path (`autoParseMulti`), so handwritten stays
  /// consistent with the rest of the photo feature.
  Future<ImportManagerResult> importSinglePhoto(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    try {
      final rateLimiter = _rateLimiter;
      if (rateLimiter != null) {
        final limitResult = await rateLimiter.checkLimit(
          ImportOperation.basic('auto'),
        );
        if (limitResult is RateLimitDenied) {
          return ImportManagerResult.rateLimit(limitResult);
        }
      }

      final strategy = _strategies.whereType<PhotoImportStrategy>().firstOrNull;
      if (strategy == null) {
        return ImportManagerResult.failure(
          'No photo import strategy is available',
          availableStrategies: _strategies.map((s) => s.strategyName).toList(),
        );
      }

      // Return the terminal result directly — no fallback loop to swallow it.
      return await _parseWithStrategy(strategy, input, options);
    } catch (e) {
      return ImportManagerResult.failure(
        'Import manager error: $e',
        availableStrategies: _strategies.map((s) => s.strategyName).toList(),
      );
    }
  }

  /// Voice-dictation entry point (voice plan, roadmap #2). [input] is the
  /// ASSEMBLED transcript text from voice_transcript_assembler.dart.
  ///
  /// Mirrors [importSinglePhoto]: rate-limit check up front (structured
  /// denial survives to the ViewModel), then straight to the voice
  /// strategy via [_parseWithStrategy] — the telemetry choke point — so
  /// dictated imports are rate-limited AND logged under source 'voice'
  /// (the direct TextImportStrategy call would silently skip both).
  Future<ImportManagerResult> importVoiceTranscript(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    try {
      final rateLimiter = _rateLimiter;
      if (rateLimiter != null) {
        final limitResult = await rateLimiter.checkLimit(
          ImportOperation.basic('auto'),
        );
        if (limitResult is RateLimitDenied) {
          return ImportManagerResult.rateLimit(limitResult);
        }
      }

      final strategy = _strategies.whereType<VoiceImportStrategy>().firstOrNull;
      if (strategy == null) {
        return ImportManagerResult.failure(
          'No voice import strategy is available',
          availableStrategies: _strategies.map((s) => s.strategyName).toList(),
        );
      }

      final result = await _parseWithStrategy(strategy, input, options);
      // Unlike photo (metered on its LLM-vision bucket), voice consumes no
      // metered downstream resource — the basic bucket IS its quota, so a
      // successful import must record usage or the checkLimit above is
      // inert (review finding #6: unlimited voice imports).
      if (result.isSuccess) {
        await _recordImportUsage('voice');
      }
      return result;
    } catch (e) {
      return ImportManagerResult.failure(
        'Import manager error: $e',
        availableStrategies: _strategies.map((s) => s.strategyName).toList(),
      );
    }
  }

  /// Record successful import usage for rate limiting.
  Future<void> _recordImportUsage(String sourceType) async {
    try {
      await _rateLimiter?.recordUsage(ImportOperation.basic(sourceType));
    } catch (e) {
      AppLogger.debug('ImportManager: Failed to record import usage: $e');
    }
  }

  /// Import using a specific strategy
  Future<ImportManagerResult> importWithStrategy(
    String strategyName,
    String input, {
    Map<String, dynamic>? options,
  }) async {
    final strategy = _strategies
        .where((s) => s.strategyName == strategyName)
        .firstOrNull;

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

  /// Circuit breaker: abort batch if >=8 of last 10 results fail.
  static const _circuitBreakerWindow = 10;
  static const _circuitBreakerThreshold = 8;

  Future<BatchImportResult> batchImport(
    List<String> inputs, {
    ImportStrategy? preferredStrategy,
    Map<String, dynamic>? options,
  }) async {
    final results = <ImportManagerResult>[];
    final recipes = <Recipe>[];
    final errors = <String>[];
    final recentFailures = <bool>[]; // true = failure
    var aborted = false;

    // HIGH-3: Process in parallel batches instead of sequentially
    for (var i = 0; i < inputs.length; i += _batchConcurrencyLimit) {
      if (aborted) break;

      final batchEnd = (i + _batchConcurrencyLimit).clamp(0, inputs.length);
      final batch = inputs.sublist(i, batchEnd);

      // Process this batch in parallel
      final batchResults = await Future.wait(
        batch.map(
          (input) => autoImport(
            input,
            preferredStrategy: preferredStrategy,
            options: options,
          ),
        ),
      );

      for (final result in batchResults) {
        results.add(result);

        final failed = !result.isSuccess || result.recipe == null;
        if (!failed) {
          recipes.add(result.recipe!);
        } else {
          errors.add(result.errorMessage ?? 'Unknown error');
        }

        // Rolling failure window for circuit breaker
        recentFailures.add(failed);
        if (recentFailures.length > _circuitBreakerWindow) {
          recentFailures.removeAt(0);
        }

        if (recentFailures.length >= _circuitBreakerWindow) {
          final failCount = recentFailures.where((f) => f).length;
          if (failCount >= _circuitBreakerThreshold) {
            AppLogger.warning(
              'Batch import circuit breaker: $failCount/$_circuitBreakerWindow '
              'recent failures, aborting remaining ${inputs.length - results.length} items',
            );
            errors.add('Avbruten: för många misslyckade importer');
            aborted = true;
            break;
          }
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

  /// Parse a blob that may contain SEVERAL recipes (a cookbook page) into N
  /// recipes — **parse-only**, no save, no per-block rate-limit charge.
  ///
  /// [MultiRecipeSplitter] segments the text; when it finds a single recipe it
  /// returns `[input]`, so this collapses to exactly the existing
  /// [autoParseOnly] behaviour (wrapped in a 1-element [BatchImportResult]).
  /// Callers that want a picker check `successfulRecipes.length > 1`.
  ///
  /// **The single-recipe path is no longer byte-unchanged, and that is
  /// deliberate.** This method now trims both ends of the input before
  /// splitting (`withoutFrameNoise`, which owns the ORDER: it takes the orphan
  /// trailing heading's decision and the leading furniture's decision from the
  /// UNTOUCHED document, then cuts once). So a page whose photo caught the
  /// next recipe's title loses that title, and a page whose photo caught a
  /// running header, a folio, or the previous recipe's tail loses that too.
  /// The splitter keeps its own contract — it still never hands back one
  /// shortened block; what it is handed can now be shorter. (It does drop
  /// furniture when it splits — bounded by the discard budget on the LAYOUT
  /// path only, and NOT bounded at all on the text path, where a block failing
  /// its tests vanishes at any size; that is a separate promise, stated on
  /// `split`.) Trimming happens HERE rather than inside `split` for two
  /// reasons: the splitter's guarantee is worth keeping, and the eval arms can
  /// only measure a trim if it sits outside `split`.
  /// A run without a [layout] is still byte-identical to before.
  Future<BatchImportResult> autoParseMulti(
    String input, {
    ImportStrategy? preferredStrategy,
    Map<String, dynamic>? options,
    DocumentLayout? layout,
  }) async {
    // [layout] is where the words sat on the page, when a reader measured
    // them. Only the photo path can supply it; the paste path never can, so it
    // stays optional and null reproduces today's behaviour exactly.
    //
    // Trim first, split second. A heading the frame cut off from its own
    // recipe is not this page's content, and removing it needs no split — so
    // it also reaches the pages where the splitter declines for want of a
    // second heading, which no change to the splitting rules could. How many
    // pages that is, and over which population, lives in `withoutOrphanTail`'s
    // own doc and is deliberately not restated here: it is two different
    // measurements over two different populations, and copying either one out
    // is how three drifting copies of a figure get made.
    //
    // ONE call, and that is the point: `withoutFrameNoise` takes BOTH trims'
    // decisions from the untouched document and only then cuts, and it returns
    // the originals untouched whenever neither rule can tell. Chaining the two
    // appliers here — which these lines used to do — let the tail cut move the
    // page's median type size under the leading trim and cost a real recipe
    // title; `frame_trim.dart` carries the executed case.
    final trimmed = withoutFrameNoise(input, layout);
    final blocks = MultiRecipeSplitter().split(
      trimmed.text,
      layout: trimmed.layout,
    );

    final results = <ImportManagerResult>[];
    final recipes = <Recipe>[];
    final errors = <String>[];

    for (final block in blocks) {
      final result = await autoParseOnly(
        block,
        preferredStrategy: preferredStrategy,
        options: options,
      );
      results.add(result);
      if (result.isSuccess && result.recipe != null) {
        recipes.add(result.recipe!);
      } else {
        errors.add(result.errorMessage ?? 'Unknown error');
      }
    }

    return BatchImportResult(
      results: results,
      successfulRecipes: recipes,
      errors: errors,
      totalProcessed: blocks.length,
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
        suggestions.add(
          ImportSuggestion(
            strategy: strategy,
            confidence: _calculateConfidence(strategy, input),
            description: strategy.description,
          ),
        );
      }
    }

    // Sort by confidence (highest first)
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));

    return suggestions;
  }

  /// Get text import strategy for direct usage
  TextImportStrategy getTextImportStrategy() {
    final textStrategy = _strategies
        .whereType<TextImportStrategy>()
        .firstOrNull;

    if (textStrategy == null) {
      throw StateError('TextImportStrategy not found in available strategies');
    }

    return textStrategy;
  }

  /// Save imported recipe using PersonalRecipeOperations.
  /// Tagging is handled by PersonalRecipeModule._applyTagging on save —
  /// no need to tag here (the result would be dropped by addUnifiedRecipe's
  /// parameter decomposition anyway).
  Future<ImportManagerResult> saveImportedRecipe(Recipe recipe) async {
    try {
      final saveResult = await _personalOperations.addUnifiedRecipe(recipe);

      if (saveResult.isSuccess) {
        return ImportManagerResult.success(
          recipe,
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
    final stopwatch = Stopwatch()..start();
    try {
      // Execute import strategy to parse recipe
      final importResult = await strategy.import(input, options: options);

      // BUT-1470: log a server-side parse event for every import path at this
      // shared choke point, so photo/text/social imports are measured the way
      // URL imports already are.
      _logParseEvent(strategy, importResult, stopwatch.elapsedMilliseconds);

      // Tier-7 recovery: a strategy can return `needsAssistance` (extracted
      // text the parser couldn't structure) instead of a recipe. This is NOT
      // a plain failure — it carries text + hints the user can finish manually.
      // Propagate it so URL/Text/Photo imports keep the assisted-import path
      // (previously this fell into the `!isSuccess` branch and was dropped).
      if (importResult.needsAssistance) {
        return ImportManagerResult.assistance(
          extractedText: importResult.extractedText,
          suggestedTitle: importResult.suggestedTitle,
          likelyIngredientLines: importResult.likelyIngredientLines,
          strategy: strategy.strategyName,
          metadata: importResult.metadata,
        );
      }

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

      // HIGH-1: Generate preview tags for immediate allergen/dietary display.
      // Preview tagging is an optional enhancement — it must NEVER fail an
      // already-parsed recipe. Wrap it in its own guard (mirrors
      // _retagCachedRecipe) so a tagging throw falls back to the untagged
      // recipe instead of discarding the parse and double-logging the parse
      // event (BUT-1470 telemetry) via the outer catch.
      var recipeWithPreview = importResult.recipe!;
      final taggingService = _taggingService;
      if (taggingService != null && recipeWithPreview.tagResult == null) {
        try {
          final previewTags = await taggingService.generatePhase1Preview(
            recipeWithPreview,
          );
          if (previewTags != null) {
            recipeWithPreview = Recipe(
              core: recipeWithPreview.core.copyWith(tagResult: previewTags),
              type: recipeWithPreview.type,
              socialData: recipeWithPreview.socialData,
              realtimeData: recipeWithPreview.realtimeData,
              offlineData: recipeWithPreview.offlineData,
            );
          }
        } catch (e) {
          AppLogger.warning('Preview tagging failed, saving untagged: $e');
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
      // BUT-1597: an exception thrown before a result is returned is still a
      // parse outcome — log it (success=false) so exception failures are
      // measured, not just the success/needsAssistance/failure return paths.
      // Mirrors _logParseEvent's UrlImportStrategy skip (it self-logs per-tier)
      // to avoid double-counting. Never throws: ParseEventLogger swallows errors.
      if (strategy is! UrlImportStrategy) {
        _eventLogger.logEvent(
          url: null,
          source: _sourceTypeFromStrategy(strategy.strategyName),
          success: false,
          parseTimeMs: stopwatch.elapsedMilliseconds,
        );
      }
      return ImportManagerResult.failure(
        'Parse execution error: $e',
        strategy: strategy.strategyName,
      );
    }
  }

  /// BUT-1470: emit a fire-and-forget parse event for a strategy outcome.
  ///
  /// [UrlImportStrategy] already logs its own per-tier parse events (and its
  /// enhanced-parser tier logs again via RecipeParserService), so it is skipped
  /// here to avoid double-counting the most common import path. Every other
  /// strategy (photo/OCR, text, archive, and the social pipelines) had no
  /// parse-event coverage before this — this is the single choke point that
  /// closes that gap. Never throws: ParseEventLogger swallows its own errors.
  void _logParseEvent(
    ImportStrategy strategy,
    ImportResult result,
    int parseTimeMs,
  ) {
    if (strategy is UrlImportStrategy) return;

    _eventLogger.logEvent(
      // The input for these paths is raw text / image bytes / a file id, not a
      // fetchable URL, so there is no meaningful `url` to record.
      url: null,
      source: _sourceTypeFromStrategy(strategy.strategyName),
      success: result.isSuccess && result.recipe != null,
      parseTimeMs: parseTimeMs,
    );
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

      // HIGH-2: Check if cached recipe needs retagging.
      // NOTE (2026-07-02): the retag result is deliberately NOT written back
      // to the shared cache entry — firestore.rules restricts cache updates
      // to access stats as a cache-poisoning defense (a client-writable
      // shared recipe would let one user's tags, incl. user-defined
      // ingredient overrides, become canonical for everyone). Per-hit
      // client-side retag is the accepted cost; see roadmap P1.
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

  /// Save successful import result to cache if input is a URL, and record usage.
  Future<void> _saveToCacheIfUrl(
    String input,
    ImportManagerResult result,
  ) async {
    final sourceType = _sourceTypeFromStrategy(result.strategy);
    await _recordImportUsage(sourceType);

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

      // BUT-1484: thread the pipeline's actually-computed tier + confidence
      // (carried in the strategy result metadata) into the cache entry instead
      // of hardcoding, so cross-user cache analytics reflect real extraction
      // quality. `tier` is the strategy's numeric tier (some paths emit a
      // non-int marker like 'multi'); confidence comes from the parser's
      // `overallQuality` score (0.0–1.0). Both fall back to the prior defaults
      // when a strategy doesn't emit them.
      final meta = result.metadata;
      final computedTier = meta?['tier'];
      final computedConfidence = meta?['overallQuality'];
      final extractionMeta = ExtractionMeta(
        pipeline: sourceType,
        tier: computedTier is int ? computedTier : 0,
        method: result.strategy ?? 'unknown',
        confidence: computedConfidence is num
            ? computedConfidence.toDouble()
            : 0.8,
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
    // Voice before text: dictated transcripts must never blend into the
    // pasted-text telemetry bucket (Data/Integrations panel condition).
    if (lower.contains('voice')) return 'voice';
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
