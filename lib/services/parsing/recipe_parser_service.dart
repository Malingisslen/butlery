import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/circuit_breaker.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:butlery/repositories/site_config_repository.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/parsing/cache/local_recipe_cache.dart';
import 'package:butlery/services/parsing/common/recipe_merger.dart';
import 'package:butlery/services/parsing/ingredient_conversion.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/parsing/line_classifier/neural_line_classifier.dart';
import 'package:butlery/services/parsing/tiers/llm_tier.dart';
import 'package:butlery/services/parsing/tiers/parsing_context.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';
import 'package:butlery/services/parsing/tiers/rule_based_tier.dart';
import 'package:butlery/services/parsing/tiers/schema_org_tier.dart';
import 'package:butlery/services/parsing/tiers/site_config_tier.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Parser version for cache invalidation.
const String parserVersion = '2.0.0';

/// Quality threshold for accepting a tier result without continuing.
const double defaultQualityThreshold = 0.65;

/// Extra threshold for reliable domains to avoid unnecessary LLM calls.
const double _reliableDomainBoost = 0.15;

/// Cap so even boosted thresholds don't reject genuinely good parses.
const double _maxEffectiveThreshold = 0.95;

/// Per-tier quality discount: structured tiers get a lower bar since their
/// data is inherently more trustworthy (JSON-LD, CSS selectors) than
/// heuristic extraction. A 0.55 SchemaOrg result (e.g. missing time) is
/// still better than triggering an expensive LLM call.
const Map<String, double> _tierQualityDiscount = {
  SchemaOrgTier.tierIdentifier: 0.10, // JSON-LD is highly structured
  SiteConfigTier.tierIdentifier: 0.05, // CSS selectors are semi-structured
};

/// Result of parsing operation.
class ParseResult {
  /// The parsed recipe, if successful.
  final ParsedRecipe? recipe;

  /// Whether parsing succeeded.
  final bool success;

  /// Error message if failed.
  final String? error;

  /// User-facing Swedish error message (from most actionable tier failure).
  final String? userMessage;

  /// Whether the result came from cache.
  final bool fromCache;

  /// Total parsing time.
  final Duration totalTime;

  const ParseResult({
    this.recipe,
    required this.success,
    this.error,
    this.userMessage,
    this.fromCache = false,
    required this.totalTime,
  });

  factory ParseResult.success(
    ParsedRecipe recipe, {
    bool fromCache = false,
    required Duration totalTime,
  }) =>
      ParseResult(
        recipe: recipe,
        success: true,
        fromCache: fromCache,
        totalTime: totalTime,
      );

  factory ParseResult.failure(
    String error, {
    required Duration totalTime,
    String? userMessage,
  }) =>
      ParseResult(
        success: false,
        error: error,
        userMessage: userMessage,
        totalTime: totalTime,
      );
}

/// Main recipe parsing service with tier-based architecture.
///
/// Orchestrates parsing through 4 tiers:
/// 1. SchemaOrgTier - JSON-LD structured data
/// 2. SiteConfigTier - Firestore CSS selectors
/// 3. RuleBasedTier - Swedish line classification + CRF ingredient parsing
/// 4. LlmTier - AI extraction (fallback)
///
/// All tiers share a single [IngredientParsingStrategy] that tries CRF
/// (on-device model) first, falling back to regex when weights unavailable.
///
/// Features:
/// - Quality-based tier progression
/// - Smart result merging
/// - Local caching with P0-1 content-hash protection
/// - P1-3 circuit breaker for reliability
class RecipeParserService extends BaseService {
  @override
  String get serviceName => 'RecipeParserService';

  static const _selectiveEnhanceTierName = 'SelectiveEnhance';

  final SiteConfigRepository? _siteConfigRepository;
  final LlmService? _llmService;
  final NeuralLineClassifier? _neuralLineClassifier;
  final String Function() _getCurrentUserId;

  /// Current user ID, resolved at call time to handle login/logout.
  String get _userId => _getCurrentUserId();

  /// Local cache for parsed recipes (lazily initialized).
  LocalRecipeCache? _cacheField;

