/// Instagram recipe import pipeline with WebView-based caption extraction.
///
/// Tier structure:
/// 1. WebScraper caption extraction via InstagramContentExtractor (free, client-side)
/// 2. LLM structuring of extracted caption (paid, ~$0.005)
/// 3. User-assisted import with extracted text (free)
/// 4. Request user screenshot (free)
library;

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/extraction/platform_detector.dart';
import 'package:butlery/services/extraction/web_scraper.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';

class InstagramPipeline extends ImportStrategy with ImportValidationMixin {
  final LlmEnhancementService _llmService;

  /// `caseSensitive: false` because share-sheets and iOS Safari often emit
  /// mixed-case hosts (BUT-1113).
  static final _instagramPatterns = [
    RegExp(r'instagram\.com/p/([A-Za-z0-9_-]+)', caseSensitive: false),
    RegExp(r'instagram\.com/reel/([A-Za-z0-9_-]+)', caseSensitive: false),
    RegExp(r'instagr\.am/p/([A-Za-z0-9_-]+)', caseSensitive: false),
    RegExp(r'instagram\.com/([A-Za-z0-9_.]+)/p/', caseSensitive: false),
  ];

  InstagramPipeline({required LlmEnhancementService llmService})
      : _llmService = llmService;

  @override
  String get strategyName => 'instagram';

  @override
  String get description =>
      'Importera recept från Instagram-inlägg genom att extrahera bildtexten';

  @override
  String get inputExample => 'https://www.instagram.com/p/ABC123/';

  @override
  bool canHandle(String input) => _isInstagramUrl(input);

  @override
  bool validateInput(String input) => _isInstagramUrl(input);

  bool _isInstagramUrl(String url) {
    final lower = url.toLowerCase();
    if (!lower.contains('instagram.com') && !lower.contains('instagr.am')) {
      return false;
    }
    return _instagramPatterns.any((p) => p.hasMatch(url));
  }

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    final resultV2 = await importV2(input, options: options);
    return _convertToLegacyResult(resultV2);
  }

  Future<ImportResultV2> importV2(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    AppLogger.info('InstagramPipeline: Starting import for $input');

    // Tier 1: Extract caption via WebScraper + InstagramContentExtractor
    String? captionText;
    String? thumbnailUrl;
    final scraper = WebScraper();
    try {
      final result = await scraper.performExtraction(
        input,
        SourcePlatform.instagram,
      );
      captionText = result.extractedText;
      thumbnailUrl = result.metadata['thumbnailUrl'] as String?;
    } catch (e) {
      AppLogger.warning('InstagramPipeline: WebScraper extraction failed: $e');
    } finally {
      scraper.dispose();
    }

    if (captionText == null || captionText.trim().isEmpty) {
      AppLogger.warning('InstagramPipeline: No caption extracted');
      return ImportNeedsScreenshot(
        platform: 'Instagram',
        url: input,
        thumbnailUrl: thumbnailUrl,
        message: AppLocale.current.importErrorCouldNotReachPage,
      );
    }

    AppLogger.info(
      'InstagramPipeline: Got caption (${captionText.length} chars)',
    );

    // Tier 2: LLM extraction from caption
    final llmResult = await _llmService.extractFromTranscript(
      captionText,
      input,
    );

    if (llmResult.isSuccess) {
      return ImportSuccess(
        recipe: (llmResult as ImportSuccess).recipe,
        confidence: 0.65,
        pipeline: 'instagram',
        tier: 2,
        method: 'caption-llm',
        usedLlm: true,
        requiresReview: true,
        metadata: {
          'postUrl': input,
          'thumbnailUrl': thumbnailUrl,
        },
      );
    }

    // Rate limited — offer user-assisted
    if (llmResult is ImportFailure &&
        llmResult.errorCode == ImportErrorCode.rateLimited) {
      return ImportNeedsAssistance(
        extractedText: captionText,
        suggestedTitle: _extractTitleFromCaption(captionText),
        thumbnailUrl: thumbnailUrl,
        message: AppLocale.current.importErrorAiQuotaExhausted,
        partialData: {'postUrl': input},
      );
    }

    // Tier 3: User-assisted if we have enough text
    if (captionText.length > 50) {
      return ImportNeedsAssistance(
        extractedText: captionText,
        suggestedTitle: _extractTitleFromCaption(captionText),
        thumbnailUrl: thumbnailUrl,
        message: AppLocale.current.importErrorNoRecipeFound,
        partialData: {'postUrl': input},
      );
    }

    // Tier 4: Request screenshot
    return ImportNeedsScreenshot(
      platform: 'Instagram',
      url: input,
      thumbnailUrl: thumbnailUrl,
      message: AppLocale.current.importErrorNoRecipeFound,
    );
  }

  String? _extractTitleFromCaption(String caption) {
    final firstLine = caption.split('\n').first.trim();
    if (firstLine.length > 5 && firstLine.length < 100) return firstLine;
    return null;
  }

  ImportResult _convertToLegacyResult(ImportResultV2 resultV2) {
    return switch (resultV2) {
      final ImportSuccess success => ImportResult.success(
          success.recipe,
          metadata: {
            'pipeline': success.pipeline,
            'tier': success.tier,
            'method': success.method,
            'usedLlm': success.usedLlm,
            ...?success.metadata,
          },
        ),
      final ImportNeedsAssistance assistance => ImportResult.assistance(
          extractedText: assistance.extractedText,
          suggestedTitle: assistance.suggestedTitle,
          metadata: assistance.partialData,
        ),
      final ImportNeedsScreenshot screenshot => ImportResult.failure(
          screenshot.message,
          metadata: {
            'platform': screenshot.platform,
            'url': screenshot.url,
            'thumbnailUrl': screenshot.thumbnailUrl,
            'needsScreenshot': true,
          },
        ),
      final ImportPartial partial => ImportResult.assistance(
          extractedText: partial.extractedText ?? '',
          suggestedTitle: partial.title,
          metadata: partial.partialData,
        ),
      final ImportFailure failure => ImportResult.failure(
          failure.message,
          metadata: {
            'errorCode': failure.errorCode.name,
            'pipeline': failure.pipeline,
            'tier': failure.tier,
          },
        ),
    };
  }
}
