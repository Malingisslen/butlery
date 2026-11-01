/// BUT-1508: the import manager, the URL import and the AI fallback get their
/// services from `ContentModule`, as lookups on the container the user signed
/// in under. Every service sits only in that container (never in
/// `GetIt.instance`), so a link that reaches for the global locator or for a
/// different service finds nothing, or the wrong object.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/di/modules/import_registrations.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/pipelines/instagram_pipeline.dart';
import 'package:butlery/services/import/pipelines/tiktok_pipeline.dart';
import 'package:butlery/services/import/youtube/youtube_import_strategy.dart';
import 'package:butlery/services/parsing/cache/parsed_recipe_cache.dart';
import 'package:butlery/services/parsing/recipe_parser_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/services/import/parser_shadow_sampler.dart';

class _YouTube extends Mock implements YouTubeImportStrategy {}

class _TikTok extends Mock implements TikTokPipeline {}

class _Instagram extends Mock implements InstagramPipeline {}

class _Limiter extends Mock implements ImportRateLimiter {}

class _Tagging extends Mock implements TaggingService {}

class _Analytics extends Mock implements AnalyticsService {}

class _Client extends Mock implements http.Client {}

class _Parser extends Mock implements RecipeParserService {}

class _Llm extends Mock implements LlmEnhancementService {}

class _Recipes extends Mock implements UnifiedRecipeService {}

class _Personal extends Mock implements PersonalRecipeOperations {}

class _Sampler extends Mock implements ParserShadowSampler {}

void main() {
  late GetIt userScope;
  late _YouTube youtube;
  late _TikTok tiktok;
  late _Instagram instagram;
  late _Limiter limiter;
  late _Tagging tagging;
  late _Analytics analytics;
  late _Client client;
  late _Parser parser;
  late ParsedRecipeCache cache;
  late _Llm llm;

  setUp(() {
    userScope = GetIt.asNewInstance();
    youtube = _YouTube();
    tiktok = _TikTok();
    instagram = _Instagram();
    limiter = _Limiter();
    tagging = _Tagging();
    analytics = _Analytics();
    client = _Client();
    parser = _Parser();
    cache = ParsedRecipeCache();
    llm = _Llm();
    userScope
      ..registerSingleton<YouTubeImportStrategy>(youtube)
      ..registerSingleton<TikTokPipeline>(tiktok)
      ..registerSingleton<InstagramPipeline>(instagram)
      ..registerSingleton<ImportRateLimiter>(limiter)
      ..registerSingleton<TaggingService>(tagging)
      ..registerSingleton<AnalyticsService>(analytics)
      ..registerSingleton<http.Client>(client)
      ..registerSingleton<RecipeParserService>(parser)
      ..registerSingleton<ParsedRecipeCache>(cache)
      ..registerSingleton<LlmEnhancementService>(llm);
  });

  tearDown(() async {
    await userScope.reset();
    await GetIt.instance.reset();
  });

  test('each link reaches the service of the signed-in container', () {
    final links = ImportRegistrations.links(userScope);

    expect(links.youtube(), same(youtube));
    expect(links.tiktok(), same(tiktok));
    expect(links.instagram(), same(instagram));
    expect(links.rateLimiter(), same(limiter));
    expect(links.tagging(), same(tagging));
    expect(links.analytics(), same(analytics));
    expect(links.httpClient(), same(client));
    expect(links.recipeParser(), same(parser));
    expect(links.parsedRecipeCache(), same(cache));
    expect(links.llmEnhancement(), same(llm));
  });

  test(
    'the optional services are null until registered, never a throw',
    () async {
      final bare = GetIt.asNewInstance();
      addTearDown(bare.reset);
      final links = ImportRegistrations.links(bare);

      expect(links.analytics(), isNull);
      expect(links.httpClient(), isNull);
      expect(links.parsedRecipeCache(), isNull);
    },
  );

  test('ContentModule builds the import manager with those links', () async {
    final scope = GetIt.asNewInstance();
    addTearDown(scope.reset);
    await ContentModule().configureUserScope(scope);
    // The module registered its own versions of some of these lazily; the
    // fakes replace them before anything resolves.
    void swap<T extends Object>(T fake) {
      if (scope.isRegistered<T>()) scope.unregister<T>();
      scope.registerSingleton<T>(fake);
    }

    swap<UnifiedRecipeService>(_stubRecipes());
    swap<ParserShadowSampler>(_Sampler());
    swap<YouTubeImportStrategy>(youtube);
    swap<TikTokPipeline>(tiktok);
    swap<InstagramPipeline>(instagram);
    swap<ImportRateLimiter>(limiter);
    swap<TaggingService>(tagging);
    swap<AnalyticsService>(analytics);
    swap<http.Client>(client);
    swap<RecipeParserService>(parser);
    swap<ParsedRecipeCache>(cache);
    swap<LlmEnhancementService>(llm);

    final manager = scope<ImportManager>();

    expect(manager.links.youtube(), same(youtube));
    expect(manager.links.tiktok(), same(tiktok));
    expect(manager.links.instagram(), same(instagram));
    expect(manager.links.rateLimiter(), same(limiter));
    expect(manager.links.tagging(), same(tagging));
    expect(manager.links.analytics(), same(analytics));
    expect(manager.links.httpClient(), same(client));
    expect(manager.links.recipeParser(), same(parser));
    expect(manager.links.parsedRecipeCache(), same(cache));
    expect(manager.links.llmEnhancement(), same(llm));
  });
}

UnifiedRecipeService _stubRecipes() {
  final recipes = _Recipes();
  when(() => recipes.personal).thenReturn(_Personal());
  return recipes;
}
