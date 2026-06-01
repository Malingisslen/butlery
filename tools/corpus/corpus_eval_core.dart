/// Evaluation engine for the cookbook gold corpus.
///
/// Loads `gold.json` + `draft.json` (the parser's prediction) + `ocr.txt` per
/// recipe, scores each via [corpus_metrics], and aggregates. Pure Dart — the
/// IO is `dart:io`, the scoring is side-effect-free and unit-tested.
///
/// Regression workflow: re-run prelabel (OCR is cached → free) to refresh
/// `draft.json` against the CURRENT parser, then run this. Movement in the
/// summary F1s is the regression signal.
library;

import 'dart:convert';
import 'dart:io';

import 'corpus_metrics.dart';
import 'corpus_models.dart';
import 'corpus_paths.dart';

/// One scorable recipe: the facit, the parser's prediction, and the raw OCR.
class CorpusEntry {
  final String bookSlug;
  final String recipeId;
  final GoldRecipe gold;
  final GoldRecipe prediction;
  final String ocrText;

  const CorpusEntry({
    required this.bookSlug,
    required this.recipeId,
    required this.gold,
    required this.prediction,
    required this.ocrText,
  });
}

/// Per-recipe scored result.
class RecipeReport {
  final String bookSlug;
  final String recipeId;
  final RecipeScore score;
  final TokenRecallResult ocrRecall;

  const RecipeReport({
    required this.bookSlug,
    required this.recipeId,
    required this.score,
    required this.ocrRecall,
  });
}

/// Outcome of loading: scorable entries plus the reasons others were skipped,
/// so silent under-coverage never reads as "everything passed".
class CorpusLoad {
  final List<CorpusEntry> entries;
  final List<String> skipped;

  const CorpusLoad({required this.entries, required this.skipped});
}

/// Reads every verified recipe in the corpus. A recipe is skipped (with a
/// logged reason) when gold is missing/unverified or no prediction exists.
CorpusLoad loadEntries(CorpusPaths paths) {
  if (!paths.exists) {
    return CorpusLoad(
      entries: const [],
      skipped: ['corpus root not found: ${paths.root}'],
    );
  }

  final entries = <CorpusEntry>[];
  final skipped = <String>[];

  for (final bookDir in paths.books()) {
    final bookSlug = _basename(bookDir.path);
    for (final recipeDir in paths.recipeDirs(bookSlug)) {
      final recipeId = _basename(recipeDir.path);
      final label = '$bookSlug/$recipeId';

      final goldFile = File(paths.gold(bookSlug, recipeId));
      final gold = _readRecipe(goldFile);
      if (gold == null) {
        skipped.add('$label: gold.json missing or malformed');
        continue;
      }
      if (!gold.verified) {
        skipped.add('$label: gold.json not verified yet');
        continue;
      }

      final prediction = _readRecipe(File(paths.draft(bookSlug, recipeId)));
      if (prediction == null) {
        skipped.add('$label: draft.json (prediction) missing');
        continue;
      }

      final ocrFile = File(paths.ocrText(bookSlug, recipeId));
      final ocrText = ocrFile.existsSync() ? ocrFile.readAsStringSync() : '';

      entries.add(CorpusEntry(
        bookSlug: bookSlug,
        recipeId: recipeId,
        gold: gold,
        prediction: prediction,
        ocrText: ocrText,
      ));
    }
  }

  return CorpusLoad(entries: entries, skipped: skipped);
}

RecipeReport scoreEntry(CorpusEntry entry) => RecipeReport(
      bookSlug: entry.bookSlug,
      recipeId: entry.recipeId,
      score: scoreRecipe(entry.gold, entry.prediction),
      ocrRecall: goldTokenRecall(entry.gold, entry.ocrText),
    );

/// Corpus-level means. Scalar accuracies (portions/time) are computed only
/// over the recipes whose facit actually asserts that field — see
/// [portionsAsserted] / [timeAsserted] for the denominators.
class CorpusSummary {
  final int count;
  final double titleMatchRate;
  final double meanTitleSimilarity;
  final double meanIngredientNameF1;
  final double meanIngredientFullF1;
  final double meanInstructionF1;
  final double meanOcrRecall;
  final int portionsAsserted;
  final double portionsAccuracy;
  final int timeAsserted;
  final double timeAccuracy;

  const CorpusSummary({
    required this.count,
    required this.titleMatchRate,
    required this.meanTitleSimilarity,
    required this.meanIngredientNameF1,
    required this.meanIngredientFullF1,
    required this.meanInstructionF1,
    required this.meanOcrRecall,
    required this.portionsAsserted,
    required this.portionsAccuracy,
    required this.timeAsserted,
    required this.timeAccuracy,
  });

  Map<String, dynamic> toJson() => {
        'count': count,
        'titleMatchRate': _round(titleMatchRate),
        'meanTitleSimilarity': _round(meanTitleSimilarity),
        'meanIngredientNameF1': _round(meanIngredientNameF1),
        'meanIngredientFullF1': _round(meanIngredientFullF1),
        'meanInstructionF1': _round(meanInstructionF1),
        'meanOcrRecall': _round(meanOcrRecall),
        'portionsAsserted': portionsAsserted,
        'portionsAccuracy': _round(portionsAccuracy),
        'timeAsserted': timeAsserted,
        'timeAccuracy': _round(timeAccuracy),
      };
}

