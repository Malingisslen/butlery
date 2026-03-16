import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/extraction/web_scraper.dart';
import 'package:butlery/services/extraction/site_parsers/site_parser_registry.dart';
import 'package:butlery/services/parsing/recipe_parser_service.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/utils/recipe_scraper.dart';

import 'package:butlery/services/import/extractors/schema_org_recipe_extractor.dart';
import 'package:butlery/services/import/utilities/html_utilities.dart';
import 'package:butlery/services/import/heuristics/ingredient_line_detector.dart';
import 'package:butlery/services/parsing/sanitizers/html_sanitizer.dart';
import 'package:butlery/services/import/fetchers/http_content_fetcher.dart';
import 'package:butlery/services/import/fallbacks/llm_extraction_fallback.dart';
import 'package:butlery/services/parsing/parse_event_logger.dart';

/// Imports recipes from web URLs using multi-tier extraction (structured data, scraping, LLM fallback).
class UrlImportStrategy extends ImportStrategy with ImportValidationMixin {
  static const _uuid = Uuid();

  final HttpContentFetcher _fetcher;
  final LlmExtractionFallback _llmFallback;
  final ParseEventLogger _eventLogger = ParseEventLogger();
  RecipeParserService? _parserService;

  UrlImportStrategy({
    http.Client? httpClient,
    WebScraper Function()? webScraperFactory,
  })  : _fetcher = HttpContentFetcher(
          httpClient: httpClient,
          webScraperFactory: webScraperFactory,
        ),
        _llmFallback = LlmExtractionFallback();

  RecipeParserService? get _recipeParser {
    if (_parserService != null) return _parserService;
    try {
      _parserService = ServiceLocator.get<RecipeParserService>();
      return _parserService;
    } catch (e) {
      AppLogger.debug(
          'UrlImportStrategy: RecipeParserService not available: $e');
      return null;
    }
  }

  @override
  String get strategyName => 'URL Import';

  @override
  String get description =>
      'Import recipes from web URLs (recipe sites, blogs, social media)';

  @override
  String get inputExample => 'https://www.ica.se/recept/pannkakor-123';

  @override
  bool canHandle(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;

    try {
      final uri = Uri.parse(trimmed);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.hasAuthority &&
          uri.host.isNotEmpty &&
          !HttpContentFetcher.isBlockedHost(uri.host);
    } catch (e) {
      return false;
    }
  }

  @override
  bool validateInput(String input) => canHandle(input);

