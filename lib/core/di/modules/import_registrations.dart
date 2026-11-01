/// BUT-1508: what the import manager and the URL import reach for, handed to
/// them by `ContentModule` as lookups on the container the user signed in
/// under.
library;

import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/import/import_links.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/pipelines/instagram_pipeline.dart';
import 'package:butlery/services/import/pipelines/tiktok_pipeline.dart';
import 'package:butlery/services/import/youtube/youtube_import_strategy.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/services/parsing/recipe_parser_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';

abstract final class ImportRegistrations {
  static ImportLinks links(GetIt container) => ImportLinks(
    youtube: () => container<YouTubeImportStrategy>(),
    tiktok: () => container<TikTokPipeline>(),
    instagram: () => container<InstagramPipeline>(),
    rateLimiter: () => container<ImportRateLimiter>(),
    tagging: () => container<TaggingService>(),
    analytics: () => _ifRegistered<AnalyticsService>(container),
    httpClient: () => _ifRegistered<http.Client>(container),
    recipeParser: () => container<RecipeParserService>(),
    parsedRecipeCache: () => _ifRegistered<ParsedRecipeCache>(container),
    llmEnhancement: () => container<LlmEnhancementService>(),
  );

  static T? _ifRegistered<T extends Object>(GetIt container) =>
      container.isRegistered<T>() ? container<T>() : null;
}
