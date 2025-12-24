import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

/// Handles LLM-based recipe extraction as a fallback when structured data is unavailable.
class LlmExtractionFallback {
  LlmEnhancementService? _llmService;

  LlmEnhancementService? get _llmEnhancement {
    if (_llmService != null) return _llmService;
    try {
      _llmService = ServiceLocator.get<LlmEnhancementService>();
      return _llmService;
    } catch (e) {
      return null;
    }
  }

  /// Attempts LLM-based recipe extraction from HTML.
  /// Returns null if LLM is unavailable, rate limited, or extraction fails.
  Future<ImportResult?> tryExtraction(String html, String url, String strategyName) async {
    final llm = _llmEnhancement;
    if (llm == null) {
      AppLogger.debug('LlmExtractionFallback: LLM service not available');
      return null;
    }

    final isAvailable = await llm.isAvailable();
    if (!isAvailable) {
      AppLogger.info('LlmExtractionFallback: LLM rate limited, skipping');
      return null;
    }

    AppLogger.info('LlmExtractionFallback: Trying LLM extraction for $url');

    try {
      final llmResult = await llm.extractFromHtml(html, url, currentTier: 3);

      if (llmResult is ImportSuccess) {
        AppLogger.info(
          'LlmExtractionFallback: LLM extracted "${llmResult.recipe.title}"',
        );
        return ImportResult.success(
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
        );
      }

      if (llmResult is ImportFailure) {
        if (llmResult.errorCode == ImportErrorCode.rateLimited ||
            llmResult.errorCode == ImportErrorCode.llmQuotaExceeded) {
          AppLogger.info('LlmExtractionFallback: LLM rate limited');
          return null;
        }

        AppLogger.warning(
          'LlmExtractionFallback: LLM extraction failed - ${llmResult.message}',
        );
        return null;
      }

      if (llmResult is ImportNeedsAssistance) {
        AppLogger.info('LlmExtractionFallback: LLM needs user assistance');
        return null;
      }

      return null;
    } catch (e) {
      AppLogger.warning('LlmExtractionFallback: LLM extraction error - $e');
      return null;
    }
  }
}
