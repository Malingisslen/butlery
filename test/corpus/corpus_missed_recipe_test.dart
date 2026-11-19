/// Corpus measurement for the "Det verkar finnas fler recept på sidan" card:
/// how often would it show on a page that holds ONE recipe (an unneeded card)
/// and on a page where the phone returned fewer recipes than the page holds
/// (a card that helps)?
///
///   flutter test test/corpus/corpus_missed_recipe_test.dart
///   with RUN_CORPUS_MISSED=1 in the environment
///   (BUTLERY_CORPUS_DIR=/path/to/corpus to point elsewhere)
///
/// A Flutter test rather than an arm of `tools/corpus_split_eval.dart`, because
/// one of the card's signals is a block the PARSER rejected, and the parser
/// needs the app's DI. It calls the same `ImportManager.autoParseMulti` and the
/// same `missed_recipe_check.dart` functions the photo screen calls, with
/// `reflow: true` as the page path does.
///
/// The answer key is the verified gold entries per page, minus `frameCut:
/// fragment` entries (a sliver of the next recipe is not a recipe the user
/// wants, so a card for it would be unneeded). Never the splitter's own output.
///
/// Each input is scored separately: the stored `ocr.txt`, and, for pages that
/// have one, the text of the ML Kit capture (`layout-mlkit.json`). Both stand
/// in for what the phone reads; neither is the phone. No geometry is passed,
/// matching the code default of `enable_layout_recipe_split`.
@Tags(['corpus-tools'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/layout/line_reflow.dart';
import 'package:butlery/services/import/layout/page_reflow.dart';
import 'package:butlery/services/import/missed_recipe_check.dart';
import 'package:butlery/services/import/multi_recipe_splitter.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';

import '../../tools/corpus/corpus_paths.dart';
import '../infrastructure/di/test_service_locator.dart';

bool get _shouldRun => Platform.environment['RUN_CORPUS_MISSED'] == '1';

class _NoopPersonalOps extends Mock implements PersonalRecipeOperations {}

class _Page {
  final String book;
  final String imageId;
  final int gold;
  final String text;
  const _Page(this.book, this.imageId, this.gold, this.text);
}

class _Outcome {
  final _Page page;
  final int found;
  final int textCandidates;
  final int blocksTried;
  const _Outcome(this.page, this.found, this.textCandidates, this.blocksTried);

  bool alarm({required bool useText, required bool useBlocks}) =>
      mayHaveMissedRecipes(
        found: found,
        candidates: candidateRecipeCount(
          textCandidates: useText ? textCandidates : 0,
          blocksTried: useBlocks ? blocksTried : 0,
        ),
      );

  Map<String, dynamic> toJson() => {
    'book': page.book,
    'page': page.imageId,
    'gold': page.gold,
    'found': found,
    'textCandidates': textCandidates,
    'blocksTried': blocksTried,
  };
}

Map<String, dynamic>? _readJson(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  try {
    final decoded = jsonDecode(f.readAsStringSync());
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

/// Pages with verified gold, keyed `book/imageId`, valued by the number of
/// verified entries that are not frame-cut fragments.
Map<String, int> _goldCounts(CorpusPaths paths, List<String> books) {
  final counts = <String, int>{};
  for (final book in books) {
    for (final entry in paths.recipeEntries(book)) {
      final gold = _readJson(entry.goldPath);
      if (gold == null || gold['verified'] != true) continue;
      final key = '$book/${entry.imageId}';
      counts.putIfAbsent(key, () => 0);
      if (gold['frameCut'] == 'fragment') continue;
      counts[key] = counts[key]! + 1;
    }
  }
  return counts;
}

String? _ocrTextOf(CorpusPaths paths, String book, String imageId) {
  final f = File(paths.ocrText(book, imageId));
  return f.existsSync() ? f.readAsStringSync() : null;
}

String? _mlkitTextOf(CorpusPaths paths, String book, String imageId) {
  final m = _readJson(paths.ocrLayout(book, imageId, engine: 'mlkit'));
  if (m == null) return null;
  try {
    final page = PageLayout.fromJson(m);
    if (page.lines.isEmpty) return null;
    return DocumentLayout([page]).text;
  } catch (_) {
    return null;
  }
}

/// The text the photo screen parses for one page: the same page preparation
/// `recombineAndParse` runs before `autoParseOcrText`.
String _asPhotoPage(String text) => prepareScreenPages([PageText(text)]).text;

String _pct(int n, int of) =>
    of == 0 ? '-' : '${(100 * n / of).toStringAsFixed(1)} % ($n av $of)';

String _report(String label, List<_Outcome> outcomes) {
  final single = outcomes.where((o) => o.page.gold == 1).toList();
  final short = outcomes.where((o) => o.found < o.page.gold).toList();
  final multiComplete = outcomes
      .where((o) => o.page.gold > 1 && o.found >= o.page.gold)
      .toList();
  final b = StringBuffer()
    ..writeln('== $label: ${outcomes.length} sidor ==')
    ..writeln(
      '  sidor med ett recept: ${single.length}, '
      'sidor där telefonen fick för få: ${short.length}, '
      'sidor med flera recept som redan blev rätt: ${multiComplete.length}',
    );
  for (final (name, useText, useBlocks) in [
    ('textsignalen', true, false),
    ('kasserade block', false, true),
    ('båda (största värdet)', true, true),
  ]) {
    bool a(_Outcome o) => o.alarm(useText: useText, useBlocks: useBlocks);
    b
      ..writeln('  $name:')
      ..writeln(
        '    onödigt kort, ett recept: ${_pct(single.where(a).length, single.length)}',
      )
      ..writeln(
        '    onödigt kort, flera redan rätt: '
        '${_pct(multiComplete.where(a).length, multiComplete.length)}',
      )
      ..writeln(
        '    kort när något saknades: ${_pct(short.where(a).length, short.length)}',
      );
  }
  // Which single-recipe pages raise the combined card, so a rule can be
  // tightened against named pages and the photographs opened.
  final falseAlarms = single.where(
    (o) => o.alarm(useText: true, useBlocks: true),
  );
  for (final o in falseAlarms) {
    b.writeln(
      '    onödigt: ${o.page.book}/${o.page.imageId} '
      'hittade ${o.found}, text ${o.textCandidates}, block ${o.blocksTried}',
    );
  }
  return b.toString();
}

void main() {
  setUpAll(() async {
    if (!_shouldRun) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestServiceLocator.initialize();
  });

  test(
    'missed-recipe card: unneeded and helpful cards over the corpus',
    () async {
      final paths = CorpusPaths.resolve();
      if (!paths.exists) fail('Corpus root not found: ${paths.root}.');

      final books = paths
          .books()
          .map((d) => d.path.replaceAll('\\', '/').split('/').last)
          .toList();
      final gold = _goldCounts(paths, books);
      final manager = ImportManager(_NoopPersonalOps());

      Future<_Outcome> score(_Page page) async {
        final result = await manager.autoParseMulti(
          page.text,
          // Pure measurement: no quota check and no parse event per page.
          channel: null,
          reflow: true,
        );
        return _Outcome(
          page,
          result.successfulRecipes.length,
          MultiRecipeSplitter.countCandidates(reflowWrappedLines(page.text)),
          result.totalProcessed,
        );
      }

      final byInput = <String, List<_Outcome>>{'ocr.txt': [], 'ML Kit': []};
      var noAnswerKey = 0;
      for (final MapEntry(key: key, value: count) in gold.entries) {
        if (count == 0) {
          noAnswerKey++;
          continue;
        }
        final [book, imageId] = key.split('/');
        final ocr = _ocrTextOf(paths, book, imageId);
        if (ocr != null) {
          byInput['ocr.txt']!.add(
            await score(_Page(book, imageId, count, _asPhotoPage(ocr))),
          );
        }
        final mlkit = _mlkitTextOf(paths, book, imageId);
        if (mlkit != null) {
          byInput['ML Kit']!.add(
            await score(_Page(book, imageId, count, _asPhotoPage(mlkit))),
          );
        }
      }

      final text = StringBuffer()
        ..writeln('Korpus: ${paths.root}')
        ..writeln(
          'Sidor utan annat än fragment i facit (hoppade): $noAnswerKey',
        )
        ..writeln(
          'Ersättnings-OCR: varken ocr.txt eller ML Kit-fångsten är '
          'telefonens egen läsning i appen.',
        );
      for (final MapEntry(key: label, value: outcomes) in byInput.entries) {
        text.writeln(_report(label, outcomes));
      }
      // ignore: avoid_print
      print(text);

      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      final out = File('${paths.reportsDir()}/missed-recipe-$ts.json');
      out.parent.createSync(recursive: true);
      out.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          for (final e in byInput.entries)
            e.key: e.value.map((o) => o.toJson()).toList(),
        }),
      );
      // ignore: avoid_print
      print('Rapport: ${out.path}');
    },
    skip: _shouldRun ? false : 'set RUN_CORPUS_MISSED=1 to run',
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
