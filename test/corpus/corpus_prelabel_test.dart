/// Prelabel harness for the cookbook gold corpus.
///
/// This is a *script shaped as a test* (it needs the Flutter asset bundle for
/// CRF weights + the app DI for the parser) — NOT a CI test. It is double-
/// guarded so a normal `flutter test` never runs it:
///   1. Tagged `corpus-tools` (excluded by the default tag config).
///   2. Skips at runtime unless `RUN_CORPUS_PRELABEL=1`.
///
/// What it does, per image in `<book>/inbox/`:
///   1. OCR the image (OCRExtractionService) → page-NN.jpg + ocr.txt + ocr.meta.json
///   2. Parse the text (ImportManager.autoParseOnly) → title/portions/time/steps
///   3. Structure each ingredient line (IngredientParsingStrategy.parseLine)
///   4. Write draft.json (the parser's prediction) + a gold.json seed
///      (verified:false copy you then correct by hand and flip to true)
///
/// Run it:
///   RUN_CORPUS_PRELABEL=1 BUTLERY_CORPUS_DIR=/path/to/corpus \
///     flutter test test/corpus/corpus_prelabel_test.dart \
///     --dart-define=OCR_SPACE_API_KEY=... --dart-define=GOOGLE_VISION_API_KEY=...
///
/// OCR needs the API keys above (passed as dart-defines, same as the app). A
/// page whose OCR fails is recorded in ocr.meta.json and skipped — the batch
/// never aborts.
@Tags(['corpus-tools'])
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';

import '../../tools/corpus/corpus_models.dart';
import '../../tools/corpus/corpus_paths.dart';
import '../infrastructure/di/test_service_locator.dart';

const _enabled = bool.fromEnvironment('dart.vm.product') ? false : true;

bool get _shouldRun =>
    _enabled && Platform.environment['RUN_CORPUS_PRELABEL'] == '1';

/// Parse-only never saves, so [ImportManager]'s save dependency is never
/// invoked — a bare mock satisfies the constructor without real DI weight.
class _NoopPersonalOps extends Mock implements PersonalRecipeOperations {}

