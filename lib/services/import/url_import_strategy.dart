import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:clock/clock.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe/source_artefact.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/extraction/web_scraper.dart';
import 'package:butlery/services/extraction/site_parsers/site_parser_registry.dart';
import 'package:butlery/services/parsing/recipe_parser_service.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/services/parsing/feedback/import_correction_snapshot.dart';
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:butlery/utils/recipe_scraper.dart';

import 'package:butlery/services/import/extractors/schema_org_recipe_extractor.dart';
import 'package:butlery/services/import/utilities/html_utilities.dart';
import 'package:butlery/services/import/heuristics/ingredient_line_detector.dart';
import 'package:butlery/services/parsing/sanitizers/html_sanitizer.dart';
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
    // BUT-1078: forward a DNS lookup seam to HttpContentFetcher so the
    // DNS-rebinding gate can be driven end-to-end in tests (e.g. a hostname
    // that resolves to 127.0.0.1). Defaults to InternetAddress.lookup in
    // HttpContentFetcher when null.
    Future<List<InternetAddress>> Function(String host)? dnsLookup,
  }) : _fetcher = HttpContentFetcher(
         httpClient: httpClient,
         webScraperFactory: webScraperFactory,
         dnsLookup: dnsLookup,
       ),
       _llmFallback = LlmExtractionFallback();

  RecipeParserService? get _recipeParser {
    if (_parserService != null) return _parserService;
    try {
      _parserService = ServiceLocator.get<RecipeParserService>();
      return _parserService;
    } catch (e) {
      AppLogger.debug(
        'UrlImportStrategy: RecipeParserService not available: $e',
      );
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
  Future<ImportResult> import(
    String input, {
    Map<String, dynamic>? options,
  }) async {
    try {
      final url = input.trim();
      final domain = _extractDomain(url);

      // Fetch HTML — try simple HTTP first
      final httpFetch = await _fetcher.fetchHtml(url);
      final httpHtml = httpFetch.html;
      AppLogger.debug(
        'UrlImportStrategy: HTTP fetch for $domain → ${httpHtml == null ? "null" : "${httpHtml.length} chars"}',
      );

      // BUT-1650: a below-threshold enhanced parse (real ingredients but weak
      // overall) is held here as a floor rather than shipped immediately, so the
      // cascade — crucially the Tier 6 LLM escalation — still gets to produce a
      // cleaner recipe. If nothing beats it, the held parse is returned at the
      // end (never a regression: the old code shipped exactly this parse).
      ImportResult? belowThresholdEnhanced;

      // Tier 1: Enhanced parser on HTTP HTML
      final parserOutcome = await _tryEnhancedParser(url, httpHtml, options);
      if (parserOutcome != null) {
        if (parserOutcome.quality >= defaultQualityThreshold) {
          return parserOutcome.result;
        }
        belowThresholdEnhanced ??= parserOutcome.result;
      }

      // Tier 2: Structured data on HTTP HTML
      if (httpHtml != null) {
        final structuredResult = _tryStructuredExtraction(httpHtml, url);
        if (structuredResult != null) {
          return _atTier(structuredResult, 'StructuredExtraction');
        }
      }

      // Tier 3: Headless browser HTML — retry parser + structured extraction
      // Covers JS-rendered pages and sites blocking simple HTTP
      final scraperHtml = await _fetcher.tryWebScraperHtml(url);
      AppLogger.debug(
        'UrlImportStrategy: WebScraper HTML for $domain → ${scraperHtml == null ? "null" : "${scraperHtml.length} chars"}',
      );
      if (scraperHtml != null) {
        // BUT-1650: same quality gate for the scraper-HTML enhanced parse — a
        // JS-rendered page can beat the HTTP parse, but a still-weak result is
        // held, not shipped, so the LLM escalation runs.
        final scraperParserOutcome = await _tryEnhancedParser(
          url,
          scraperHtml,
          options,
        );
        if (scraperParserOutcome != null) {
          if (scraperParserOutcome.quality >= defaultQualityThreshold) {
            return scraperParserOutcome.result;
          }
          belowThresholdEnhanced ??= scraperParserOutcome.result;
        }

        final scraperStructuredResult = _tryStructuredExtraction(
          scraperHtml,
          url,
        );
        if (scraperStructuredResult != null) {
          return _atTier(scraperStructuredResult, 'StructuredExtraction');
        }
      }

      // Tier 4: Web scraper text extraction fallback
      final scraperResult = await _tryWebScraperFallback(url);
      if (scraperResult != null) {
        return _atTier(scraperResult, 'WebScraper');
      }

      // Use best available HTML for remaining tiers
      final bestHtml = scraperHtml ?? httpHtml;

      // Tier 5: HTML text parse
      if (bestHtml != null && bestHtml.length > 100) {
        final textResult = await _tryHtmlTextParse(bestHtml, url);
        if (textResult != null) {
          return _atTier(textResult, 'HtmlTextParse');
        }
      }

      // Tier 6: LLM extraction
      if (bestHtml != null && bestHtml.length > 100) {
        final llmResult = await _llmFallback.tryExtraction(
          bestHtml,
          url,
          strategyName,
        );
        if (llmResult != null) {
          return _atTier(llmResult, 'LLM');
        }
      }

      // BUT-1650: no tier beat the held below-threshold enhanced parse (the
      // Tier 6 LLM included) — return it as the floor rather than dropping to
      // user-assist/failure. It carries real parsed structure, so it is a
      // better outcome than Tier 7 for the user.
      if (belowThresholdEnhanced != null) {
        return belowThresholdEnhanced;
      }

      // Tier 7: User-assisted import
      if (bestHtml != null && bestHtml.length > 100) {
        final assistedResult = _createUserAssistedResult(bestHtml, url);
        if (assistedResult != null) {
          return _atTier(assistedResult, 'UserAssisted');
        }
      }

      return _createFailureResult(url, bestHtml, httpFetch);
    } catch (e) {
      AppLogger.error('URL import failed', e);
      return ImportResult.failure(
        'Could not import recipe from URL. Please try again.',
        errorCode: ImportErrorCode.parsingFailed,
        metadata: {
          'strategy': strategyName,
        },
      );
    }
  }

  /// Runs the multi-tier enhanced parser (LLM disabled — BUT-1476) and returns
  /// both the converted [ImportResult] and the parse's [overallQuality] so the
  /// caller can quality-gate it (BUT-1650). Null when the parser is unavailable
  /// or produced no recipe.
  Future<({ImportResult result, double quality})?> _tryEnhancedParser(
    String url,
    String? htmlContent,
    Map<String, dynamic>? options,
  ) async {
    final parser = _recipeParser;
    if (parser == null || htmlContent == null) return null;

    // BUT-1476: disable the parser's own LLM tier here so a failed URL import
    // has a SINGLE Gemini escalation owner — the Tier 6 LlmExtractionFallback in
    // import(). _tryEnhancedParser runs up to twice per import (HTTP HTML, then
    // scraper HTML); left enabled, its internal LlmTier could fire Gemini on
    // each pass and the Tier 6 fallback a third time — up to 3 full LLM calls
    // for one failed import. The cheaper structured/scraper tiers still run;
    // only the LLM escalation is funnelled to one point.
    final parseResult = await parser.parseFromUrl(
      url: url,
      htmlContent: htmlContent,
      useLlm: false,
    );
    if (!parseResult.success || parseResult.recipe == null) return null;

    AppLogger.info(
      'UrlImportStrategy: Enhanced parser extracted "${parseResult.recipe!.title.value}"',
    );
    return (
      result: _convertParsedRecipeToImportResult(parseResult, url),
      quality: parseResult.recipe!.overallQuality,
    );
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
    return ImportResult.success(
      recipe,
      metadata: {
        'strategy': strategyName,
        'extraction_method': extractionMethod,
        'data_format': recipeData['@type'] ?? 'Recipe',
        'url': url,
        'site_parser': ?siteParserDomain,
      },
    );
  }

  Future<ImportResult?> _tryWebScraperFallback(String url) async {
    final webScraperResult = await _fetcher.tryWebScraper(url);
    if (webScraperResult == null) return null;

    final textStrategy = TextImportStrategy();
    final textResult = await textStrategy.import(webScraperResult);

    if (!textResult.isSuccess || textResult.recipe == null) return null;

    final recipe = textResult.recipe!.copyWith(
      sourceUrl: url,
      sourceArtefact: SourceArtefact(
        type: SourceArtefactType.url,
        payload: url,
        fetchedAt: clock.now(),
      ),
    );
    // BUT-1469: the inner TextImportStrategy already stored a correction
    // snapshot tagged ImportSource.text with no domain. Re-tag it url+domain
    // (same recipe id, last write wins) — mirrors the photo/voice override — so
    // corrections from a URL never pollute the pasted-text training bucket and
    // keep their domain attribution for URL alias-learning.
    ImportCorrectionSnapshot.capture(
      recipe,
      source: ImportSource.url,
      domain: _extractDomain(url),
    );
    return ImportResult.success(
      recipe,
      warnings: [
        ...?(textResult.warnings),
        'No structured data found - parsed as plain text',
      ],
      metadata: {
        'strategy': strategyName,
        'extraction_method': 'text_fallback',
        'url': url,
      },
    );
  }

  Future<ImportResult?> _tryHtmlTextParse(String html, String url) async {
    final plainText = HtmlSanitizer.stripToPlainText(html);
    if (plainText.length <= 100) return null;

    // BUT-1070: if the page has JSON-LD structured data but no Recipe @type,
    // it's almost certainly a news article / blog post the schema.org tier
    // already rejected. Surface a strong warning so the user understands
    // the result is unlikely to be a real recipe.
    final nonRecipeJsonLdDetected = hasOnlyNonRecipeJsonLd(html);

    final textStrategy = TextImportStrategy();
    final textResult = await textStrategy.import(plainText);

    if (!textResult.isSuccess || textResult.recipe == null) return null;

    // BUT-1077: quality gate — fall through to Tier 7 (user-assisted) when
    // the text parser found no recipe-like structure at all (no ingredients,
    // no instructions). Pure prose blogs have no ingredients or instructions
    // detected by TextImportStrategy, so presenting them as a "success with
    // warnings" is worse UX than letting the user correct via Tier 7.
    final r = textResult.recipe!;
    if (r.core.ingredients.isEmpty && r.core.instructions.isEmpty) return null;

    final recipe = textResult.recipe!.copyWith(
      sourceUrl: url,
      sourceArtefact: SourceArtefact(
        type: SourceArtefactType.url,
        payload: url,
        fetchedAt: clock.now(),
      ),
    );
    // BUT-1469: re-tag the inner text snapshot as url+domain (see
    // _tryWebScraperFallback) — same recipe id, last write wins.
    ImportCorrectionSnapshot.capture(
      recipe,
      source: ImportSource.url,
      domain: _extractDomain(url),
    );
    return ImportResult.success(
      recipe,
      warnings: [
        if (nonRecipeJsonLdDetected)
          AppLocale.current.warningUrlImportNotARecipe,
        ...?(textResult.warnings),
        'Extracted from HTML text - quality may vary',
      ],
      metadata: {
        'strategy': strategyName,
        'extraction_method': 'html_text_parse',
        'url': url,
        // BUT-1076: was 3, now matches the Tier 5 source comment.
        'tier': 5,
      },
    );
  }

  /// BUT-1070: returns true when the HTML has at least one JSON-LD block with
  /// an `@type` and NONE of the discovered `@type` values match `Recipe`. Used
  /// to escalate the "this is probably a news article" signal in the
  /// text-fallback tier.
  @visibleForTesting
  bool hasOnlyNonRecipeJsonLd(String html) {
    // Reads the PARSED document, like `_extractJsonLd` does, so this signal
    // and the extraction it escalates cannot disagree about which blocks are
    // JSON-LD. A page whose `+` is entity-encoded HAS JSON-LD, and a matcher
    // blind to that reads it as a page with none, which flips this signal's
    // answer (BUT-2020/BUT-2037).
    final blocks = html_parser
        .parse(html)
        .querySelectorAll('script')
        .where((e) => isJsonLdMediaType(e.attributes['type']));

    var sawAnyType = false;
    var sawRecipe = false;

    for (final block in blocks) {
      final body = block.text.trim();
      if (body.isEmpty) continue;

      dynamic decoded;
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        continue;
      }

      void inspect(dynamic node) {
        if (node is List) {
          for (final item in node) {
            inspect(item);
          }
        } else if (node is Map) {
          final type = node['@type'];
          if (type is String) {
            sawAnyType = true;
            if (type == 'Recipe') sawRecipe = true;
          } else if (type is List) {
            for (final t in type) {
              if (t is String) {
                sawAnyType = true;
                if (t == 'Recipe') sawRecipe = true;
              }
            }
          }
          // Walk @graph too — many sites nest items under it.
          final graph = node['@graph'];
          if (graph != null) inspect(graph);
        }
      }

      inspect(decoded);
    }

    return sawAnyType && !sawRecipe;
  }

  ImportResult? _createUserAssistedResult(String html, String url) {
    final plainText = HtmlSanitizer.stripToPlainText(html);
    if (plainText.length <= 50) return null;

    final suggestedTitle = HtmlUtilities.extractTitleFromHtml(html);
    final lines = plainText.split('\n');
    final likelyIngredients = IngredientLineDetector.findIngredientLines(lines);
    // BUT-2237: help is offered for a page that holds something to finish by
    // hand. A login form, or a page with no ingredient line at all, is a
    // failure with its own cause rather than a dead-end help screen.
    if (likelyIngredients.isEmpty || _loginForm.hasMatch(html)) return null;

    AppLogger.info('UrlImportStrategy: Returning for user-assisted import');
    return ImportResult.assistance(
      extractedText: plainText,
      suggestedTitle: suggestedTitle,
      likelyIngredientLines: likelyIngredients,
      // BUT-1076: tier was 5, now matches the Tier 7 source comment.
      metadata: {'strategy': strategyName, 'url': url, 'tier': 7},
    );
  }

  ImportResult _createFailureResult(
    String url,
    String? htmlResult,
    HtmlFetch httpFetch,
  ) {
    final code = failureCodeFor(htmlResult, httpFetch);
    return ImportResult.failure(
      switch (code) {
        ImportErrorCode.urlNotAccessible => 'Could not reach the page.',
        ImportErrorCode.platformBlocked => 'The page requires login.',
        _ => 'No recipe found on the page.',
      },
      errorCode: code,
      metadata: {
        'strategy': strategyName,
        'url': url,
        'html_fetched': htmlResult != null,
        'html_length': htmlResult?.length ?? 0,
        if (httpFetch.statusCode != null) 'http_status': httpFetch.statusCode,
      },
    );
  }

  /// Why every tier gave up. Only reached after tiers 1–7 all declined, so a
  /// page that WAS read held no structured recipe and no ingredient lines.
  @visibleForTesting
  static ImportErrorCode failureCodeFor(String? html, HtmlFetch httpFetch) {
    if (html == null) {
      final status = httpFetch.statusCode;
      return status == 401 || status == 403
          ? ImportErrorCode.platformBlocked
          : ImportErrorCode.urlNotAccessible;
    }
    return _loginForm.hasMatch(html)
        ? ImportErrorCode.platformBlocked
        : ImportErrorCode.noRecipeContent;
  }

  static final _loginForm = RegExp(
    r'''<input[^>]+type\s*=\s*["']?password''',
    caseSensitive: false,
  );

  String? _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst(RegExp(r'^www\.'), '').toLowerCase();
    } catch (_) {
      return null;
    }
  }

  /// Names the tier that answered, for the import's one parse event.
  static ImportResult _atTier(ImportResult result, String tier) =>
      result.withMetadata({'successfulTier': tier});

  ImportResult _convertParsedRecipeToImportResult(
    ParseResult parseResult,
    String url,
  ) {
    final parsed = parseResult.recipe!;
    final recipeId = _uuid.v4();

    // BUT-1469: key the correction-capture snapshot by recipe id (not sourceUrl)
    // so every import path shares one cache scheme. URL keeps its rich, genuine
    // ParsedRecipe here — the other strategies store a lighter snapshot.
    final cache = ServiceLocator.tryGet<ParsedRecipeCache>();
    if (cache != null) {
      cache.store(recipeId, parsed);
      AppLogger.debug(
        'Stored ParsedRecipe in cache for import correction: $recipeId',
      );
    }

    final parsedIngredients = parsed.ingredients.value;
    final ingredients =
        parsedIngredients?.map((i) => i.originalLine).toList() ?? [];
    final instructions = parsed.instructions.value ?? [];

    final recipe = Recipe(
      core: RecipeCore(
        id: recipeId,
        title: parsed.title.value ?? 'Imported Recipe',
        description: parsed.description.orEmpty(),
        ingredients: ingredients,
        // BUT-1216: persist the parser's structured form (amount/unit/name)
        // instead of discarding it — index-aligned with `ingredients`.
        structuredIngredients: parsedIngredients
            ?.map(RecipeIngredient.fromParsed)
            .toList(),
        instructions: instructions,
        portions: parsed.portions.value,
        timeMinutes: parsed.totalTime.value?.inMinutes,
        mealType: 'Middag',
        imageUrls: parsed.imageUrl != null ? [parsed.imageUrl!] : [],
        sourceUrl: url,
        sourceArtefact: SourceArtefact(
          type: SourceArtefactType.url,
          payload: url,
          fetchedAt: clock.now(),
        ),
        createdAt: clock.now(),
        updatedAt: clock.now(),
        createdBy: '',
      ),
      type: RecipeType.personal,
    );

    return ImportResult.success(
      recipe,
      metadata: {
        'strategy': strategyName,
        'extraction_method': 'enhanced_parser',
        'url': url,
        'tier': 'multi',
        'fromCache': parseResult.fromCache,
        'parseTime': parseResult.totalTime.inMilliseconds,
        'overallQuality': parsed.overallQuality,
        'successfulTier': ?parseResult.tierResults
            .where((t) => t.success)
            .lastOrNull
            ?.tierName,
        'tierAttempts': [
          for (final t in parseResult.tierResults)
            {
              'tier': t.tierName,
              'success': t.success,
              'quality': t.quality,
              'durationMs': t.duration.inMilliseconds,
            },
        ],
        if (parseResult.unknownDomain) 'unknownDomain': true,
      },
    );
  }
}
