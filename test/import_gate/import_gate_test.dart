/// The import gate (BUT-2236): two corpora kept in the repo, run through the
/// real import strategies with no network and no AI, scored against gold and
/// held to the floors in `floors.json`.
///
///   flutter test test/import_gate/
///
/// - `sites/`: site pages in the form ADR-0012 allows (real structure and real
///   ingredient rows, placeholder title and steps), fed to [UrlImportStrategy]
///   through a [MockClient]. The parser service is wired as the app wires it,
///   with the built-in site configs (Firestore is a fake, so no stored ones).
/// - `text/`: thirty pasted Swedish recipes fed to [TextImportStrategy], the
///   parser photo and voice end in too.
///
/// Every AI seam is a counting fake and every real socket is refused and
/// counted, so "no AI" and "no network" are measured, not assumed.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/site_config_repository.dart';
import 'package:butlery/services/extraction/web_scraper.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/llm/llm_enhancement_service.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/parsing/recipe_parser_service.dart';

import '../unit/services/parsing/_fake_local_recipe_cache.dart';
import 'gate_scoring.dart';
import 'site_pages.dart';

const _gateDir = 'test/import_gate';

/// Counts every method call except the availability probe, so a fallback that
/// asks "may I?" and is told yes but then calls nothing still reads as zero.
mixin _CountsCalls on Mock {
  int calls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (invocation.isMethod &&
        !name.contains('isAvailable') &&
        !name.contains('dispose')) {
      calls++;
    }
    return super.noSuchMethod(invocation);
  }
}

class _CountingLlmService extends Mock
    with _CountsCalls
    implements LlmService {}

class _CountingLlmEnhancement extends Mock
    with _CountsCalls
    implements LlmEnhancementService {}

class _CountingWebScraper extends Mock
    with _CountsCalls
    implements WebScraper {}

class _RefuseNetwork extends HttpOverrides {
  int attempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    attempts++;
    throw const SocketException('import gate: network is not allowed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RefuseNetwork network;
  late _CountingLlmService llm;
  late _CountingLlmEnhancement llmEnhancement;
  var webScraperCalls = 0;
  final corpora = <CorpusScore>[];

  setUpAll(() async {
    network = _RefuseNetwork();
    HttpOverrides.global = network;

    llm = _CountingLlmService();
    llmEnhancement = _CountingLlmEnhancement();
    when(() => llmEnhancement.isAvailable()).thenAnswer((_) async => true);

    app_provider.ServiceLocator.reset();
    app_provider.ServiceLocator.initialize(DIContainer());
    final getIt = GetIt.instance;
    await getIt.reset();

    final ingredientStrategy = IngredientParsingStrategy();
    final parser = RecipeParserService(
      getCurrentUserId: () => 'import-gate',
      siteConfigRepository: SiteConfigRepository(
        firestore: FakeFirebaseFirestore(),
      ),
      llmService: llm,
      ingredientStrategy: ingredientStrategy,
      cache: FakeLocalRecipeCache(),
    );
    await parser.init();
    getIt
      ..registerSingleton<IngredientParsingStrategy>(ingredientStrategy)
      ..registerSingleton<RecipeParserService>(parser)
      ..registerSingleton<LlmEnhancementService>(llmEnhancement);
  });

  tearDownAll(() async {
    HttpOverrides.global = null;
    await GetIt.instance.reset();
    app_provider.ServiceLocator.reset();
  });

  int llmCallsNow() => llm.calls + llmEnhancement.calls;

  Produced produced(ImportResult result, int llmBefore) {
    final Recipe? recipe = result.recipe;
    return Produced(
      title: recipe?.title,
      ingredientLines: recipe?.ingredients ?? const [],
      steps: recipe?.instructions.length ?? 0,
      portions: recipe?.portions,
      timeMinutes: recipe?.timeMinutes,
      llmCalls: llmCallsNow() - llmBefore,
      failure: recipe == null ? (result.errorMessage ?? 'inget recept') : null,
    );
  }

  test('sites: real URL strategy over the site corpus', () async {
    final goldJson =
        jsonDecode(File(siteGoldPath).readAsStringSync())
            as Map<String, dynamic>;
    final scores = <RecipeScore>[];
    for (final entry in goldJson.entries) {
      final j = entry.value as Map<String, dynamic>;
      final source = j['source'] as String;
      final html = sitePageHtml(source);
      final url = j['url'] as String;

      final strategy = UrlImportStrategy(
        httpClient: MockClient(
          (req) async => req.url.toString() == url
              ? http.Response(
                  html,
                  200,
                  headers: {'content-type': 'text/html; charset=utf-8'},
                )
              : http.Response('', 404),
        ),
        webScraperFactory: () {
          final s = _CountingWebScraper();
          webScraperCalls++;
          return s;
        },
        dnsLookup: (host) async => [InternetAddress('8.8.8.8')],
      );
      final before = llmCallsNow();
      final result = await strategy.import(url);
      scores.add(
        scoreRecipe(
          GoldRecipe.fromJson(entry.key, j),
          produced(result, before),
        ),
      );
    }
    corpora.add(CorpusScore('sites', scores));
  });

  test('text: TextImportStrategy over the pasted-text corpus', () async {
    final files =
        Directory('$_gateDir/text')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.txt'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, hasLength(30), reason: 'provsamling 2 ska ha 30 recept');

    final strategy = TextImportStrategy();
    final scores = <RecipeScore>[];
    for (final f in files) {
      final stem = f.path.substring(0, f.path.length - '.txt'.length);
      final id = stem.split('/').last;
      final gold = GoldRecipe.fromJson(
        id,
        jsonDecode(File('$stem.gold.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      final before = llmCallsNow();
      final result = await strategy.import(f.readAsStringSync());
      scores.add(scoreRecipe(gold, produced(result, before)));
    }
    corpora.add(CorpusScore('text', scores));
  });

  test('floors hold', () {
    expect(corpora, hasLength(2), reason: 'båda provsamlingarna ska ha körts');
    final floors = Floors.read(File('$_gateDir/floors.json'));
    final report = formatReport(corpora, floors, network.attempts);
    // ignore: avoid_print
    print(report);
    // ignore: avoid_print
    print('Webbläsarhämtningar (fejkade, inget nät): $webScraperCalls');
    final summary = Platform.environment['GITHUB_STEP_SUMMARY'];
    if (summary != null && summary.isNotEmpty) {
      File(summary).writeAsStringSync(report, mode: FileMode.append);
    }

    final problems = <String>{
      for (final c in corpora)
        ...checkFloors(c, floors, networkCalls: network.attempts),
    }.toList();
    expect(problems, isEmpty, reason: problems.join('\n'));
  });
}
