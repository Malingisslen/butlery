/// LLM Enhancement Service for recipe import.
///
/// This service integrates LLM capabilities into the import pipeline:
/// - Enhances partial extractions from rule-based methods
/// - Extracts recipes from images when OCR returns raw text
/// - Structures transcripts from YouTube/TikTok
library;

import 'dart:typed_data';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:butlery/services/parsing/ingredient_conversion.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/parsing/tiers/parsing_tier.dart';

/// Service for LLM-based recipe enhancement in the import pipeline.
class LlmEnhancementService extends BaseService {
  @override
  String get serviceName => 'LlmEnhancementService';

  final LlmService _llmService;
  final ImportRateLimiter _rateLimiter;

  LlmEnhancementService({
    required LlmService llmService,
    required ImportRateLimiter rateLimiter,
  }) : _llmService = llmService,
       _rateLimiter = rateLimiter;

  /// Enhance a partial extraction result with LLM.
  ///
  /// Takes an [ImportPartial] result and attempts to complete it using LLM.
  /// Returns [ImportSuccess] if enhancement succeeds, or [ImportFailure] if not.
  Future<ImportResultV2> enhance(ImportPartial partial) async {
    AppLogger.debug(
      'LlmEnhancementService: Enhancing partial result '
      '(confidence: ${partial.confidence}, missing: ${partial.missingFields})',
    );

    // Check if we have enough data to enhance
    if (!partial.canEnhance) {
      AppLogger.warning('LlmEnhancementService: Not enough data to enhance');
      return ImportFailure(
        message: AppLocale.current.llmEnhancementNotEnoughData,
        errorCode: ImportErrorCode.parsingFailed,
        pipeline: partial.pipeline,
        tier: partial.tier,
      );
    }

    // Check rate limit first
    final operation = ImportOperation.withLlm(
      'enhance',
      LlmOperationType.enhancement,
    );
    final limitCheck = await _rateLimiter.checkLimit(operation);

    if (limitCheck.isDenied) {
      final denied = limitCheck as RateLimitDenied;
      AppLogger.info('LlmEnhancementService: Rate limited - ${denied.message}');
      return ImportFailure.rateLimited(
        message: denied.swedishMessage,
        retryAfter: denied.retryAfter,
      );
    }

    try {
      // Prepare text for enhancement
      final text = partial.extractedText ?? partial.rawHtml ?? '';

      final response = await _llmService.structureRecipe(
        text: text,
        mode: StructureMode.enhance,
        partialData: partial.partialData,
      );

      if (!response.success || response.recipe == null) {
        AppLogger.warning(
          'LlmEnhancementService: Enhancement failed - ${response.error}',
        );
        return ImportFailure(
          message: response.error ?? AppLocale.current.errorAiEnhancementFailed,
          errorCode: ImportErrorCode.parsingFailed,
          pipeline: partial.pipeline,
          tier: partial.tier,
        );
      }

      // Convert to Recipe
      final recipe = _extractedToRecipe(response.recipe!);

      AppLogger.info(
        'LlmEnhancementService: Successfully enhanced to "${recipe.title}"',
      );

      return ImportSuccess(
        recipe: recipe,
        confidence: 0.85, // LLM-enhanced results have good confidence
        pipeline: partial.pipeline,
        tier: partial.tier + 1, // LLM is the next tier
        method: 'llm-enhancement',
        usedLlm: true,
        requiresReview: true, // LLM results should be reviewed
        metadata: {
          'originalConfidence': partial.confidence,
          'missingFields': partial.missingFields,
          'llmCost': response.estimatedCost,
        },
      );
    } on LlmException catch (e) {
      AppLogger.error('LlmEnhancementService: LLM error - $e');
      return ImportFailure(
        message: e.message,
        errorCode: e.isRateLimited
            ? ImportErrorCode.llmQuotaExceeded
            : ImportErrorCode.parsingFailed,
        retryAfter: e.retryAfter,
        pipeline: partial.pipeline,
        tier: partial.tier,
      );
    } catch (e) {
      AppLogger.error('LlmEnhancementService: Unexpected error - $e');
      return ImportFailure(
        message: 'Ett oväntat fel uppstod vid AI-förbättring.',
        errorCode: ImportErrorCode.unknown,
        technicalDetails: e.toString(),
        pipeline: partial.pipeline,
        tier: partial.tier,
      );
    }
  }