void main() {
  setUpAll(() async {
    // Skip heavy DI + OCR init entirely on a normal `flutter test` run — the
    // body is skipped anyway, and this keeps CI fast and side-effect-free.
    if (!_shouldRun) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    await TestServiceLocator.initialize();
    await OCRExtractionService.instance.initialize();
  });

  test('prelabel: OCR + parse every inbox image into draft/gold seeds',
      () async {
    final paths = CorpusPaths.resolve();
    if (!paths.exists) {
      fail('Corpus root not found: ${paths.root}. '
          'Create it or set BUTLERY_CORPUS_DIR.');
    }

    final importManager = ImportManager(_NoopPersonalOps());
    final ingredientParser = IngredientParsingStrategy();

    var processed = 0;
    var failed = 0;

    for (final bookDir in paths.books()) {
      final bookSlug = _basename(bookDir.path);
      final inbox = Directory(paths.inbox(bookSlug));
      if (!inbox.existsSync()) continue;

      final images = inbox
          .listSync()
          .whereType<File>()
          .where((f) => _isImage(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      for (final image in images) {
        final recipeId = _recipeIdFor(image.path);
        final recipeDir = Directory(paths.recipe(bookSlug, recipeId));
        recipeDir.createSync(recursive: true);

        final bytes = await image.readAsBytes();
        await File('${recipeDir.path}/page-01.jpg').writeAsBytes(bytes);

        final ocr = await _runOcr(bytes);
        File(paths.ocrText(bookSlug, recipeId)).writeAsStringSync(ocr.text);
        File(paths.ocrMeta(bookSlug, recipeId))
            .writeAsStringSync(encodeJsonPretty(ocr.meta.toJson()));

        if (ocr.meta.isFailure || ocr.text.trim().isEmpty) {
          failed++;
          stderr
              .writeln('OCR failed for $bookSlug/$recipeId: ${ocr.meta.error}');
          // Leave the image in inbox-equivalent state (page-01.jpg kept) so it
          // can be retried; no draft written.
          continue;
        }

        final draft = await _parseToDraft(
          importManager,
          ingredientParser,
          ocr.text,
        );

        File(paths.draft(bookSlug, recipeId))
            .writeAsStringSync(encodeJsonPretty(draft.toJson()));

        // Seed gold.json from the draft ONLY if it doesn't exist yet — never
        // clobber human corrections on a re-run.
        final goldFile = File(paths.gold(bookSlug, recipeId));
        if (!goldFile.existsSync()) {
          goldFile.writeAsStringSync(
            encodeJsonPretty(draft.copyWith(verified: false).toJson()),
          );
        }

        processed++;
        stdout.writeln('Prelabeled $bookSlug/$recipeId '
            '(${draft.ingredients.length} ingredients, '
            '${draft.instructions.length} steps)');
      }
    }

    stdout
        .writeln('Prelabel done: $processed processed, $failed OCR failures.');
  },
      skip: _shouldRun
          ? false
          : 'set RUN_CORPUS_PRELABEL=1 to run the prelabel batch');
}

class _OcrOutcome {
  final String text;
  final OcrMeta meta;
  const _OcrOutcome(this.text, this.meta);
}

Future<_OcrOutcome> _runOcr(Uint8List bytes) async {
  // Timestamp is read once here; the corpus is not resumable so this is safe
  // (unlike workflow scripts, plain tests may call DateTime.now()).
  final ts = DateTime.now().toIso8601String();
  try {
    final result = await OCRExtractionService.instance.extractText(bytes);
    final ok = result.isSuccessful && result.text.isNotEmpty;
    return _OcrOutcome(
      result.text,
      OcrMeta(
        provider: result.metadata['provider']?.toString() ?? 'unknown',
        confidence: result.confidence,
        timestampIso: ts,
        error: ok ? null : 'no text extracted',
      ),
    );
  } catch (e) {
    return _OcrOutcome(
      '',
      OcrMeta(provider: 'unknown', timestampIso: ts, error: e.toString()),
    );
  }
}

Future<GoldRecipe> _parseToDraft(
  ImportManager importManager,
  IngredientParsingStrategy ingredientParser,
  String ocrText,
) async {
  Recipe? recipe;
  try {
    final result = await importManager.autoParseOnly(ocrText);
    if (result.isSuccess && result.importedRecipes.isNotEmpty) {
      recipe = result.importedRecipes.first;
    }
  } catch (_) {
    // Fall through to a title-only draft below.
  }

  final title = recipe?.title ?? _firstNonEmptyLine(ocrText);
  final rawIngredients = recipe?.ingredients ?? const <String>[];
  final instructions = recipe?.instructions ?? const <String>[];

  final ingredients = <GoldIngredient>[];
  for (final line in rawIngredients) {
    ingredients.add(await _structureLine(ingredientParser, line));
  }

  return GoldRecipe(
    verified: false,
    title: title,
    portions: recipe?.portions?.toString(),
    timeMinutes: _totalTime(recipe),
    ingredients: ingredients,
    instructions: instructions,
    sourcePages: const ['page-01.jpg'],
  );
}

Future<GoldIngredient> _structureLine(
  IngredientParsingStrategy parser,
  String line,
) async {
  try {
    final p = await parser.parseLine(line);
    return GoldIngredient(
      name: p.name.isEmpty ? line : p.name,
      originalLine: p.originalLine.isEmpty ? line : p.originalLine,
      quantity: p.quantity,
      unit: p.unit,
      size: p.size,
      preparation: p.preparation,
    );
  } catch (_) {
    // Structuring is best-effort; a name-only ingredient is still a usable seed.
    return GoldIngredient(name: line, originalLine: line);
  }
}

int? _totalTime(Recipe? r) {
  if (r == null) return null;
  final prep = r.prepTimeMinutes ?? 0;
  final cook = r.cookTimeMinutes ?? 0;
  final total = prep + cook;
  return total > 0 ? total : null;
}

String _firstNonEmptyLine(String text) => text
    .split('\n')
    .map((l) => l.trim())
    .firstWhere((l) => l.isNotEmpty, orElse: () => 'Namnlöst recept');

bool _isImage(String path) {
  final p = path.toLowerCase();
  return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png');
}

String _basename(String p) {
  final cleaned = p.replaceAll('\\', '/');
  final i = cleaned.lastIndexOf('/');
  return i < 0 ? cleaned : cleaned.substring(i + 1);
}

/// Stable recipe id from the image filename (e.g. `scan_007.jpg` → `scan_007`).
String _recipeIdFor(String imagePath) {
  final base = _basename(imagePath);
  final dot = base.lastIndexOf('.');
  final stem = dot < 0 ? base : base.substring(0, dot);
  return stem.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}
