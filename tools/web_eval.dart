/// CLI: score the web-import ground-truth corpus and write a report.
///
///   dart run tools/web_eval.dart
///   BUTLERY_CORPUS_DIR=/path/to/corpus dart run tools/web_eval.dart
///
/// Reads `<corpus>/web/<slug>/{gold.json, draft.json}` per fixture, scores the
/// parser's structured output (title / ingredients / instructions / portions /
/// time) via the SAME [scoreRecipe] the cookbook eval uses, prints a summary,
/// and writes `_reports/import/eval-<timestamp>.json`. Pure file IO — never
/// hits the network or the parser, so it is free to run as often as you like.
///
/// Produce the `draft.json` predictions first with:
///   RUN_IMPORT_EVAL=1 flutter test test/corpus/web_import_prelabel_test.dart
library;

import 'dart:convert';
import 'dart:io';

import 'corpus/corpus_metrics.dart';
import 'corpus/corpus_models.dart';
import 'corpus/corpus_paths.dart';

void main(List<String> args) {
  final paths = CorpusPaths.resolve();
  // `_web` (underscore-prefixed) so the cookbook OCR eval's CorpusPaths.books()
  // — which skips `_`-prefixed dirs — never mistakes web fixtures for a book.
  final webRoot = Directory('${paths.root}/_web');
  stdout.writeln('Web corpus root: ${webRoot.path}');

  final scores = <_WebScore>[];
  final skipped = <String>[];

  if (webRoot.existsSync()) {
    for (final slugDir in webRoot.listSync().whereType<Directory>()) {
      final slug = _basename(slugDir.path);
      final goldFile = File('${slugDir.path}/gold.json');
      if (!goldFile.existsSync()) {
        skipped.add('$slug: gold.json missing');
        continue;
      }
      final gold = _readRecipe(goldFile);
      if (gold == null) {
        skipped.add('$slug: gold.json malformed (parse error)');
        continue;
      }
      if (!gold.verified) {
        skipped.add('$slug: gold.json not verified yet');
        continue;
      }
      final draftFile = File('${slugDir.path}/draft.json');
      if (!draftFile.existsSync()) {
        skipped.add('$slug: draft.json (prediction) missing');
        continue;
      }
      final pred = _readRecipe(draftFile);
      if (pred == null) {
        skipped.add('$slug: draft.json malformed (parse error)');
        continue;
      }
      scores.add(_WebScore(slug, scoreRecipe(gold, pred)));
    }
  } else {
    skipped.add('web corpus not found: ${webRoot.path}');
  }

  stdout.writeln(_format(scores, skipped));

  if (scores.isNotEmpty) {
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final dir = Directory('${paths.reportsDir()}/import')
      ..createSync(recursive: true);
    final file = File('${dir.path}/eval-$ts.json');
    file.writeAsStringSync(_reportJson(scores, ts));
    stdout.writeln('Report written: ${file.path}');
  }

  if (scores.isEmpty) {
    stderr.writeln('No verified web fixtures scored.');
    exit(1);
  }
}

class _WebScore {
  final String slug;
  final RecipeScore score;
  const _WebScore(this.slug, this.score);
}

String _format(List<_WebScore> scores, List<String> skipped) {
  final b = StringBuffer();
  b.writeln('=== Web-import eval ===');
  b.writeln('Scored: ${scores.length}   Skipped: ${skipped.length}');
  b.writeln('');
  if (scores.isNotEmpty) {
    b.writeln('Per-fixture (ingredient name-F1 / full-F1 / instruction-F1):');
    for (final s in scores) {
      b.writeln(
        '  ${s.slug}: '
        '${_pct(s.score.ingredientNames.f1)} / '
        '${_pct(s.score.ingredientsFull.f1)} / '
        '${_pct(s.score.instructions.f1)}',
      );
    }
    b.writeln('');
    b.writeln('--- Summary ---');
    b.writeln(
      '  Title match rate     : ${_pct(_mean(scores, (s) => s.titleMatch ? 1 : 0))}',
    );
    b.writeln(
      '  Ingredient name-F1   : ${_pct(_mean(scores, (s) => s.ingredientNames.f1))}',
    );
    b.writeln(
      '  Ingredient full-F1   : ${_pct(_mean(scores, (s) => s.ingredientsFull.f1))}',
    );
    b.writeln(
      '  Instruction F1       : ${_pct(_mean(scores, (s) => s.instructions.f1))}',
    );
  }
  if (skipped.isNotEmpty) {
    b.writeln('');
    b.writeln('--- Skipped (${skipped.length}) ---');
    for (final s in skipped) {
      b.writeln('  • $s');
    }
  }
  return b.toString();
}

String _reportJson(List<_WebScore> scores, String ts) {
  double mean(double Function(RecipeScore) f) => _mean(scores, f);
  return const JsonEncoder.withIndent('  ').convert({
    'timestamp': ts,
    'summary': {
      'count': scores.length,
      'titleMatchRate': _round(mean((s) => s.titleMatch ? 1 : 0)),
      'meanIngredientNameF1': _round(mean((s) => s.ingredientNames.f1)),
      'meanIngredientFullF1': _round(mean((s) => s.ingredientsFull.f1)),
      'meanInstructionF1': _round(mean((s) => s.instructions.f1)),
    },
    'fixtures': [
      for (final s in scores)
        {
          'fixture': s.slug,
          'ingredientNameF1': _round(s.score.ingredientNames.f1),
          'ingredientFullF1': _round(s.score.ingredientsFull.f1),
          'instructionF1': _round(s.score.instructions.f1),
          'titleMatch': s.score.titleMatch,
        },
    ],
  });
}

double _mean(List<_WebScore> scores, double Function(RecipeScore) f) =>
    scores.isEmpty
    ? 0
    : scores.map((s) => f(s.score)).reduce((a, b) => a + b) / scores.length;

GoldRecipe? _readRecipe(File file) {
  if (!file.existsSync()) return null;
  try {
    final json = jsonDecode(file.readAsStringSync());
    if (json is! Map) return null;
    return GoldRecipe.fromJson(json.cast<String, dynamic>());
  } catch (_) {
    return null;
  }
}

String _basename(String p) {
  final cleaned = p.replaceAll('\\', '/');
  final i = cleaned.lastIndexOf('/');
  return i < 0 ? cleaned : cleaned.substring(i + 1);
}

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
double _round(double v) => double.parse(v.toStringAsFixed(4));