  /// Extract recipe from image using LLM vision.
  ///
  /// This is the final fallback after OCR methods fail.
  ///
  /// [isHandwritten] BUT-684: routes to the handwriting-tuned OCR prompt in
  /// the Cloud Function. Default false = printed-text prompt (unchanged).
  Future<ImportResultV2> extractFromImage(
    Uint8List imageBytes, {
    String? context,
    bool isHandwritten = false,
  }) async {
    AppLogger.debug(
      'LlmEnhancementService: Extracting from image (${imageBytes.length} bytes)',
    );

    // Check rate limit
    final operation = ImportOperation.withLlm('image', LlmOperationType.vision);
    final limitCheck = await _rateLimiter.checkLimit(operation);

    if (limitCheck.isDenied) {
      final denied = limitCheck as RateLimitDenied;
      AppLogger.info('LlmEnhancementService: Rate limited - ${denied.message}');
      return ImportFailure.rateLimited(
        message: denied.swedishMessage,
        retryAfter: denied.retryAfter,
      );
    }

    try {
      final response = await _llmService.ocrRecipeImage(
        imageBytes: imageBytes,
        context: context,
        isHandwritten: isHandwritten,
      );

      if (response.success && response.recipe != null) {
        final recipe = _extractedToRecipe(response.recipe!);
        AppLogger.info(
          'LlmEnhancementService: Successfully extracted "${recipe.title}" from image',
        );
        return ImportSuccess(
          recipe: recipe,
          confidence: 0.8,
          pipeline: 'photo',
          tier: 4, // LLM vision is the final tier
          method: 'llm-vision',
          usedLlm: true,
          requiresReview: true,
          metadata: {
            'llmCost': response.estimatedCost,
          },
        );
      }

      // If we got raw text but no structured recipe, return for user assistance
      if (response.rawText != null && response.rawText!.isNotEmpty) {
        AppLogger.info(
          'LlmEnhancementService: Got raw text, returning for user assistance',
        );
        return ImportNeedsAssistance(
          extractedText: response.rawText!,
          imageBytes: imageBytes,
          message: 'AI kunde inte strukturera texten automatiskt.',
        );
      }

      return ImportFailure(
        message: response.error ?? AppLocale.current.errorGeneric,
        errorCode: ImportErrorCode.ocrFailed,
        pipeline: 'photo',
        tier: 4,
      );
    } on LlmException catch (e) {
      AppLogger.error('LlmEnhancementService: LLM error - $e');
      return ImportFailure(
        message: e.message,
        errorCode: e.isRateLimited
            ? ImportErrorCode.llmQuotaExceeded
            : ImportErrorCode.ocrFailed,
        retryAfter: e.retryAfter,
        pipeline: 'photo',
        tier: 4,
      );
    }
  }

  /// Extract recipe from HTML using LLM as final fallback.
  ///
  /// Used when all rule-based extraction methods fail.
  Future<ImportResultV2> extractFromHtml(
    String html,
    String url, {
    int currentTier = 3,
  }) async {
    AppLogger.debug(
      'LlmEnhancementService: Extracting from HTML (${html.length} chars)',
    );

    // Check rate limit
    final operation = ImportOperation.withLlm(
      'website',
      LlmOperationType.fullExtraction,
    );
    final limitCheck = await _rateLimiter.checkLimit(operation);

    if (limitCheck.isDenied) {
      final denied = limitCheck as RateLimitDenied;
      return ImportFailure.rateLimited(
        message: denied.swedishMessage,
        retryAfter: denied.retryAfter,
      );
    }

    try {
      final response = await _llmService.structureRecipe(
        text: html,
        mode: StructureMode.extract,
        sourceUrl: url,
      );

      if (response.success && response.recipe != null) {
        final recipe = _extractedToRecipe(response.recipe!);
        return ImportSuccess(
          recipe: recipe,
          confidence: 0.8,
          pipeline: 'website',
          tier: currentTier + 1,
          method: 'llm-extraction',
          usedLlm: true,
          requiresReview: true,
          metadata: {
            'llmCost': response.estimatedCost,
            'sourceUrl': url,
          },
        );
      }

      return ImportFailure(
        message: response.error ?? 'AI kunde inte extrahera receptet.',
        errorCode: ImportErrorCode.parsingFailed,
        pipeline: 'website',
        tier: currentTier + 1,
      );
    } on LlmException catch (e) {
      return ImportFailure(
        message: e.message,
        errorCode: e.isRateLimited
            ? ImportErrorCode.llmQuotaExceeded
            : ImportErrorCode.parsingFailed,
        retryAfter: e.retryAfter,
        pipeline: 'website',
        tier: currentTier + 1,
      );
    }
  }

