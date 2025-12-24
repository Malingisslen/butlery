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
import 'package:butlery/services/import/fetchers/http_content_fetcher.dart';
import 'package:butlery/services/import/fallbacks/llm_extraction_fallback.dart';

/// Imports recipes from web URLs using multi-tier extraction (structured data, scraping, LLM fallback).
class UrlImportStrategy extends ImportStrategy with ImportValidationMixin {
  static const _uuid = Uuid();

  final HttpContentFetcher _fetcher;
  final LlmExtractionFallback _llmFallback;
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
             uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  bool validateInput(String input) => canHandle(input);

  @override
  Future<ImportResult> import(String input, {Map<String, dynamic>? options}) async {
    try {
      final url = input.trim();

      // Tier 1: Enhanced parser (if enabled)
      final parserResult = await _tryEnhancedParser(url, options);
      if (parserResult != null) return parserResult;

      final htmlResult = await _fetcher.fetchHtmlWithTimeout(url);

      if (htmlResult != null) {
        // Tier 2: Structured data (site-specific or schema.org)
        final structuredResult = _tryStructuredExtraction(htmlResult, url);
        if (structuredResult != null) return structuredResult;
      }

      // Tier 3: Web scraper fallback
      final scraperResult = await _tryWebScraperFallback(url);
      if (scraperResult != null) return scraperResult;

      // Tier 3.5: HTML text parse
      if (htmlResult != null && htmlResult.length > 100) {
        final textResult = await _tryHtmlTextParse(htmlResult, url);
        if (textResult != null) return textResult;
      }

      // Tier 4: LLM extraction
      if (htmlResult != null && htmlResult.length > 100) {
        final llmResult = await _llmFallback.tryExtraction(htmlResult, url, strategyName);
        if (llmResult != null) return llmResult;
      }

      // Tier 5: User-assisted import
      if (htmlResult != null && htmlResult.length > 100) {
        final assistedResult = _createUserAssistedResult(htmlResult, url);
        if (assistedResult != null) return assistedResult;
      }

      return _createFailureResult(url, htmlResult);

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

  Future<ImportResult?> _tryEnhancedParser(String url, Map<String, dynamic>? options) async {
    final parser = _recipeParser;
    if (parser == null || options?['useEnhancedParser'] != true) return null;

    final htmlContent = await _fetcher.fetchHtmlWithTimeout(url);
    if (htmlContent == null) return null;

    final parseResult = await parser.parseFromUrl(url: url, htmlContent: htmlContent);
    if (!parseResult.success || parseResult.recipe == null) return null;

    AppLogger.info('UrlImportStrategy: Enhanced parser extracted "${parseResult.recipe!.title.value}"');
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
      warnings: [...?(textResult.warnings), 'No structured data found - parsed as plain text'],
      metadata: {'strategy': strategyName, 'extraction_method': 'text_fallback', 'url': url},
    );
  }

  Future<ImportResult?> _tryHtmlTextParse(String html, String url) async {
    final plainText = HtmlUtilities.stripHtmlTags(html);
    if (plainText.length <= 100) return null;

    final textStrategy = TextImportStrategy();
    final textResult = await textStrategy.import(plainText);

    if (!textResult.isSuccess || textResult.recipe == null) return null;

    final recipe = textResult.recipe!.copyWith(sourceUrl: url);
    return ImportResult.success(
      recipe,
      warnings: [...?(textResult.warnings), 'Extracted from HTML text - quality may vary'],
      metadata: {'strategy': strategyName, 'extraction_method': 'html_text_parse', 'url': url, 'tier': 3},
    );
  }

  ImportResult? _createUserAssistedResult(String html, String url) {
    final plainText = HtmlUtilities.stripHtmlTags(html);
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

  ImportResult _convertParsedRecipeToImportResult(ParseResult parseResult, String url) {
    final parsed = parseResult.recipe!;

    final cache = ServiceLocator.tryGet<ParsedRecipeCache>();
    if (cache != null) {
      cache.store(url, parsed);
      AppLogger.debug('📊 Stored ParsedRecipe in cache for: $url');
    }

    final ingredients = parsed.ingredients.value?.map((i) => i.originalLine).toList() ?? [];
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
        mealType: 'Lunch',
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
