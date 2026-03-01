/// TikTok recipe import pipeline with multi-tier extraction.
///
/// Handles TikTok recipe video imports with 4-tier approach:
/// 1. oEmbed API caption extraction
/// 2. Emoji-based ingredient detection
/// 3. LLM with caption context
/// 4. Request user screenshot
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';

/// TikTok video metadata from oEmbed.
class TikTokMetadata {
  final String? title;
  final String? authorName;
  final String? thumbnailUrl;
  final String videoUrl;

  const TikTokMetadata({
    this.title,
    this.authorName,
    this.thumbnailUrl,
    required this.videoUrl,
  });
}

/// TikTok recipe import pipeline.
///
/// Tier structure:
/// 1. oEmbed caption parsing (free)
/// 2. Emoji-based ingredient detection (free)
/// 3. LLM extraction from caption (paid)
/// 4. Request user screenshot (free)
class TikTokPipeline extends ImportStrategy with ImportValidationMixin {
  @override
  String get strategyName => 'tiktok';

  @override
  String get description =>
      'Importera recept från TikTok-videor genom att analysera beskrivningen';

  @override
  String get inputExample => 'https://www.tiktok.com/@user/video/123456789';

  /// TikTok URL patterns.
  static final _tiktokPatterns = [
    // Standard: tiktok.com/@user/video/ID
    RegExp(r'tiktok\.com/@[^/]+/video/(\d+)'),
    // Short: vm.tiktok.com/XXX
    RegExp(r'vm\.tiktok\.com/([A-Za-z0-9]+)'),
    // Mobile: m.tiktok.com/v/ID
    RegExp(r'm\.tiktok\.com/v/(\d+)'),
    // Web player: tiktok.com/embed/ID
    RegExp(r'tiktok\.com/embed/(\d+)'),
  ];

  /// Swedish cooking-related emojis for ingredient detection.
  static const _cookingEmojis = [
    // Ingredients
    '\u{1F95A}', // egg
    '\u{1F95B}', // milk
    '\u{1F9C8}', // butter
    '\u{1F9C0}', // cheese
    '\u{1F35E}', // bread
    '\u{1FAD3}', // flatbread
    '\u{1F956}', // baguette
    '\u{1F950}', // croissant
    '\u{1F95E}', // pancakes
    '\u{1F953}', // bacon
    '\u{1F969}', // meat
    '\u{1F357}', // chicken leg
    '\u{1F41F}', // fish
    '\u{1F990}', // shrimp
    '\u{1F980}', // crab
    '\u{1F99E}', // lobster
    '\u{1F955}', // carrot
    '\u{1F966}', // broccoli
    '\u{1F952}', // cucumber
    '\u{1F345}', // tomato
    '\u{1FAD2}', // olive
    '\u{1F9C5}', // onion
    '\u{1F9C4}', // garlic
    '\u{1F954}', // potato
    '\u{1F360}', // sweet potato
    '\u{1F33D}', // corn
    '\u{1FAD1}', // bell pepper
    '\u{1F336}', // hot pepper
    '\u{1F344}', // mushroom
    '\u{1F951}', // avocado
    '\u{1F34B}', // lemon
    '\u{1F34A}', // orange
    '\u{1F34E}', // apple
    '\u{1F353}', // strawberry
    '\u{1FAD0}', // blueberries
    '\u{1F347}', // grapes
    '\u{1F34C}', // banana
    '\u{1F965}', // coconut
    '\u{1F95C}', // peanuts
    '\u{1F330}', // chestnut
    '\u{1F36B}', // chocolate
    '\u{1F36F}', // honey
    '\u{1F9C2}', // salt
    // Cooking tools/actions
    '\u{1F373}', // cooking/frying pan
    '\u{1F372}', // pot of food
    '\u{1F958}', // pan with food
    '\u{1F37D}', // plate with cutlery
    '\u{2728}', // sparkles (often used for presentation)
  ];

  final LlmEnhancementService _llmService;
  final http.Client _client;
  final bool _ownsClient;

  TikTokPipeline({
    required LlmEnhancementService llmService,
    http.Client? client,
  })  : _llmService = llmService,
        _client = client ?? http.Client(),
        _ownsClient = client == null;

  @override
  bool canHandle(String input) {
    return _isTikTokUrl(input);
  }

  @override
  bool validateInput(String input) {
    return _isTikTokUrl(input);
  }

