/// Re-derives the parser's drafts for every VERIFIED gold in the corpus from
/// the stored OCR text — no images, no OCR calls, no cost. This is the step
/// that turns "the parser changed" into new numbers; `tools/corpus_measure.dart`
/// runs it and then the eval.
///
/// Script shaped as a test (needs the Flutter asset bundle and the app DI for
/// the real parser), so it is guarded like the prelabel harness: tagged
/// `corpus-tools` and skipped unless `RUN_CORPUS_REDERIVE=1`.
///
/// Per page: parse the stored `ocr.txt` as the app would, then hand each
/// verified gold on the page the draft that holds the most of the same text.
/// A gold nothing resembles gets a `draft.missed.json` marker, never a blank
/// draft that would pass for parser output. Gold files are never written.
@Tags(['corpus-tools'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/parsing/ingredient_parsing_strategy.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';

import '../../tools/corpus/block_drafts.dart';
import '../../tools/corpus/corpus_models.dart';
import '../../tools/corpus/corpus_paths.dart';
import '../infrastructure/di/test_service_locator.dart';
import 'prelabel_parse.dart';

bool get _shouldRun => Platform.environment['RUN_CORPUS_REDERIVE'] == '1';

class _NoopPersonalOps extends Mock implements PersonalRecipeOperations {}

void main() {
  setUpAll(() async {
    if (!_shouldRun) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestServiceLocator.initialize();
  });

  test(
    're-derive drafts for every verified gold from stored OCR text',
    () async {
      final paths = CorpusPaths.resolve();
      if (!paths.exists) fail('Corpus root not found: ${paths.root}.');

      final importManager = ImportManager(_NoopPersonalOps());
      final ingredientParser = IngredientParsingStrategy();
      final log = <Map<String, dynamic>>[];
      var matched = 0;
      var missed = 0;

      for (final bookDir in paths.books()) {
        final book = bookDir.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
        final byPage = <String, List<RecipeEntry>>{};
        for (final e in paths.recipeEntries(book)) {
          byPage.putIfAbsent(e.imageId, () => []).add(e);
        }
        for (final page in byPage.entries) {
          final targets = <(RecipeEntry, GoldRecipe)>[];
          for (final e in page.value) {
            final gold = _readGold(e.goldPath);
            if (gold != null && gold.verified) targets.add((e, gold));
          }
          if (targets.isEmpty) continue;
          final ocrFile = File(page.value.first.ocrTextPath);
          // Pages without stored OCR (web recipes) keep the drafts their own
          // import harness wrote.
          if (!ocrFile.existsSync()) continue;
          final ocrText = ocrFile.readAsStringSync();
          if (ocrText.trim().isEmpty) continue;

          final drafts = await parseOcrToDrafts(
            importManager,
            ingredientParser,
            ocrText,
          );
          final assigned = assignDraftsToGolds([
            for (final t in targets) t.$2,
          ], drafts);

          for (var i = 0; i < targets.length; i++) {
            final entry = targets[i].$1;
            final match = assigned[i];
            final draftFile = File(entry.draftPath);
            final missedFile = File(entry.missedPath);
            if (match == null) {
              if (draftFile.existsSync()) draftFile.deleteSync();
              missedFile.writeAsStringSync(
                encodeJsonPretty({
                  'reason': 'no parser recipe resembles this gold',
                  'parserRecipes': drafts.length,
                  'goldsOnPage': targets.length,
                }),
              );
              missed++;
            } else {
              draftFile.writeAsStringSync(
                encodeJsonPretty(drafts[match.draftIndex].toJson()),
              );
              if (missedFile.existsSync()) missedFile.deleteSync();
              matched++;
            }
            log.add({
              'recipe': '$book/${entry.recipeId}',
              'parserRecipes': drafts.length,
              'goldsOnPage': targets.length,
              'similarity': match?.similarity,
              if (drafts.length == targets.length && match != null)
                'samePositionAsOrder': match.draftIndex == i,
            });
          }
        }
      }

      final reports = Directory(paths.reportsDir())..createSync();
      File('${reports.path}/rederive-last.json').writeAsStringSync(
        encodeJsonPretty({
          'matched': matched,
          'missed': missed,
          'entries': log,
        }),
      );
      stdout.writeln('Re-derive done: $matched matched, $missed missed.');
    },
    timeout: const Timeout(Duration(minutes: 30)),
    skip: _shouldRun ? false : 'set RUN_CORPUS_REDERIVE=1 to run the re-derive',
  );
}

GoldRecipe? _readGold(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  try {
    return GoldRecipe.fromJson(
      (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>(),
    );
  } catch (_) {
    return null;
  }
}
