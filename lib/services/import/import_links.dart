// BUT-1508: what the import manager and its URL strategy reach for while they
// run. Each is a lookup, not an instance: the services are user-scoped and
// replaced at sign-in, and a missing one means "skip that step", never a crash.
library;

import 'package:http/http.dart' as http;

import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/pipelines/instagram_pipeline.dart';
import 'package:butlery/services/import/pipelines/tiktok_pipeline.dart';
import 'package:butlery/services/import/youtube/youtube_import_strategy.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/services/parsing/recipe_parser_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';

T? _absent<T>() => null;

class ImportLinks {
  const ImportLinks({
    this.youtube = _absent,
    this.tiktok = _absent,
    this.instagram = _absent,
    this.rateLimiter = _absent,
    this.tagging = _absent,
    this.analytics = _absent,
    this.httpClient = _absent,
    this.recipeParser = _absent,
    this.parsedRecipeCache = _absent,
    this.llmEnhancement = _absent,
  });

  /// Nothing available: every step that needs a service is skipped.
  static const none = ImportLinks();

  final YouTubeImportStrategy? Function() youtube;
  final TikTokPipeline? Function() tiktok;
  final InstagramPipeline? Function() instagram;
  final ImportRateLimiter? Function() rateLimiter;
  final TaggingService? Function() tagging;
  final AnalyticsService? Function() analytics;
  final http.Client? Function() httpClient;
  final RecipeParserService? Function() recipeParser;
  final ParsedRecipeCache? Function() parsedRecipeCache;
  final LlmEnhancementService? Function() llmEnhancement;
}
