import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

/// What the AI fallback did for one import: the recipe it found, if any, and
/// the cost of the call when one reached the model (BUT-2239).
class LlmFallbackOutcome {
  const LlmFallbackOutcome({this.result, this.llmUse = const {}});

  /// No call was made: no service, no quota, or the client refused it.
  static const none = LlmFallbackOutcome();

  final ImportResult? result;

  /// `usedLlm` and `llmCost`, ready to merge into the import's final result.
  final Map<String, dynamic> llmUse;
}

/// Handles LLM-based recipe extraction as a fallback when structured data is unavailable.
class LlmExtractionFallback {
  /// The Cloud Function refuses longer input (`structure-recipe.ts`).
  static const maxInputChars = 50000;

  LlmEnhancementService? _llmService;

  LlmEnhancementService? get _llmEnhancement {
    if (_llmService != null) return _llmService;
    try {
      _llmService = ServiceLocator.get<LlmEnhancementService>();
      return _llmService;
    } catch (e) {
      AppLogger.debug(
        'LlmExtractionFallback: LlmEnhancementService not registered: $e',
      );
      return null;
    }
  }

  /// Attempts LLM-based recipe extraction from a page's readable text, cut to
  /// what the server accepts. Makes at most one call.
  Future<LlmFallbackOutcome> tryExtraction(
    String pageText,
    String url,
    String strategyName,
  ) async {
    final llm = _llmEnhancement;
    if (llm == null) {
      AppLogger.debug('LlmExtractionFallback: LLM service not available');
      return LlmFallbackOutcome.none;
    }

    final isAvailable = await llm.isAvailable();
    if (!isAvailable) {
      AppLogger.info('LlmExtractionFallback: LLM rate limited, skipping');
      return LlmFallbackOutcome.none;
    }

    AppLogger.info('LlmExtractionFallback: Trying LLM extraction for $url');

    try {
      final input = pageText.length > maxInputChars
          ? pageText.substring(0, maxInputChars)
          : pageText;
      final llmResult = await llm.extractFromPageText(
        input,
        url,
        currentTier: 3,
      );

      if (llmResult is ImportSuccess) {
        AppLogger.info(
          'LlmExtractionFallback: LLM extracted "${llmResult.recipe.title}"',
        );
        return LlmFallbackOutcome(
          result: ImportResult.success(
            llmResult.recipe,
            warnings: [
              'Extracted using AI - please review for accuracy',
            ],
            metadata: {
              'strategy': strategyName,
              'extraction_method': 'llm',
              'url': url,
              'tier': 4,
              'usedLlm': true,
              'requiresReview': true,
              ...?(llmResult.metadata),
            },
          ),
          llmUse: llmResult.llmUse,
        );
      }

      if (llmResult is ImportFailure) {
        AppLogger.warning(
          'LlmExtractionFallback: LLM extraction failed - ${llmResult.message}',
        );
      } else if (llmResult is ImportNeedsAssistance) {
        AppLogger.info('LlmExtractionFallback: LLM needs user assistance');
      }
      return LlmFallbackOutcome(llmUse: llmResult.llmUse);
    } catch (e) {
      AppLogger.warning('LlmExtractionFallback: LLM extraction error - $e');
      return LlmFallbackOutcome.none;
    }
  }
}
