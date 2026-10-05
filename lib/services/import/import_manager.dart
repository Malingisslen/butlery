/// Import manager with strategy pattern for multi-format imports (text, archive, URL, file) and batch processing.
/// ```dart
/// final im = ImportManager(ops); await im.autoImport(text);

import 'dart:async';

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
import 'package:butlery/services/import/file_import_strategy.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/import/youtube/youtube_import_strategy.dart';
import 'package:butlery/services/import/pipelines/tiktok_pipeline.dart';
import 'package:butlery/services/import/pipelines/instagram_pipeline.dart';
import 'package:butlery/services/import/import_event.dart';
import 'package:butlery/services/import/import_manager_result.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
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
    _strategies.addAll([
      ArchiveImportStrategy(), // 1. Try archive first (fast, pre-validated)
      UrlImportStrategy(
        httpClient: ServiceLocator.tryGet<http.Client>(),
      ), // 2. Try URL import (web scraping)
      TextImportStrategy(), // 3. Try text parsing (fallback for plain text)
      PhotoImportStrategy(), // 4. Photo import (OCR extraction)
      // 5. Voice dictation — canHandle() always false (explicitly launched
      // from the voice wizard, never auto-selected).
      VoiceImportStrategy(),
      // 6. File — canHandle() always false (picker-driven, see importFile).
      FileImportStrategy(),
    ]);
  }

  /// Get all available import strategies
  List<ImportStrategy> get availableStrategies =>
      List.unmodifiable(_strategies);

  /// Of two strategy failures, keep the one that knows its cause: the first
  /// failure carrying an [ImportErrorCode] wins over any without one, and
  /// [ImportErrorCode.unknown] counts as not knowing.
  static ImportManagerResult _keepBetterFailure(
    ImportManagerResult? kept,
    ImportManagerResult next,
  ) => kept == null || (!_knowsCause(kept) && _knowsCause(next)) ? next : kept;

  static bool _knowsCause(ImportManagerResult r) =>
      r.errorCode != null && r.errorCode != ImportErrorCode.unknown;

  /// The answer when no strategy produced a recipe: the kept strategy
  /// failure with its message, code and metadata, or the generic line when
  /// no strategy even tried.
  ImportManagerResult _noRecipeResult(ImportManagerResult? failure) {
    final strategies = _strategies.map((s) => s.strategyName).toList();
    if (failure == null) {
      return ImportManagerResult.failure(
        'No import strategy could handle the provided input',
        availableStrategies: strategies,
      );
    }
    return ImportManagerResult.failure(
      failure.errorMessage ?? 'Parse failed',
      strategy: failure.strategy,
      warnings: failure.warnings,
      metadata: failure.metadata,
      errorCode: failure.errorCode,
      availableStrategies: strategies,
    );
  }

  /// Auto-detects strategy and parses recipe WITHOUT saving (for preview/validation).
  Future<ImportManagerResult> _autoParseOnly(
    String input, {
    ImportStrategy? preferredStrategy,
    Map<String, dynamic>? options,
  }) async {
    try {
      ImportManagerResult? failure;
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
        failure = _keepBetterFailure(failure, result);
      }

      // Try all compatible strategies
      for (final strategy in _strategies) {
        if (strategy.canHandle(input)) {
          final result = await _parseWithStrategy(strategy, input, options);
          if (result.isSuccess) {
            return result;
          }
          failure = _keepBetterFailure(failure, result);
        }
      }

      return _noRecipeResult(failure);
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
  }) => _measured(
    _looksLikeLink(input) ? ImportChannel.link : ImportChannel.text,
    input,
    () => _autoImport(
      input,
      preferredStrategy: preferredStrategy,
      options: options,
      onProgress: onProgress,
    ),
  );

  Future<ImportManagerResult> _autoImport(
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

      // Phase: fetching — strategy selection
      onProgress?.call('fetching');

      ImportManagerResult? failure;
      // An import asks the model at most once (BUT-2239): once a platform
      // strategy has made a call, later strategies run without AI and the
      // call's cost rides on whatever result the import ends with.
      var spent = const <String, dynamic>{};
      void noteCall(ImportManagerResult result) {
        if (result.metadata?['usedLlm'] != true) return;
        spent = {'usedLlm': true, 'llmCost': ?result.metadata?['llmCost']};
        options = {...?options, 'skipLlm': true};
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
        noteCall(result);
        failure = _keepBetterFailure(failure, result);
      }

      final tiktokPipeline = _tiktokPipeline;
      if (tiktokPipeline != null && tiktokPipeline.canHandle(input)) {
        onProgress?.call('analyzing');
        final result = await _parseWithStrategy(tiktokPipeline, input, options);
        if (result.isSuccess || result.needsAssistance) {
          onProgress?.call('creating');
          return result;
        }
        // TikTok pipeline failed, continue with other strategies
        noteCall(result);
        failure = _keepBetterFailure(failure, result);
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
          return result;
        }
        noteCall(result);
        failure = _keepBetterFailure(failure, result);
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
          return result.withLlmUse(spent);
        }
        // Tier-7: an assisted-import result is a terminal outcome, not a
        // fallback-worthy miss — return it instead of trying other strategies.
        if (result.needsAssistance) {
          return result.withLlmUse(spent);
        }
        failure = _keepBetterFailure(failure, result);
      }

      for (final strategy in _strategies) {
        if (strategy.canHandle(input)) {
          onProgress?.call('analyzing');
          final result = await _parseWithStrategy(strategy, input, options);
          if (result.isSuccess) {
            onProgress?.call('creating');
            return result.withLlmUse(spent);
          }
          if (result.needsAssistance) {
            return result.withLlmUse(spent);
          }
          failure = _keepBetterFailure(failure, result);
        }
      }

      return _noRecipeResult(failure).withLlmUse(spent);
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
  /// → structured `rateLimit(denied)` on denial).
  Future<ImportManagerResult> importSinglePhoto(
    String input, {
    Map<String, dynamic>? options,
  }) => _measured(
    ImportChannel.photo,
    input,
    () => _importSinglePhoto(input, options: options),
  );

  Future<ImportManagerResult> _importSinglePhoto(
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
  /// strategy via [_parseWithStrategy].
  Future<ImportManagerResult> importVoiceTranscript(
    String input, {
    Map<String, dynamic>? options,
  }) => _measured(
    ImportChannel.voice,
    input,
    () => _importVoiceTranscript(input, options: options),
  );

  Future<ImportManagerResult> _importVoiceTranscript(
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

      return await _parseWithStrategy(strategy, input, options);
    } catch (e) {
      return ImportManagerResult.failure(
        'Import manager error: $e',
        availableStrategies: _strategies.map((s) => s.strategyName).toList(),
      );
    }
  }

  /// Runs one import and then measures it (BUT-2238): exactly one parse
  /// event, and one use of the import quota whatever the outcome. A request
  /// the rate limiter refused is neither measured nor counted.
  Future<ImportManagerResult> _measured(
    ImportChannel channel,
    String input,
    Future<ImportManagerResult> Function() run,
  ) async {
    final stopwatch = Stopwatch()..start();
    final result = await run();
    await _finishImport(channel, input, result, stopwatch.elapsed);
    return result;
  }

  Future<void> _finishImport(
    ImportChannel channel,
    String input,
    ImportManagerResult result,
    Duration elapsed,
  ) async {
    if (result.rateLimitDenied != null) return;
    _record(
      ImportEvent.fromResult(
        result,
        channel: channel,
        input: input,
        elapsed: elapsed,
      ),
    );
  }

  void _record(ImportEvent event) {
    _eventLogger.log(event);
    // Not awaited: the quota write retries on a transient error, and an
    // offline failure must reach the user without waiting for it.
    unawaited(_recordUsage(event.channel));
    unawaited(_trackImport(event));
  }

  Future<void> _trackImport(ImportEvent event) async {
    final analytics = ServiceLocator.tryGet<AnalyticsService>();
    if (analytics == null) return;
    try {
      final source = event.channel.name;
      await analytics.logImportStarted(source: source);
      if (event.success) await analytics.logImportSuccess(source: source);
    } catch (e) {
      AppLogger.debug('ImportManager: Failed to log import analytics: $e');
    }
  }

  /// File entry point (BUT-2240): every recipe in one picked CSV, Excel or
  /// Paprika file, for the batch preview. A cancelled picker is not an
  /// import, so it is neither limited nor measured.
  Future<FileImportResult> importFile() async {
    final strategy = _strategies.whereType<FileImportStrategy>().firstOrNull;
    final file = await strategy?.pickFile();
    if (strategy == null || file == null) {
      return const FileImportResult.cancelled();
    }

    final limitResult = await _rateLimiter?.checkLimit(
      ImportOperation.basic('auto'),
    );
    if (limitResult is RateLimitDenied) {
      return FileImportResult.rateLimit(limitResult);
    }

    final stopwatch = Stopwatch()..start();
    final recipes = await strategy.importPicked(file);
    _record(
      ImportEvent(
        channel: ImportChannel.file,
        strategy: ImportEvent.strategyId(strategy.strategyName),
        outcome: recipes.isEmpty ? 'failure' : 'recipe',
        parseTimeMs: stopwatch.elapsedMilliseconds,
        errorCode: recipes.isEmpty ? ImportErrorCode.parsingFailed.name : null,
      ),
    );
    return FileImportResult(recipes);
  }

  Future<void> _recordUsage(ImportChannel channel) async {
    try {
      await _rateLimiter?.recordUsage(ImportOperation.basic(channel.name));
    } catch (e) {
      AppLogger.debug('ImportManager: Failed to record import usage: $e');
    }
  }

  // Domain-like input without a scheme, e.g. "ica.se/recept/...".
  static final _domainPattern = RegExp(
    r'^[\w\-]+\.[\w\-]+(?:\.[\w\-]+)*(?:/.*)?$',
    caseSensitive: false,
  );

  bool _looksLikeLink(String input) {
    final trimmed = input.trim().toLowerCase();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return true;
    }
    return _domainPattern.hasMatch(trimmed);
  }

  ImportChannel _channelForStrategy(String strategyName, String input) =>
      switch (ImportEvent.strategyId(strategyName)) {
        'photo' => ImportChannel.photo,
        'voice' => ImportChannel.voice,
        _ => _looksLikeLink(input) ? ImportChannel.link : ImportChannel.text,
      };

  /// Import using a specific strategy
  Future<ImportManagerResult> importWithStrategy(
    String strategyName,
    String input, {
    Map<String, dynamic>? options,
  }) => _measured(
    _channelForStrategy(strategyName, input),
    input,
    () => _importWithStrategy(strategyName, input, options: options),
  );

  Future<ImportManagerResult> _importWithStrategy(
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
  /// [_autoParseOnly] behaviour (wrapped in a 1-element [BatchImportResult]).
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
  ///
  /// [channel] null means this parse belongs to an import that was already
  /// measured — a page added, removed or reordered, a restored draft, the
  /// text behind a handwritten photo — so it writes no event and uses no quota.
  Future<BatchImportResult> autoParseMulti(
    String input, {
    ImportStrategy? preferredStrategy,
    Map<String, dynamic>? options,
    DocumentLayout? layout,
    ImportChannel? channel = ImportChannel.text,
  }) async {
    final stopwatch = Stopwatch()..start();
    final batch = await _autoParseMulti(
      input,
      preferredStrategy: preferredStrategy,
      options: options,
      layout: layout,
    );
    if (channel == null) return batch;
    // One page is one import, however many recipes it held: the event
    // describes the first recipe found, or the failure that knew its cause.
    final answer =
        batch.results
            .where((r) => r.isSuccess && r.recipe != null)
            .firstOrNull ??
        _noRecipeResult(
          batch.results.fold<ImportManagerResult?>(
            null,
            (kept, r) => _keepBetterFailure(kept, r),
          ),
        );
    await _finishImport(channel, input, answer, stopwatch.elapsed);
    return batch;
  }

  Future<BatchImportResult> _autoParseMulti(
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
      final result = await _autoParseOnly(
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
        return ImportManagerResult.success(recipe, strategy: 'direct_save');
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
          metadata: importResult.metadata,
          errorCode: importResult.errorCode,
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
      // already-parsed recipe. Wrap it in its own guard so a tagging throw
      // falls back to the untagged recipe instead of discarding the parse.
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
}
