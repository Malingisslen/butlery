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
/// Each input is scored separately: the stored `ocr.txt` without geometry,
/// and the text of each layout capture (`layout-mlkit.json`,
/// `layout-winocr.json`) WITH its geometry, as the photo screen passes ML Kit's
/// when `enable_layout_recipe_split` is on. Each stands in for what the phone
/// reads; none is the phone.
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
  final int tails;
  final String text;
  final DocumentLayout? layout;
  const _Page(
    this.book,
    this.imageId,
    this.gold,
    this.tails,
    this.text, [
    this.layout,
  ]);
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
    'tails': page.tails,
    'layout': page.layout != null,
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
/// verified entries that are not frame-cut fragments. [tails] gets, per page,
/// how many of those are `frameCut: tail`.
Map<String, int> _goldCounts(
  CorpusPaths paths,
  List<String> books,
  Map<String, int> tails,
) {
  final counts = <String, int>{};
  for (final book in books) {
    for (final entry in paths.recipeEntries(book)) {
      final gold = _readJson(entry.goldPath);
      if (gold == null || gold['verified'] != true) continue;
      final key = '$book/${entry.imageId}';
      counts.putIfAbsent(key, () => 0);
      if (gold['frameCut'] == 'fragment') continue;
      counts[key] = counts[key]! + 1;
      if (gold['frameCut'] == 'tail') tails[key] = (tails[key] ?? 0) + 1;
    }
  }
  return counts;
}

String? _ocrTextOf(CorpusPaths paths, String book, String imageId) {
  final f = File(paths.ocrText(book, imageId));
  return f.existsSync() ? f.readAsStringSync() : null;
}

PageLayout? _layoutOf(
  CorpusPaths paths,
  String book,
  String imageId,
  String engine,
) {
  final m = _readJson(paths.ocrLayout(book, imageId, engine: engine));
  if (m == null) return null;
  try {
    final page = PageLayout.fromJson(m);
    return page.lines.isEmpty ? null : page;
  } catch (_) {
    return null;
  }
}

/// The text and geometry the photo screen parses for one page: the same page
/// preparation `recombineAndParse` runs before `autoParseOcrText`.
(String, DocumentLayout?) _asPhotoPage(String text, {PageLayout? layout}) {
  final prepared = prepareScreenPages([PageText(text, layout: layout)]);
  return (
    prepared.text,
    layout == null ? null : DocumentLayout(prepared.layouts),
  );
}

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
      '  varav sidor där facit har en svans (frameCut: tail): '
      '${outcomes.where((o) => o.page.tails > 0).length}; '
      'för få och facit har svans: '
      '${short.where((o) => o.page.tails > 0).length} av ${short.length}',
    )
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
      final tails = <String, int>{};
      final gold = _goldCounts(paths, books, tails);
      final manager = ImportManager(_NoopPersonalOps());

      Future<_Outcome> score(_Page page) async {
        final result = await manager.autoParseMulti(
          page.text,
          layout: page.layout,
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

      final byInput = <String, List<_Outcome>>{
        'ocr.txt': [],
        'ML Kit med geometri': [],
        'winocr med geometri': [],
      };
      var noAnswerKey = 0;
      for (final MapEntry(key: key, value: count) in gold.entries) {
        if (count == 0) {
          noAnswerKey++;
          continue;
        }
        final [book, imageId] = key.split('/');
        final pageTails = tails[key] ?? 0;
        final ocr = _ocrTextOf(paths, book, imageId);
        if (ocr != null) {
          final (text, _) = _asPhotoPage(ocr);
          byInput['ocr.txt']!.add(
            await score(_Page(book, imageId, count, pageTails, text)),
          );
        }
        for (final (label, engine) in [
          ('ML Kit med geometri', 'mlkit'),
          ('winocr med geometri', 'winocr'),
        ]) {
          final page = _layoutOf(paths, book, imageId, engine);
          if (page == null) continue;
          final (text, layout) = _asPhotoPage(page.text, layout: page);
          byInput[label]!.add(
            await score(
              _Page(book, imageId, count, pageTails, text, layout),
            ),
          );
        }
      }

      final text = StringBuffer()
        ..writeln('Korpus: ${paths.root}')
        ..writeln(
          'Sidor utan annat än fragment i facit (hoppade): $noAnswerKey',
        )
        ..writeln(
          'Ersättnings-OCR: ingen av indatan är telefonens egen läsning i appen.',
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