  bool _isTikTokUrl(String url) {
    // Quick check first
    final lowerUrl = url.toLowerCase();
    if (!lowerUrl.contains('tiktok.com') && !lowerUrl.contains('vm.tiktok')) {
      return false;
    }
    // Validate with patterns
    return _tiktokPatterns.any((pattern) => pattern.hasMatch(url));
  }

  @override
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    final resultV2 = await importV2(input, options: options);
    return _convertToLegacyResult(resultV2);
  }

  /// Import using V2 result types.
  Future<ImportResultV2> importV2(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    AppLogger.info('TikTokPipeline: Starting import for $input');

    // Tier 1: Fetch metadata via oEmbed
    final metadata = await _fetchMetadata(input);
    final caption = metadata?.title ?? '';

    if (caption.isEmpty) {
      AppLogger.warning('TikTokPipeline: No caption available');
      // Skip to Tier 4: Request screenshot
      return ImportNeedsScreenshot(
        platform: 'TikTok',
        url: input,
        thumbnailUrl: metadata?.thumbnailUrl,
        message: AppLocale.current.tiktokCouldNotFetchDescription,
      );
    }

    AppLogger.info('TikTokPipeline: Got caption (${caption.length} chars)');

    // Tier 2: Check for emoji-based recipe format
    final emojiParsed = _parseEmojiIngredients(caption);
    if (emojiParsed != null && emojiParsed.ingredients.isNotEmpty) {
      AppLogger.info(
        'TikTokPipeline: Emoji parsing found ${emojiParsed.ingredients.length} ingredients',
      );

      // If we have enough structure, try to build a recipe
      if (emojiParsed.ingredients.length >= 3) {
        // Tier 3: Use LLM to structure the emoji-parsed content
        final llmResult = await _llmService.extractFromTranscript(
          _formatEmojiParsedForLlm(emojiParsed, caption),
          input,
          videoTitle: metadata?.title,
        );

        if (llmResult.isSuccess) {
          return ImportSuccess(
            recipe: (llmResult as ImportSuccess).recipe,
            confidence: 0.7,
            pipeline: 'tiktok',
            tier: 2,
            method: 'emoji-llm',
            usedLlm: true,
            requiresReview: true,
            metadata: {
              'videoUrl': input,
              'authorName': metadata?.authorName,
              'thumbnailUrl': metadata?.thumbnailUrl,
              'emojiIngredientCount': emojiParsed.ingredients.length,
            },
          );
        }
      }
    }

    // Tier 3: Try LLM extraction on raw caption
    final llmResult = await _llmService.extractFromTranscript(
      caption,
      input,
      videoTitle: metadata?.title,
    );

    if (llmResult.isSuccess) {
      return ImportSuccess(
        recipe: (llmResult as ImportSuccess).recipe,
        confidence: 0.65,
        pipeline: 'tiktok',
        tier: 3,
        method: 'caption-llm',
        usedLlm: true,
        requiresReview: true,
        metadata: {
          'videoUrl': input,
          'authorName': metadata?.authorName,
          'thumbnailUrl': metadata?.thumbnailUrl,
        },
      );
    }

    // Check for rate limit
    if (llmResult is ImportFailure &&
        llmResult.errorCode == ImportErrorCode.rateLimited) {
      return ImportNeedsAssistance(
        extractedText: caption,
        suggestedTitle: _extractTitleFromCaption(caption),
        thumbnailUrl: metadata?.thumbnailUrl,
        message: AppLocale.current.tiktokAiQuotaExhausted,
        partialData: {
          'videoUrl': input,
          'authorName': metadata?.authorName,
        },
      );
    }

    // Tier 4: User-assisted or screenshot
    if (caption.length > 50) {
      // We have some caption, offer user-assisted
      return ImportNeedsAssistance(
        extractedText: caption,
        suggestedTitle: _extractTitleFromCaption(caption),
        thumbnailUrl: metadata?.thumbnailUrl,
        message: AppLocale.current.tiktokCouldNotExtractRecipe,
        partialData: {
          'videoUrl': input,
          'authorName': metadata?.authorName,
        },
      );
    }

    // Tier 4: Request screenshot
    return ImportNeedsScreenshot(
      platform: 'TikTok',
      url: input,
      thumbnailUrl: metadata?.thumbnailUrl,
      message: AppLocale.current.tiktokNoRecipeInDescription,
    );
  }

  /// Fetch TikTok metadata via oEmbed API.
  Future<TikTokMetadata?> _fetchMetadata(String url) async {
    try {
      final oembedUrl = Uri.parse(
        'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(url)}',
      );

      final response = await _client.get(oembedUrl).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        AppLogger.warning(
          'TikTokPipeline: oEmbed request failed (${response.statusCode})',
        );
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;

      return TikTokMetadata(
        title: data['title'] as String?,
        authorName: data['author_name'] as String?,
        thumbnailUrl: data['thumbnail_url'] as String?,
        videoUrl: url,
      );
    } catch (e) {
      AppLogger.warning('TikTokPipeline: Failed to fetch metadata: $e');
      return null;
    }
  }

  /// Parse emoji-formatted ingredients from TikTok caption.
  _EmojiParsedRecipe? _parseEmojiIngredients(String caption) {
    final ingredients = <String>[];
    final instructions = <String>[];

    // Split by newlines and look for emoji patterns
    final lines = caption.split(RegExp(r'[\n\r]'));

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Check if line starts with a cooking emoji
      final hasEmoji = _cookingEmojis.any((emoji) => trimmed.contains(emoji));

      if (hasEmoji) {
        // Extract the text after the emoji
        String ingredient = trimmed;

        // Remove the emoji and clean up
        for (final emoji in _cookingEmojis) {
          ingredient = ingredient.replaceAll(emoji, '').trim();
        }

        // Check if it looks like a measurement
        if (_looksLikeMeasurement(ingredient)) {
          ingredients.add(ingredient);
        } else if (ingredient.length > 20) {
          // Longer text is likely an instruction
          instructions.add(ingredient);
        }
      }
    }

    if (ingredients.isEmpty && instructions.isEmpty) {
      return null;
    }

    return _EmojiParsedRecipe(
      ingredients: ingredients,
      instructions: instructions,
    );
  }

  /// Check if text looks like a measurement.
  bool _looksLikeMeasurement(String text) {
    final patterns = [
      RegExp(r'\d+\s*(dl|cl|ml|l|msk|tsk|krm|g|kg|st)\b', caseSensitive: false),
      RegExp(r'^\d+[\s,.]'),
      RegExp(r'(ca|cirka|ungefär)\s*\d+', caseSensitive: false),
    ];

    return patterns.any((p) => p.hasMatch(text));
  }

  /// Format emoji-parsed content for LLM processing.
  String _formatEmojiParsedForLlm(_EmojiParsedRecipe parsed, String original) {
    final buffer = StringBuffer();

    buffer.writeln(AppLocale.current.tiktokOriginalText);
    buffer.writeln(original);
    buffer.writeln();

    if (parsed.ingredients.isNotEmpty) {
      buffer.writeln(AppLocale.current.tiktokIdentifiedIngredients);
      for (final ing in parsed.ingredients) {
        buffer.writeln('- $ing');
      }
      buffer.writeln();
    }

    if (parsed.instructions.isNotEmpty) {
      buffer.writeln('Möjliga instruktioner:');
      for (final inst in parsed.instructions) {
        buffer.writeln('- $inst');
      }
    }

    return buffer.toString();
  }

  /// Extract a title from the caption.
  String? _extractTitleFromCaption(String caption) {
    // Look for common title patterns
    final patterns = [
      RegExp(r'^([^!?.]+[!?.])', multiLine: true), // First sentence
      RegExp(r'#([A-Za-zÅÄÖåäö]+recept)',
          caseSensitive: false), // Recipe hashtag
      RegExp(r'recept på\s+([^!?.]+)', caseSensitive: false), // "recept på X"
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(caption);
      if (match != null) {
        String title = match.group(1) ?? match.group(0) ?? '';
        // Clean up
        title = title
            .replaceAll(RegExp(r'#\w+'), '')
            .replaceAll(RegExp(r'@\w+'), '')
            .trim();
        if (title.length >= 5 && title.length <= 100) {
          return title;
        }
      }
    }

    // Fallback: first 50 chars
    if (caption.length > 10) {
      return '${caption.substring(0, caption.length > 50 ? 50 : caption.length)}...';
    }

    return null;
  }

  /// Convert V2 result to legacy ImportResult.
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

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

/// Parsed recipe from emoji-formatted content.
class _EmojiParsedRecipe {
  final List<String> ingredients;
  final List<String> instructions;

  _EmojiParsedRecipe({
    required this.ingredients,
    required this.instructions,
  });
}
