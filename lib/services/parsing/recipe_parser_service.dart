import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/circuit_breaker.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/models/parsing/tier_result.dart';
import 'package:butlery/repositories/site_config_repository.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/parsing/cache/local_recipe_cache.dart';
import 'package:butlery/services/parsing/common/recipe_merger.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
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
  'SchemaOrg': 0.10, // JSON-LD is highly structured
  'SiteConfig': 0.05, // CSS selectors are semi-structured
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

  final SiteConfigRepository? _siteConfigRepository;
  final LlmService? _llmService;
  final String _userId;

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

  RecipeParserService({
    required String userId,
    SiteConfigRepository? siteConfigRepository,
    LlmService? llmService,
    IngredientParsingStrategy? ingredientStrategy,
  })  : _userId = userId,
        _siteConfigRepository = siteConfigRepository,
        _llmService = llmService {
    // Shared strategy: CRF when weights available, regex fallback
    final strategy = ingredientStrategy ?? IngredientParsingStrategy();

    _tiers = [
      SchemaOrgTier(ingredientStrategy: strategy),
      SiteConfigTier(
        configLoader: _siteConfigRepository?.getConfigIfExists,
        ingredientStrategy: strategy,
      ),
      RuleBasedTier(ingredientStrategy: strategy),
      LlmTier(llmService: _llmService),
    ];
  }

  /// Initialize the parser service.
  Future<void> init() async {
    // Create cache with CacheDao from OfflineService
    final offlineService = ServiceLocator.get<OfflineService>();
    _cacheField = LocalRecipeCache(
      userId: _userId,
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
    if (_siteConfigRepository != null && context.domain != null) {
      final config =
          await _siteConfigRepository.getConfigIfExists(context.domain!);
      if (config != null && config.isReliable) {
        effectiveThreshold = (qualityThreshold + _reliableDomainBoost)
            .clamp(0.0, _maxEffectiveThreshold);
      }
    }

    // Run parsing tiers
    final result = await _runTiers(
      context,
      qualityThreshold: effectiveThreshold,
      useLlm: useLlm,
    );

    if (result == null) {
      _logParseEvent(
        url: url,
        source: context.source.name,
        success: false,
        fromCache: false,
        parseTimeMs: stopwatch.elapsedMilliseconds,
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

    _logParseEvent(
      url: url,
      source: context.source.name,
      success: true,
      fromCache: false,
      parseTimeMs: stopwatch.elapsedMilliseconds,
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

    final result = await _runTiers(
      context,
      qualityThreshold: qualityThreshold,
      useLlm: useLlm,
    );

    if (result == null) {
      _logParseEvent(
        url: null,
        source: source.name,
        success: false,
        fromCache: false,
        parseTimeMs: stopwatch.elapsedMilliseconds,
      );
      return ParseResult.failure(
        'Could not extract recipe from text',
        totalTime: stopwatch.elapsed,
        userMessage: _pickUserMessage(),
      );
    }

    _logParseEvent(
      url: null,
      source: source.name,
      success: true,
      fromCache: false,
      parseTimeMs: stopwatch.elapsedMilliseconds,
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
  Future<ParsedRecipe?> _runTiers(
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

      // Before LLM tier: check if earlier tiers produced a partial result
      // that can be enhanced instead of fully re-extracted.
      if (tier is LlmTier) {
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

    return _merger.merge(results);
  }

  /// Extract good fields from the best partial result and set them on the
  /// context so the LLM tier can use enhance mode instead of full extraction.
  void _preparePartialForEnhancement(
    List<TierResult> results,
    ParsingContext context,
  ) {
    // Find best successful result from earlier tiers
    final bestResult = results
        .where((r) => r.success && r.recipe != null)
        .fold<TierResult?>(null, (best, r) {
      if (best == null || r.quality > best.quality) return r;
      return best;
    });

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
  }) {
    // Fire and forget - don't await, don't fail on error
    _functions.httpsCallable('logParseEvent').call<Map<String, dynamic>>({
      'url': url,
      'source': source,
      'success': success,
      'fromCache': fromCache,
      'parseTimeMs': parseTimeMs,
      'parserVersion': parserVersion,
    }).then((_) {
      // Success - do nothing
    }).catchError((e) {
      // Silently ignore analytics errors - don't disrupt parsing
      AppLogger.debug('$serviceName: Parse event logging failed: $e');
    });
  }
}