  /// Get the cache (must be initialized first via init())
  LocalRecipeCache get _cache {
    if (_cacheField == null) {
      throw StateError(
          'RecipeParserService not initialized - call init() first');
    }
    return _cacheField!;
  }

  /// Recipe merger for combining tier results.
  final RecipeMerger _merger = RecipeMerger();

  /// Circuit breaker for cache operations (P1-3).
  final CircuitBreaker _cacheCircuitBreaker = CircuitBreaker(
    failureThreshold: 3,
    resetTime: const Duration(minutes: 2),
  );

  /// Firebase Functions for server-side analytics.
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Parsing tiers in execution order.
  late final List<ParsingTier> _tiers;

  /// Shared ingredient parsing strategy (OCR mode toggled per-request).
  late final IngredientParsingStrategy _ingredientStrategy;

  RecipeParserService({
    required String Function() getCurrentUserId,
    SiteConfigRepository? siteConfigRepository,
    LlmService? llmService,
    IngredientParsingStrategy? ingredientStrategy,
    NeuralLineClassifier? neuralLineClassifier,
  })  : _getCurrentUserId = getCurrentUserId,
        _siteConfigRepository = siteConfigRepository,
        _llmService = llmService,
        _neuralLineClassifier = neuralLineClassifier {
    // Shared strategy: CRF when weights available, regex fallback
    final strategy = ingredientStrategy ?? IngredientParsingStrategy();
    _ingredientStrategy = strategy;

    _tiers = [
      SchemaOrgTier(ingredientStrategy: strategy),
      SiteConfigTier(
        configLoader: _siteConfigRepository?.getConfigIfExists,
        ingredientStrategy: strategy,
      ),
      RuleBasedTier(
        ingredientStrategy: strategy,
        neuralClassifier: neuralLineClassifier,
      ),
      LlmTier(llmService: _llmService),
    ];
  }

  /// Initialize the parser service.
  Future<void> init() async {
    // Create cache with CacheDao from OfflineService
    final offlineService = ServiceLocator.get<OfflineService>();
    _cacheField = LocalRecipeCache(
      getCurrentUserId: _getCurrentUserId,
      parserVersion: parserVersion,
      cacheDao: offlineService.database.cacheDao,
    );
    await _cache.init();

    // Seed site configs if empty (one-time, non-blocking)
    final repo = _siteConfigRepository;
    if (repo != null) {
      // Fire and forget - don't block initialization
      repo.seedConfigsIfEmpty();
    }

    // Initialize neural line classifier in background (fire-and-forget)
    final neuralClassifier = _neuralLineClassifier;
    if (neuralClassifier != null) {
      Future(() async {
        try {
          final ready = await neuralClassifier.ensureInitialized();
          if (ready) {
            AppLogger.info('$serviceName: Neural line classifier ready');
          }
        } catch (e) {
          AppLogger.debug('$serviceName: Neural classifier init failed: $e');
        }
      });
    }

    AppLogger.info('$serviceName: Initialized with ${_tiers.length} tiers');
  }

