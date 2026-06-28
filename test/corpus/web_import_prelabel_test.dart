/// Prelabel harness for the web-import ground-truth eval.
///
/// A *script shaped as a test* — NOT a CI test. Double-guarded:
///   1. Tagged `corpus-tools` (excluded by the default tag config).
///   2. Skips at runtime unless `RUN_IMPORT_EVAL=1`.
///
/// Per fixture in `<corpus>/web/<slug>/` (each holding `page.html` + `url.txt`):
///   1. Feed the saved HTML to the REAL URL import pipeline via the injectable
///      `MockClient` seam — no network, no Firebase. `ServiceLocator` is left
///      uninitialized so the paid LLM tiers never fire: the eval measures the
///      DETERMINISTIC parse quality before any LLM fallback.
///   2. Write `draft.json` (the prediction) and seed `gold.json`
///      (`verified:false`, corrected by hand and flipped to true).
///
/// On first run it BOOTSTRAPS a starter set of fixtures from the inline
/// Swedish-site HTML already in `test/fixtures/swedish_sites/`, so the eval has
/// real coverage with no new labeling. Add real URLs by dropping a
/// `page.html` + `url.txt` into a new `<corpus>/web/<slug>/` dir.
///
/// Run it:
///   RUN_IMPORT_EVAL=1 flutter test test/corpus/web_import_prelabel_test.dart
@Tags(['corpus-tools'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/url_import_strategy.dart';

import '../../tools/corpus/corpus_models.dart';
import '../../tools/corpus/corpus_paths.dart';
import '../fixtures/swedish_sites/arla_test_data.dart';
import '../fixtures/swedish_sites/ica_test_data.dart';
import '../fixtures/swedish_sites/koket_test_data.dart';
import '../fixtures/swedish_sites/recept_test_data.dart';

const _enabled = bool.fromEnvironment('dart.vm.product') ? false : true;
bool get _shouldRun =>
    _enabled && Platform.environment['RUN_IMPORT_EVAL'] == '1';

/// Starter fixtures materialized on first run (slug → real URL + saved HTML).
const Map<String, ({String url, String html})> _bootstrap = {
  'ica-kottbullar': (
    url: 'https://www.ica.se/recept/kottbullar/',
    html: IcaTestFixtures.kottbullarComplete,
  ),
  'arla-chokladbollar': (
    url: 'https://www.arla.se/recept/chokladbollar/',
    html: ArlaTestFixtures.chokladbollarComplete,
  ),
  'koket-kottbullar': (
    url: 'https://www.koket.se/kottbullar',
    html: KoketTestFixtures.kottbullarProfessional,
  ),
  'recept-kanelbullar': (
    url: 'https://www.recept.se/recept/kanelbullar',
    html: ReceptTestFixtures.kanelbullarComplete,
  ),
};

void main() {
  test(
    'web import prelabel: parse saved HTML into draft/gold seeds',
    () async {
      final paths = CorpusPaths.resolve();
      if (!paths.exists) {
        fail('Corpus root not found: ${paths.root}. Set BUTLERY_CORPUS_DIR.');
      }
      // `_web` (underscore-prefixed) so the cookbook OCR eval never scores web
      // fixtures as a book — its CorpusPaths.books() skips `_`-prefixed dirs.
      final webRoot = Directory('${paths.root}/_web')
        ..createSync(recursive: true);

      _bootstrapFixtures(webRoot);

      var processed = 0;
      var failed = 0;

      for (final slugDir in webRoot.listSync().whereType<Directory>()) {
        final slug = _basename(slugDir.path);
        final pageFile = File('${slugDir.path}/page.html');
        if (!pageFile.existsSync()) continue;

        final url = _readUrl(slugDir.path);
        final html = pageFile.readAsStringSync();

        final strategy = UrlImportStrategy(
          httpClient: MockClient(
            (req) async => http.Response(
              html,
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            ),
          ),
          // Keep the SSRF/DNS-rebinding gate happy offline: resolve every host
          // to a public address so no real DNS lookup happens.
          dnsLookup: (host) async => [InternetAddress('8.8.8.8')],
        );

        final result = await strategy.import(url);
        final recipe = result.recipe;
        if (recipe == null) {
          failed++;
          stderr.writeln('No recipe parsed for web/$slug');
          continue;
        }

        final draft = _recipeToGold(recipe);
        // draft.json = latest prediction (always overwritten so it tracks the
        // current parser); gold.json = human ground truth (seeded once below,
        // then owned by the labeler — never clobbered on re-run).
        File(
          '${slugDir.path}/draft.json',
        ).writeAsStringSync(encodeJsonPretty(draft.toJson()));
        final goldFile = File('${slugDir.path}/gold.json');
        if (!goldFile.existsSync()) {
          goldFile.writeAsStringSync(
            encodeJsonPretty(draft.copyWith(verified: false).toJson()),
          );
        }
        processed++;
        stdout.writeln(
          'Parsed web/$slug: "${recipe.title}" '
          '(${recipe.structuredIngredients.length} ingredients)',
        );
      }

      stdout.writeln('Web prelabel done: $processed parsed, $failed failures.');
    },
    skip: _shouldRun
        ? false
        : 'set RUN_IMPORT_EVAL=1 to run the web prelabel batch',
  );
}

void _bootstrapFixtures(Directory webRoot) {
  _bootstrap.forEach((slug, fx) {
    final dir = Directory('${webRoot.path}/$slug')..createSync(recursive: true);
    final page = File('${dir.path}/page.html');
    if (!page.existsSync()) {
      page.writeAsStringSync(fx.html);
      File('${dir.path}/url.txt').writeAsStringSync(fx.url);
    }
  });
}

String _readUrl(String slugDirPath) {
  final f = File('$slugDirPath/url.txt');
  return f.existsSync()
      ? f.readAsStringSync().trim()
      : 'https://example.com/recipe';
}

GoldRecipe _recipeToGold(Recipe recipe) => GoldRecipe(
  verified: false,
  title: recipe.title,
  portions: recipe.portions?.toString(),
  timeMinutes: recipe.timeMinutes,
  ingredients: _ingredients(recipe),
  instructions: recipe.instructions,
  sourcePages: const ['page.html'],
);

/// Prefer the parser's STRUCTURED ingredients (so ingredient full-F1 is
/// meaningful); fall back to raw lines when structure is absent.
List<GoldIngredient> _ingredients(Recipe recipe) {
  final structured = recipe.structuredIngredients;
  if (structured.isNotEmpty) {
    return structured.map(_fromStructured).toList();
  }
  return recipe.ingredients
      .map((line) => GoldIngredient(name: line, originalLine: line))
      .toList();
}

GoldIngredient _fromStructured(RecipeIngredient i) => GoldIngredient(
  name: i.name,
  originalLine: i.raw.isEmpty ? i.name : i.raw,
  quantity: i.amount?.toString(),
  unit: i.unit,
  preparation: i.note,
);

String _basename(String p) {
  final cleaned = p.replaceAll('\\', '/');
  final i = cleaned.lastIndexOf('/');
  return i < 0 ? cleaned : cleaned.substring(i + 1);
}