/// Aggregate scored reports into a [CorpusSummary]. Pure — no IO.
CorpusSummary summarize(List<RecipeReport> reports) {
  if (reports.isEmpty) {
    return const CorpusSummary(
      count: 0,
      titleMatchRate: 0,
      meanTitleSimilarity: 0,
      meanIngredientNameF1: 0,
      meanIngredientFullF1: 0,
      meanInstructionF1: 0,
      meanOcrRecall: 0,
      portionsAsserted: 0,
      portionsAccuracy: 0,
      timeAsserted: 0,
      timeAccuracy: 0,
    );
  }

  final n = reports.length;
  double mean(double Function(RecipeReport) f) =>
      reports.map(f).reduce((a, b) => a + b) / n;

  final portionsScored =
      reports.where((r) => r.score.portionsMatch != null).toList();
  final timeScored = reports.where((r) => r.score.timeMatch != null).toList();

  double rate(List<RecipeReport> rs, bool Function(RecipeReport) ok) =>
      rs.isEmpty ? 0 : rs.where(ok).length / rs.length;

  return CorpusSummary(
    count: n,
    titleMatchRate: rate(reports, (r) => r.score.titleMatch),
    meanTitleSimilarity: mean((r) => r.score.titleSimilarity),
    meanIngredientNameF1: mean((r) => r.score.ingredientNames.f1),
    meanIngredientFullF1: mean((r) => r.score.ingredientsFull.f1),
    meanInstructionF1: mean((r) => r.score.instructions.f1),
    meanOcrRecall: mean((r) => r.ocrRecall.recall),
    portionsAsserted: portionsScored.length,
    portionsAccuracy:
        rate(portionsScored, (r) => r.score.portionsMatch == true),
    timeAsserted: timeScored.length,
    timeAccuracy: rate(timeScored, (r) => r.score.timeMatch == true),
  );
}

/// Human-readable console report.
String formatReport(
  List<RecipeReport> reports,
  CorpusSummary summary,
  List<String> skipped,
) {
  final b = StringBuffer();
  b.writeln('=== Cookbook corpus eval ===');
  b.writeln('Scored recipes: ${summary.count}   Skipped: ${skipped.length}');
  b.writeln('');
  if (reports.isNotEmpty) {
    b.writeln('Per-recipe (ingredient name-F1 / full-F1 / OCR-recall):');
    for (final r in reports) {
      b.writeln('  ${r.bookSlug}/${r.recipeId}: '
          '${_pct(r.score.ingredientNames.f1)} / '
          '${_pct(r.score.ingredientsFull.f1)} / '
          '${_pct(r.ocrRecall.recall)}'
          '${r.ocrRecall.missing.isEmpty ? '' : '  (OCR missed: ${r.ocrRecall.missing.join(', ')})'}');
    }
    b.writeln('');
  }
  b.writeln('--- Summary ---');
  b.writeln('  Title match rate     : ${_pct(summary.titleMatchRate)}');
  b.writeln('  Title similarity     : ${_pct(summary.meanTitleSimilarity)}');
  b.writeln('  Ingredient name-F1   : ${_pct(summary.meanIngredientNameF1)}');
  b.writeln('  Ingredient full-F1   : ${_pct(summary.meanIngredientFullF1)}');
  b.writeln('  Instruction F1       : ${_pct(summary.meanInstructionF1)}');
  b.writeln('  OCR token recall     : ${_pct(summary.meanOcrRecall)}');
  b.writeln('  Portions accuracy    : ${_pct(summary.portionsAccuracy)} '
      '(${summary.portionsAsserted} asserted)');
  b.writeln('  Time accuracy        : ${_pct(summary.timeAccuracy)} '
      '(${summary.timeAsserted} asserted)');
  if (skipped.isNotEmpty) {
    b.writeln('');
    b.writeln('--- Skipped (${skipped.length}) ---');
    for (final s in skipped) {
      b.writeln('  • $s');
    }
  }
  return b.toString();
}

/// Writes the machine-readable summary to `_reports/eval-<timestamp>.json`.
/// [timestamp] is injected (the caller stamps it) so this stays deterministic.
File writeReportJson(
  CorpusPaths paths,
  CorpusSummary summary,
  List<RecipeReport> reports,
  String timestamp,
) {
  final dir = Directory(paths.reportsDir());
  dir.createSync(recursive: true);
  final file = File('${paths.reportsDir()}/eval-$timestamp.json');
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'timestamp': timestamp,
      'summary': summary.toJson(),
      'recipes': [
        for (final r in reports)
          {
            'recipe': '${r.bookSlug}/${r.recipeId}',
            'ingredientNameF1': _round(r.score.ingredientNames.f1),
            'ingredientFullF1': _round(r.score.ingredientsFull.f1),
            'instructionF1': _round(r.score.instructions.f1),
            'ocrRecall': _round(r.ocrRecall.recall),
            'ocrMissing': r.ocrRecall.missing,
          },
      ],
    }),
  );
  return file;
}

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