  @override
  Future<ImportResult> import(String input,
      {Map<String, dynamic>? options}) async {
    try {
      final url = input.trim();
      final stopwatch = Stopwatch()..start();
      final domain = _extractDomain(url);

      // Fetch HTML — try simple HTTP first
      final httpHtml = await _fetcher.fetchHtmlWithTimeout(url);
      AppLogger.debug(
          'UrlImportStrategy: HTTP fetch for $domain → ${httpHtml == null ? "null" : "${httpHtml.length} chars"}');

      // Tier 1: Enhanced parser on HTTP HTML
      final parserResult = await _tryEnhancedParser(url, httpHtml, options);
      if (parserResult != null) return parserResult;

      // Tier 2: Structured data on HTTP HTML
      if (httpHtml != null) {
        final structuredResult = _tryStructuredExtraction(httpHtml, url);
        if (structuredResult != null) {
          _logImportEvent(url, domain, 'StructuredExtraction', true, stopwatch);
          return structuredResult;
        }
      }

      // Tier 3: Headless browser HTML — retry parser + structured extraction
      // Covers JS-rendered pages and sites blocking simple HTTP
      final scraperHtml = await _fetcher.tryWebScraperHtml(url);
      AppLogger.debug(
          'UrlImportStrategy: WebScraper HTML for $domain → ${scraperHtml == null ? "null" : "${scraperHtml.length} chars"}');
      if (scraperHtml != null) {
        final scraperParserResult =
            await _tryEnhancedParser(url, scraperHtml, options);
        if (scraperParserResult != null) return scraperParserResult;

        final scraperStructuredResult =
            _tryStructuredExtraction(scraperHtml, url);
        if (scraperStructuredResult != null) {
          _logImportEvent(url, domain, 'StructuredExtraction', true, stopwatch);
          return scraperStructuredResult;
        }
      }

      // Tier 4: Web scraper text extraction fallback
      final scraperResult = await _tryWebScraperFallback(url);
      if (scraperResult != null) {
        _logImportEvent(url, domain, 'WebScraper', true, stopwatch);
        return scraperResult;
      }

      // Use best available HTML for remaining tiers
      final bestHtml = scraperHtml ?? httpHtml;

      // Tier 5: HTML text parse
      if (bestHtml != null && bestHtml.length > 100) {
        final textResult = await _tryHtmlTextParse(bestHtml, url);
        if (textResult != null) {
          _logImportEvent(url, domain, 'HtmlTextParse', true, stopwatch);
          return textResult;
        }
      }

      // Tier 6: LLM extraction
      if (bestHtml != null && bestHtml.length > 100) {
        final llmResult =
            await _llmFallback.tryExtraction(bestHtml, url, strategyName);
        if (llmResult != null) {
          _logImportEvent(url, domain, 'LLM', true, stopwatch, usedLlm: true);
          return llmResult;
        }
      }

      // Tier 7: User-assisted import
      if (bestHtml != null && bestHtml.length > 100) {
        final assistedResult = _createUserAssistedResult(bestHtml, url);
        if (assistedResult != null) {
          _logImportEvent(url, domain, 'UserAssisted', true, stopwatch);
          return assistedResult;
        }
      }

      _logImportEvent(url, domain, null, false, stopwatch);
      return _createFailureResult(url, bestHtml);
    } catch (e) {
      return ImportResult.failure(
        'Error importing from URL: ${e.toString()}',
        metadata: {
          'strategy': strategyName,
          'error_type': e.runtimeType.toString(),
        },
      );
    }
  }

  Future<ImportResult?> _tryEnhancedParser(
      String url, String? htmlContent, Map<String, dynamic>? options) async {
    final parser = _recipeParser;
    if (parser == null || htmlContent == null) return null;

    final parseResult =
        await parser.parseFromUrl(url: url, htmlContent: htmlContent);
    if (!parseResult.success || parseResult.recipe == null) return null;

    AppLogger.info(
        'UrlImportStrategy: Enhanced parser extracted "${parseResult.recipe!.title.value}"');
    return _convertParsedRecipeToImportResult(parseResult, url);
  }

  ImportResult? _tryStructuredExtraction(String html, String url) {
    final siteParser = SiteParserRegistry.getParser(url);

    Map<String, dynamic>? recipeData;
    String extractionMethod;
    String? siteParserDomain;

    if (siteParser != null) {
      recipeData = siteParser.parseRecipe(html);
      extractionMethod = 'site_specific';
      siteParserDomain = siteParser.domain;
    } else {
      recipeData = extractRecipeFromHtml(html);
      extractionMethod = 'schema.org';
    }

    if (recipeData == null) return null;

    final recipe = SchemaOrgRecipeExtractor.createRecipe(recipeData, url);
    return ImportResult.success(recipe, metadata: {
      'strategy': strategyName,
      'extraction_method': extractionMethod,
      'data_format': recipeData['@type'] ?? 'Recipe',
      'url': url,
      if (siteParserDomain != null) 'site_parser': siteParserDomain,
    });
  }

  Future<ImportResult?> _tryWebScraperFallback(String url) async {
    final webScraperResult = await _fetcher.tryWebScraper(url);
    if (webScraperResult == null) return null;

    final textStrategy = TextImportStrategy();
    final textResult = await textStrategy.import(webScraperResult);

    if (!textResult.isSuccess || textResult.recipe == null) return null;

    final recipe = textResult.recipe!.copyWith(sourceUrl: url);
    return ImportResult.success(
      recipe,
      warnings: [
        ...?(textResult.warnings),
        'No structured data found - parsed as plain text'
      ],
      metadata: {
        'strategy': strategyName,
        'extraction_method': 'text_fallback',
        'url': url
      },
    );
  }

