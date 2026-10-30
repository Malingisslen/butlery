@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/corpus/corpus_eval_core.dart';
import '../../tools/corpus/corpus_paths.dart';

void main() {
  // CorpusPaths normalizes to forward slashes; point it straight at the fixture.
  final paths = CorpusPaths('test/fixtures/corpus');

  group('loadEntries', () {
    test(
      'loads verified recipes and skips the unverified one with a reason',
      () {
        final load = loadEntries(paths);

        // recipe-01 + recipe-02 are verified; recipe-03 is not.
        expect(
          load.entries.map((e) => e.recipeId),
          containsAll(['recipe-01', 'recipe-02']),
        );
        expect(load.entries, hasLength(2));
        expect(
          load.skipped.join('\n'),
          contains('recipe-03'),
          reason: 'unverified gold must be skipped, not silently scored',
        );
      },
    );

    test('attaches the raw OCR text used for OCR-recall', () {
      final entry = loadEntries(
        paths,
      ).entries.firstWhere((e) => e.recipeId == 'recipe-01');
      expect(entry.ocrText, contains('vetemjöl'));
    });
  });

  group('scoreEntry + summarize', () {
    test('a perfect prediction scores full ingredient F1', () {
      final entry = loadEntries(
        paths,
      ).entries.firstWhere((e) => e.recipeId == 'recipe-01');
      final report = scoreEntry(entry);
      expect(report.score.ingredientNames.f1, 1.0);
      expect(report.score.ingredientsFull.f1, 1.0);
    });

    test('wrong quantities drop full-F1 but not name-F1', () {
      // recipe-02 draft has nötfärs as "5 dl" (gold: "500 g") and lök with no
      // amount — the items are right, the structure is not.
      final entry = loadEntries(
        paths,
      ).entries.firstWhere((e) => e.recipeId == 'recipe-02');
      final report = scoreEntry(entry);
      expect(report.score.ingredientNames.f1, 1.0);
      expect(report.score.ingredientsFull.f1, lessThan(1.0));
    });

    test('OCR-recall flags the ingredient the scan dropped', () {
      // recipe-02 ocr.txt omits "lök" entirely.
      final entry = loadEntries(
        paths,
      ).entries.firstWhere((e) => e.recipeId == 'recipe-02');
      final report = scoreEntry(entry);
      expect(report.ocrRecall.missing, contains('lök'));
      expect(report.ocrRecall.recall, lessThan(1.0));
    });

    test('summary aggregates only the scored recipes', () {
      final reports = loadEntries(paths).entries.map(scoreEntry).toList();
      final summary = summarize(reports);
      expect(summary.count, 2);
      // Both recipes assert portions + time.
      expect(summary.portionsAsserted, 2);
      expect(summary.timeAsserted, 2);
      expect(summary.meanIngredientNameF1, 1.0);
      expect(summary.meanIngredientFullF1, lessThan(1.0));
    });
  });

  group('appendTrendLine', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('corpus_trend'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('each run adds a line and never rewrites the earlier ones', () {
      final summary = summarize(
        loadEntries(paths).entries.map(scoreEntry).toList(),
      );
      final target = CorpusPaths('${tmp.path}/corpus');

      appendTrendLine(
        target,
        summary,
        date: '2026-10-29T10:00:00',
        parserVersion: '2.0.0',
      );
      final file = appendTrendLine(
        target,
        summary,
        date: '2026-10-30T10:00:00',
        parserVersion: '2.1.0',
      );

      final lines = file.readAsLinesSync();
      expect(file.path, endsWith('_reports/trend.jsonl'));
      expect(lines, hasLength(2));
      final first = jsonDecode(lines.first) as Map<String, dynamic>;
      final second = jsonDecode(lines.last) as Map<String, dynamic>;
      expect(first['parserVersion'], '2.0.0');
      expect(second['parserVersion'], '2.1.0');
      expect(second['date'], '2026-10-30T10:00:00');
      expect(second['verified'], 2);
      expect(second['ingredientNameF1'], 1.0);
      expect(
        second['ingredientFullF1'],
        closeTo(summary.meanIngredientFullF1, 0.0001),
      );
      expect(second.keys, containsAll(['instructionF1', 'ocrRecall']));
    });
  });

  group('parseParserVersion', () {
    test('reads the constant from the parser service source', () {
      expect(
        parseParserVersion(
          "/// doc\nconst String parserVersion = '2.4.1';\n",
        ),
        '2.4.1',
      );
    });

    test('is null when the declaration is gone', () {
      expect(parseParserVersion('const int other = 1;'), isNull);
    });

    test('finds the real constant in this checkout', () {
      expect(readParserVersion('.'), matches(RegExp(r'^\d+\.\d+\.\d+$')));
    });
  });
}