  /// Parse a recipe from URL content.
  Future<ParseResult> parseFromUrl({
    required String url,
    required String htmlContent,
    double qualityThreshold = defaultQualityThreshold,
    bool useCache = true,
    bool useLlm = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Create parsing context
    final context = ParsingContext.fromUrl(
      url: url,
      htmlContent: htmlContent,
      userId: _userId,
      parserVersion: parserVersion,
    );

    // Check security
    if (!context.isSecure) {
      AppLogger.warning('$serviceName: Content failed security check');
      return ParseResult.failure(
        'Content failed security validation',
        totalTime: stopwatch.elapsed,
      );
    }

    // Check cache
    if (useCache) {
      final cached = await _checkCache(context);
      if (cached != null) {
        _logParseEvent(
          url: url,
          source: context.source.name,
          success: true,
          fromCache: true,
          parseTimeMs: stopwatch.elapsedMilliseconds,
          domain: context.domain,
        );
        return ParseResult.success(
          cached,
          fromCache: true,
          totalTime: stopwatch.elapsed,
        );
      }
    }

    // Reliable domains get a higher bar so cheap tiers work harder before
    // falling back to LLM (e.g. 0.7 base → 0.85 effective)
    var effectiveThreshold = qualityThreshold;
    var isUnknownDomain = false;
    if (_siteConfigRepository != null && context.domain != null) {
      final config =
          await _siteConfigRepository.getConfigIfExists(context.domain!);
      if (config != null && config.isReliable) {
        effectiveThreshold = (qualityThreshold + _reliableDomainBoost)
            .clamp(0.0, _maxEffectiveThreshold);
      } else if (config == null && context.source == ImportSource.url) {
        // Track domains without site configs to prioritize adding them
        isUnknownDomain = true;
      }
    }

    // Run parsing tiers
    final tierData = await _runTiers(
      context,
      qualityThreshold: effectiveThreshold,
      useLlm: useLlm,
    );
    final result = tierData.recipe;

    if (result == null) {
      _logParseEvent(
        url: url,
        source: context.source.name,
        success: false,
        fromCache: false,
        parseTimeMs: stopwatch.elapsedMilliseconds,
        domain: context.domain,
        tierResults: tierData.tierResults,
        unknownDomain: isUnknownDomain,
      );
      return ParseResult.failure(
        'Could not extract recipe from content',
        totalTime: stopwatch.elapsed,
        userMessage: _pickUserMessage(),
      );
    }

    // Cache result
    if (useCache) {
      await _cacheResult(context, result);
    }

    // Report success/failure to site config
    final repo = _siteConfigRepository;
    final domain = context.domain;
    if (repo != null && domain != null) {
      if (result.overallQuality >= qualityThreshold) {
        await repo.reportSuccess(domain);
      } else {
        await repo.reportFailure(domain);
      }
    }

    final successfulTier =
        tierData.tierResults.where((t) => t.success).lastOrNull;
    _logParseEvent(
      url: url,
      source: context.source.name,
      success: true,
      fromCache: false,
      parseTimeMs: stopwatch.elapsedMilliseconds,
      domain: context.domain,
      successfulTier: successfulTier?.tierName,
      finalQuality: result.overallQuality,
      usedLlm: tierData.tierResults.any(
        (t) => t.tierName == 'LLM' && t.success,
      ),
      totalCostSek: tierData.tierResults.fold<double>(
        0,
        (sum, t) => sum + (t.costSek ?? 0),
      ),
      tierResults: tierData.tierResults,
      unknownDomain: isUnknownDomain,
    );
    return ParseResult.success(result, totalTime: stopwatch.elapsed);
  }

  /// Parse a recipe from plain text.
  Future<ParseResult> parseFromText({
    required String text,
    ImportSource source = ImportSource.text,
    double qualityThreshold = defaultQualityThreshold,
    bool useLlm = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    final context = ParsingContext.fromText(
      text: text,
      source: source,
      userId: _userId,
      parserVersion: parserVersion,
    );

    final tierData = await _runTiers(
      context,
      qualityThreshold: qualityThreshold,
      useLlm: useLlm,
    );
    final result = tierData.recipe;

    if (result == null) {
      _logParseEvent(
        url: null,
        source: source.name,
        success: false,
        fromCache: false,
        parseTimeMs: stopwatch.elapsedMilliseconds,
        tierResults: tierData.tierResults,
      );
      return ParseResult.failure(
        'Could not extract recipe from text',
        totalTime: stopwatch.elapsed,
        userMessage: _pickUserMessage(),
      );
    }

    final successfulTier =
        tierData.tierResults.where((t) => t.success).lastOrNull;
    _logParseEvent(
      url: null,
      source: source.name,
      success: true,
      fromCache: false,
      parseTimeMs: stopwatch.elapsedMilliseconds,
      successfulTier: successfulTier?.tierName,
      finalQuality: result.overallQuality,
      usedLlm: tierData.tierResults.any(
        (t) => t.tierName == 'LLM' && t.success,
      ),
      totalCostSek: tierData.tierResults.fold<double>(
        0,
        (sum, t) => sum + (t.costSek ?? 0),
      ),
      tierResults: tierData.tierResults,
    );
    return ParseResult.success(result, totalTime: stopwatch.elapsed);
  }

  /// Whether a tier should be skipped for the given context.
  bool _shouldSkipTier(ParsingTier tier, ParsingContext context, bool useLlm) {
    if (tier is LlmTier && !useLlm) return true;
    if (context.source != ImportSource.url) {
      if (tier is SchemaOrgTier || tier is SiteConfigTier) {
        return true;
      }
    }
    return tier.shouldSkip(context);
  }

  /// Most recent tier failures, used for user-facing error messages.
  List<TierResult> _lastTierFailures = [];

  /// Run parsing tiers in order until quality threshold is met.
  ///
  /// Returns both the merged recipe and the raw tier results so callers
  /// can extract metrics (successfulTier, quality, cost) for analytics.
  Future<({ParsedRecipe? recipe, List<TierResult> tierResults})> _runTiers(
    ParsingContext context, {
    required double qualityThreshold,
    required bool useLlm,
  }) async {
    final results = <TierResult>[];
    _lastTierFailures = [];

    for (final tier in _tiers) {
      if (_shouldSkipTier(tier, context, useLlm)) continue;

      if (!context.shouldContinueParsing(qualityThreshold: qualityThreshold)) {
        AppLogger.debug(
          '$serviceName: Stopping at ${tier.tierName} - quality threshold met',
        );
        break;
      }

      // Before LLM tier: try lightweight ingredient-line routing first,
      // then fall back to full recipe enhancement if needed.
      if (tier is LlmTier) {
        final patched = await _trySelectiveIngredientEnhancement(
          results,
          context,
          qualityThreshold: qualityThreshold,
        );
        if (patched) break;
        _preparePartialForEnhancement(results, context);
      }

      final result = await tier.parseWithTimeout(context);
      results.add(result);

      if (!result.success && result.failureReason != null) {
        _lastTierFailures.add(result);
      }

      AppLogger.debug(
        '$serviceName: ${tier.tierName} - '
        '${result.success ? "success (${(result.quality * 100).toInt()}%)" : "failed"}',
      );

      if (result.success) {
        final discount = _tierQualityDiscount[tier.tierName] ?? 0.0;
        if (result.quality >= (qualityThreshold - discount)) {
          break;
        }
      }
    }

    return (recipe: _merger.merge(results), tierResults: results);
  }

  /// Find the highest-quality successful result from a list of tier results.
  TierResult? _bestSuccessfulResult(List<TierResult> results) {
    return results
        .where((r) => r.success && r.recipe != null)
        .fold<TierResult?>(null, (best, r) {
      if (best == null || r.quality > best.quality) return r;
      return best;
    });
  }

  /// Extract good fields from the best partial result and set them on the
  /// context so the LLM tier can use enhance mode instead of full extraction.
  void _preparePartialForEnhancement(
    List<TierResult> results,
    ParsingContext context,
  ) {
    final bestResult = _bestSuccessfulResult(results);

    if (bestResult == null) return;

    final recipe = bestResult.recipe!;
    final weakFields = recipe.fieldsNeedingImprovement;

    // Only use enhance mode when 1-2 fields are weak (selective patching)
    if (weakFields.isEmpty || weakFields.length > 2) return;

    final goodFields = <String, dynamic>{};

    if (recipe.title.hasValue && !weakFields.contains('title')) {
      goodFields['title'] = recipe.title.value;
    }
    if (recipe.portions.hasValue && !weakFields.contains('portions')) {
      goodFields['portions'] = recipe.portions.value;
    }
    if (recipe.ingredients.hasValue && !weakFields.contains('ingredients')) {
      goodFields['ingredients'] =
          recipe.ingredients.value!.map((i) => i.originalLine).toList();
    }
    if (recipe.instructions.hasValue && !weakFields.contains('instructions')) {
      goodFields['instructions'] = recipe.instructions.value;
    }
    if (recipe.totalTime.hasValue && !weakFields.contains('totalTime')) {
      goodFields['totalTime'] = recipe.totalTime.value!.inMinutes;
    }

    context.bestPartialRecipe = ParsedRecipePartial(
      goodFields: goodFields,
      weakFields: weakFields,
    );

    AppLogger.info(
      '$serviceName: LLM will enhance ${weakFields.length} weak field(s): '
      '${weakFields.join(", ")} (${goodFields.length} fields already good)',
    );
  }

  /// Try selective ingredient-line enhancement before full LLM extraction.
  ///
  /// If earlier tiers produced a recipe where only some ingredient lines
  /// have low confidence, sends just those lines to the LLM for re-parsing
  /// (~500 tokens) instead of the entire recipe (~3000 tokens).
  ///
  /// Returns true if quality now passes the threshold (LlmTier can be skipped).
  Future<bool> _trySelectiveIngredientEnhancement(
    List<TierResult> results,
    ParsingContext context, {
    required double qualityThreshold,
  }) async {
    if (_llmService == null) return false;

    // Find best result with ingredients from earlier tiers
    final bestResult = _bestSuccessfulResult(results);

    if (bestResult == null) return false;
    final recipe = bestResult.recipe!;
    if (!recipe.ingredients.hasValue) return false;

    final parsed = recipe.ingredients.value!;
    final originalLines = parsed.map((p) => p.originalLine).toList();

    // Get uncertain lines (CRF → BERT NER → remaining for LLM)
    final uncertainLines =
        await _ingredientStrategy.getUncertainLines(parsed, originalLines);

    if (uncertainLines.isEmpty) return false;

    // Skip if majority of lines are uncertain — full LLM is better
    if (uncertainLines.length > parsed.length / 2) {
      AppLogger.debug(
        '$serviceName: ${uncertainLines.length}/${parsed.length} lines uncertain '
        '— skipping selective enhancement, using full LLM',
      );
      return false;
    }

    AppLogger.info(
      '$serviceName: Selective ingredient enhancement — '
      '${uncertainLines.length}/${parsed.length} lines to re-parse',
    );

    try {
      final stopwatch = Stopwatch()..start();
      final response = await _llmService.parseIngredientLines(
        lines: uncertainLines.values.toList(),
      );

      if (!response.success ||
          response.recipe == null ||
          response.recipe!.ingredients.isEmpty) {
        AppLogger.debug(
          '$serviceName: Selective enhancement failed — falling through to LLM',
        );
        return false;
      }

      final llmIngredients = response.recipe!.ingredients;

      // Splice LLM results back into the CRF result at original indices
      final patchedList = List<ParsedIngredient>.from(parsed);
      final uncertainIndices = uncertainLines.keys.toList();

      for (var i = 0;
          i < uncertainIndices.length && i < llmIngredients.length;
          i++) {
        final idx = uncertainIndices[i];
        final llmIng = llmIngredients[i];
        patchedList[idx] = parsedIngredientFromExtracted(
          llmIng,
          originalLine: originalLines[idx],
        );
      }

      // Recalculate ingredient confidence
      final avgConfidence = patchedList.fold<double>(
            0.0,
            (sum, p) => sum + p.confidence.score,
          ) /
          patchedList.length;

      final newIngredients = FieldResult.fromConfidenceScore(
        patchedList,
        avgConfidence,
        'Selective LLM enhancement',
      );

      // Rebuild recipe with patched ingredients
      final patchedRecipe = ParsedRecipe(
        title: recipe.title,
        portions: recipe.portions,
        ingredients: newIngredients,
        instructions: recipe.instructions,
        totalTime: recipe.totalTime,
        metadata: recipe.metadata,
        imageUrl: recipe.imageUrl,
        description: recipe.description,
      );

      final newQuality = patchedRecipe.overallQuality;
      final discount = _tierQualityDiscount[bestResult.tierName] ?? 0.0;

      AppLogger.info(
        '$serviceName: Selective enhancement result — '
        'quality ${(bestResult.quality * 100).toInt()}% → ${(newQuality * 100).toInt()}% '
        '(threshold: ${((qualityThreshold - discount) * 100).toInt()}%)',
      );

      if (newQuality >= (qualityThreshold - discount)) {
        results.add(TierResult.success(
          tierName: _selectiveEnhanceTierName,
          recipe: patchedRecipe,
          duration: stopwatch.elapsed,
          costSek: response.estimatedCost,
        ));
        return true;
      }

      return false;
    } on LlmException catch (e) {
      AppLogger.debug(
        '$serviceName: Selective enhancement LLM error: ${e.message}',
      );
      return false;
    } catch (e) {
      AppLogger.debug(
        '$serviceName: Selective enhancement error: $e',
      );
      return false;
    }
  }

  /// Pick the most actionable user message from accumulated tier failures.
  /// Priority: rateLimited > securityBlocked > invalidResponse > schemaValidationFailed > others.
  String? _pickUserMessage() {
    if (_lastTierFailures.isEmpty) return null;

    const priority = [
      TierFailureReason.rateLimited,
      TierFailureReason.securityBlocked,
      TierFailureReason.invalidResponse,
      TierFailureReason.schemaValidationFailed,
      TierFailureReason.networkError,
      TierFailureReason.timeout,
      TierFailureReason.parseError,
      TierFailureReason.noData,
    ];

    for (final reason in priority) {
      final match =
          _lastTierFailures.where((r) => r.failureReason == reason).firstOrNull;
      if (match != null) {
        return reason.userMessage;
      }
    }

    return _lastTierFailures.last.failureReason?.userMessage;
  }

  /// Check local cache for parsed recipe.
  Future<ParsedRecipe?> _checkCache(ParsingContext context) async {
    if (_cacheCircuitBreaker.isOpen) {
      return null;
    }

    try {
      return await _cacheCircuitBreaker.execute(() async {
        return _cache.get(
          urlHash: context.urlHash,
          contentHash: context.contentHash,
          source: context.source,
        );
      });
    } on CircuitBreakerOpenException {
      AppLogger.debug('$serviceName: Cache circuit breaker open');
      return null;
    } catch (e) {
      AppLogger.warning('$serviceName: Cache check failed: $e');
      return null;
    }
  }

  /// Cache a parsed recipe.
  Future<void> _cacheResult(ParsingContext context, ParsedRecipe recipe) async {
    if (_cacheCircuitBreaker.isOpen) {
      return;
    }

    try {
      await _cacheCircuitBreaker.execute(() async {
        await _cache.set(
          urlHash: context.urlHash,
          contentHash: context.contentHash,
          source: context.source,
          recipe: recipe,
        );
      });
    } on CircuitBreakerOpenException {
      AppLogger.debug('$serviceName: Cache circuit breaker open');
    } catch (e) {
      AppLogger.warning('$serviceName: Cache set failed: $e');
    }
  }

  /// Get cache statistics.
  Future<Map<String, dynamic>> getCacheStats() => _cache.getStats();

  /// Clear the local parse cache.
  Future<void> clearParseCache() => _cache.clear();

  /// Close the service.
  Future<void> close() async {
    await _cache.close();
    AppLogger.info('$serviceName: Closed');
  }

  /// Log parse event to server for analytics (fire-and-forget).
  ///
  /// This method sends parse statistics to the server but doesn't
  /// block or fail the parsing operation. Errors are silently ignored.
  void _logParseEvent({
    required String? url,
    required String source,
    required bool success,
    required bool fromCache,
    required int parseTimeMs,
    String? domain,
    String? successfulTier,
    double? finalQuality,
    bool? usedLlm,
    double? totalCostSek,
    List<TierResult>? tierResults,
    bool unknownDomain = false,
  }) {
    // Fire and forget - don't await, don't fail on error
    _functions.httpsCallable('logParseEvent').call<Map<String, dynamic>>({
      'url': url,
      'source': source,
      'success': success,
      'fromCache': fromCache,
      'parseTimeMs': parseTimeMs,
      'parserVersion': parserVersion,
      if (domain != null) 'domain': domain,
      if (successfulTier != null) 'successfulTier': successfulTier,
      if (finalQuality != null) 'finalQuality': finalQuality,
      if (usedLlm != null) 'usedLlm': usedLlm,
      if (totalCostSek != null) 'totalCostSek': totalCostSek,
      if (tierResults != null)
        'tierAttempts': tierResults
            .map((t) => {
                  'tier': t.tierName,
                  'success': t.success,
                  'quality': t.quality,
                  'durationMs': t.duration.inMilliseconds,
                })
            .toList(),
      if (unknownDomain) 'unknownDomain': true,
    }).then((_) {
      // Success - do nothing
    }).catchError((e) {
      // Silently ignore analytics errors - don't disrupt parsing
      AppLogger.debug('$serviceName: Parse event logging failed: $e');
    });
  }
}