  Future<ImportResult?> _tryHtmlTextParse(String html, String url) async {
    final plainText = HtmlSanitizer.stripToPlainText(html);
    if (plainText.length <= 100) return null;

    final textStrategy = TextImportStrategy();
    final textResult = await textStrategy.import(plainText);

    if (!textResult.isSuccess || textResult.recipe == null) return null;

    final recipe = textResult.recipe!.copyWith(sourceUrl: url);
    return ImportResult.success(
      recipe,
      warnings: [
        ...?(textResult.warnings),
        'Extracted from HTML text - quality may vary'
      ],
      metadata: {
        'strategy': strategyName,
        'extraction_method': 'html_text_parse',
        'url': url,
        'tier': 3
      },
    );
  }

  ImportResult? _createUserAssistedResult(String html, String url) {
    final plainText = HtmlSanitizer.stripToPlainText(html);
    if (plainText.length <= 50) return null;

    AppLogger.info('UrlImportStrategy: Returning for user-assisted import');
    final suggestedTitle = HtmlUtilities.extractTitleFromHtml(html);
    final lines = plainText.split('\n');
    final likelyIngredients = IngredientLineDetector.findIngredientLines(lines);

    return ImportResult.assistance(
      extractedText: plainText,
      suggestedTitle: suggestedTitle,
      likelyIngredientLines: likelyIngredients,
      metadata: {'strategy': strategyName, 'url': url, 'tier': 5},
    );
  }

  ImportResult _createFailureResult(String url, String? htmlResult) {
    return ImportResult.failure(
      'Could not extract recipe from URL. The page may not contain a valid recipe.',
      metadata: {
        'strategy': strategyName,
        'url': url,
        'html_fetched': htmlResult != null,
        'html_length': htmlResult?.length ?? 0,
      },
    );
  }

  String? _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst(RegExp(r'^www\.'), '').toLowerCase();
    } catch (_) {
      return null;
    }
  }

  void _logImportEvent(
    String url,
    String? domain,
    String? successfulTier,
    bool success,
    Stopwatch stopwatch, {
    bool? usedLlm,
  }) {
    _eventLogger.logEvent(
      url: url,
      source: 'url',
      success: success,
      parseTimeMs: stopwatch.elapsedMilliseconds,
      domain: domain,
      successfulTier: successfulTier,
      usedLlm: usedLlm,
    );
  }

  ImportResult _convertParsedRecipeToImportResult(
      ParseResult parseResult, String url) {
    final parsed = parseResult.recipe!;

    final cache = ServiceLocator.tryGet<ParsedRecipeCache>();
    if (cache != null) {
      cache.store(url, parsed);
      AppLogger.debug('Stored ParsedRecipe in cache for: $url');
    }

    final ingredients =
        parsed.ingredients.value?.map((i) => i.originalLine).toList() ?? [];
    final instructions = parsed.instructions.value ?? [];

    final recipe = Recipe(
      core: RecipeCore(
        id: _uuid.v4(),
        title: parsed.title.value ?? 'Imported Recipe',
        description: parsed.description ?? '',
        ingredients: ingredients,
        instructions: instructions,
        portions: parsed.portions.value,
        timeMinutes: parsed.totalTime.value?.inMinutes,
        mealType: 'Middag',
        imageUrls: parsed.imageUrl != null ? [parsed.imageUrl!] : [],
        sourceUrl: url,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: '',
      ),
      type: RecipeType.personal,
    );

    return ImportResult.success(recipe, metadata: {
      'strategy': strategyName,
      'extraction_method': 'enhanced_parser',
      'url': url,
      'tier': 'multi',
      'fromCache': parseResult.fromCache,
      'parseTime': parseResult.totalTime.inMilliseconds,
      'overallQuality': parsed.overallQuality,
    });
  }
}