  /// Extract recipe from video transcript (YouTube, TikTok).
  Future<ImportResultV2> extractFromTranscript(
    String transcript,
    String url, {
    String? videoTitle,
  }) async {
    AppLogger.debug(
      'LlmEnhancementService: Extracting from transcript (${transcript.length} chars)',
    );

    // Check rate limit
    final operation = ImportOperation.withLlm(
      'video',
      LlmOperationType.fullExtraction,
    );
    final limitCheck = await _rateLimiter.checkLimit(operation);

    if (limitCheck.isDenied) {
      final denied = limitCheck as RateLimitDenied;
      return ImportFailure.rateLimited(
        message: denied.swedishMessage,
        retryAfter: denied.retryAfter,
      );
    }

    try {
      final response = await _llmService.structureRecipe(
        text: transcript,
        mode: StructureMode.spoken,
        sourceUrl: url,
      );

      if (response.success && response.recipe != null) {
        final recipe = _extractedToRecipe(response.recipe!);
        return ImportSuccess(
          recipe: recipe,
          confidence: 0.75, // Transcripts are harder to parse
          pipeline: 'video',
          tier: 5, // LLM is the main tier for video
          method: 'llm-transcript',
          usedLlm: true,
          requiresReview: true,
          metadata: {
            'llmCost': response.estimatedCost,
            'sourceUrl': url,
            'videoTitle': videoTitle,
          },
        );
      }

      // Return for user assistance if LLM fails
      return ImportNeedsAssistance(
        extractedText: transcript,
        suggestedTitle: videoTitle,
        message: 'AI kunde inte extrahera receptet från videon.',
      );
    } on LlmException catch (e) {
      return ImportFailure(
        message: e.message,
        errorCode: e.isRateLimited
            ? ImportErrorCode.llmQuotaExceeded
            : ImportErrorCode.parsingFailed,
        retryAfter: e.retryAfter,
        pipeline: 'video',
        tier: 5,
      );
    }
  }

  /// Check if LLM enhancement is available (not rate limited).
  Future<bool> isAvailable() => _llmService.isAvailable();

  // Private Helpers

  /// Convert ExtractedRecipe (from LLM) to Recipe model.
  Recipe _extractedToRecipe(ExtractedRecipe extracted) {
    // Infer meal type from tags if available
    final mealType = _inferMealType(extracted.tags);

    // BUT-1228: persist the LLM's structured form (amount/unit/name) instead
    // of discarding it. Both lists derive from the SAME ParsedIngredient list
    // (originalLine == formatted), which guarantees the index-alignment
    // invariant that Recipe.structuredIngredients validates. This seam covers
    // every LLM-built recipe: TikTok/Instagram captions, photo vision
    // fallback, URL Tier-6 fallback, and enhance mode.
    final parsedIngredients = extracted.ingredients
        .map(parsedIngredientFromExtracted)
        .toList();

    return Recipe.personal(
      title: extracted.title,
      description: extracted.description.orEmpty(),
      mealType: mealType,
      portions: extracted.portions ?? ParsingTier.kDefaultPortions,
      timeMinutes: extracted.totalTimeMinutes ?? 0,
      ingredients: parsedIngredients.map((i) => i.originalLine).toList(),
      structuredIngredients: parsedIngredients
          .map(RecipeIngredient.fromParsed)
          .toList(),
      instructions: extracted.instructions,
      personalTagIds: extracted.tags,
      sourceUrl: extracted.source,
    );
  }

  /// Infer meal type from recipe tags.
  String _inferMealType(List<String> tags) {
    final lowercaseTags = tags.map((t) => t.toLowerCase()).toList();

    if (lowercaseTags.any(
      (t) => t.contains('frukost') || t.contains('breakfast'),
    )) {
      return 'breakfast';
    }
    if (lowercaseTags.any((t) => t.contains('lunch'))) {
      return 'lunch';
    }
    if (lowercaseTags.any(
      (t) => t.contains('middag') || t.contains('dinner'),
    )) {
      return 'dinner';
    }
    if (lowercaseTags.any(
      (t) => t.contains('dessert') || t.contains('efterrätt'),
    )) {
      return 'dessert';
    }
    if (lowercaseTags.any(
      (t) => t.contains('snacks') || t.contains('mellanmål'),
    )) {
      return 'snack';
    }

    // Default to dinner
    return 'dinner';
  }
}
