/// BUT-1508: the recipe parser gets its cache store and its analytics tracker
/// from `ContentModule` as links. A parser built without them would fail
/// `init()` or silently stop reporting tier outcomes.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/cache/cache_dao_interface.dart';
import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/repositories/site_config_repository.dart';
import 'package:butlery/services/analytics/trackers/parse_events_tracker.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/parsing/line_classifier/neural_line_classifier.dart';
import 'package:butlery/services/parsing/recipe_parser_service.dart';

class _Auth extends Mock implements FirebaseAuthRepository {}

class _SiteConfigs extends Mock implements SiteConfigRepository {}

class _Classifier extends Mock implements NeuralLineClassifier {}

class _Offline extends Mock implements OfflineService {}

class _Database extends Mock implements AppDatabase {}

class _CacheDao extends Mock implements CacheDao {}

class _Analytics extends Mock implements AnalyticsService {}

class _ParseTracker extends Fake implements ParseEventsTracker {
  int reported = 0;

  @override
  Future<void> logTierSucceeded({
    required String tier,
    required int durationMs,
    required String platformBucket,
    String? sessionId,
  }) async => reported++;

  @override
  Future<void> logTierFailed({
    required String tier,
    required int durationMs,
    required String platformBucket,
    String? sessionId,
  }) async => reported++;
}

class _Llm extends Mock implements LlmService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GetIt userScope;
  late _Offline offline;
  late _CacheDao cacheDao;
  late _Analytics analytics;
  late _ParseTracker tracker;

  setUp(() {
    final app = GetIt.instance;
    final database = _Database();
    cacheDao = _CacheDao();
    offline = _Offline();
    when(() => offline.database).thenReturn(database);
    when(() => database.cacheDao).thenReturn(cacheDao);
    tracker = _ParseTracker();
    analytics = _Analytics();
    when(() => analytics.parse).thenReturn(tracker);

    final siteConfigs = _SiteConfigs();
    when(siteConfigs.ensureDefaultConfigs).thenAnswer((_) async {});
    final classifier = _Classifier();
    when(classifier.ensureInitialized).thenAnswer((_) async => false);

    app
      ..registerSingleton<auth.AuthRepository>(_Auth())
      ..registerSingleton<SiteConfigRepository>(siteConfigs)
      ..registerSingleton<NeuralLineClassifier>(classifier)
      ..registerSingleton<OfflineService>(offline)
      ..registerSingleton<AnalyticsService>(analytics);
    userScope = GetIt.asNewInstance();
  });

  tearDown(() async {
    await userScope.reset();
    final app = GetIt.instance;
    await app.unregister<auth.AuthRepository>();
    await app.unregister<SiteConfigRepository>();
    await app.unregister<NeuralLineClassifier>();
    await app.unregister<OfflineService>();
    await app.unregister<AnalyticsService>();
    await app.unregister<IngredientParsingStrategy>();
  });

  Future<RecipeParserService> buildParser() async {
    GetIt.instance.registerSingleton<IngredientParsingStrategy>(
      IngredientParsingStrategy(),
    );
    await ContentModule().configureUserScope(userScope);
    await userScope.unregister<LlmService>();
    userScope.registerSingleton<LlmService>(_Llm());
    return userScope<RecipeParserService>();
  }

  test(
    'init builds the parse cache on the offline store\'s cache dao',
    () async {
      final parser = await buildParser();

      await parser.init();

      verify(() => offline.database).called(1);
    },
  );

  test(
    'a parse reports its tier outcome through the analytics service',
    () async {
      final parser = await buildParser();
      await parser.init();

      await parser.parseFromText(
        text:
            'Pannkakor\n\nIngredienser\n2 dl mjölk\n1 ägg\n\nGör så här\nVispa.',
        useLlm: false,
      );

      expect(tracker.reported, greaterThan(0));
    },
  );
}
