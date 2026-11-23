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

  /// True when the parser produced no recipe matching this gold. [prediction]
  /// is then empty, so every F1 scores zero rather than the entry vanishing.
  final bool missed;

  const CorpusEntry({
    required this.bookSlug,
    required this.recipeId,
    required this.gold,
    required this.prediction,
    required this.ocrText,
    this.missed = false,
  });
}

/// Per-recipe scored result.
class RecipeReport {
  final String bookSlug;
  final String recipeId;
  final RecipeScore score;
  final TokenRecallResult ocrRecall;
  final bool missed;

  const RecipeReport({
    required this.bookSlug,
    required this.recipeId,
    required this.score,
    required this.ocrRecall,
    this.missed = false,
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
    // recipeEntries flattens both the flat (single-recipe) and nested
    // (recipe-NN, multi-recipe) layouts into one list.
    for (final entry in paths.recipeEntries(bookSlug)) {
      final label = '$bookSlug/${entry.recipeId}';

      final gold = _readRecipe(File(entry.goldPath));
      if (gold == null) {
        skipped.add('$label: gold.json missing or malformed');
        continue;
      }
      if (!gold.verified) {
        skipped.add('$label: gold.json not verified yet');
        continue;
      }

      var prediction = _readRecipe(File(entry.draftPath));
      var missed = false;
      if (prediction == null) {
        if (!File(entry.missedPath).existsSync()) {
          skipped.add('$label: draft.json (prediction) missing');
          continue;
        }
        missed = true;
        prediction = const GoldRecipe(
          verified: false,
          title: '',
          ingredients: [],
          instructions: [],
        );
      }

      final ocrFile = File(entry.ocrTextPath);
      final ocrText = ocrFile.existsSync() ? ocrFile.readAsStringSync() : '';

      entries.add(
        CorpusEntry(
          bookSlug: bookSlug,
          recipeId: entry.recipeId,
          gold: gold,
          prediction: prediction,
          ocrText: ocrText,
          missed: missed,
        ),
      );
    }
  }

  return CorpusLoad(entries: entries, skipped: skipped);
}

RecipeReport scoreEntry(CorpusEntry entry) => RecipeReport(
  bookSlug: entry.bookSlug,
  recipeId: entry.recipeId,
  score: scoreRecipe(entry.gold, entry.prediction),
  ocrRecall: goldTokenRecall(entry.gold, entry.ocrText),
  missed: entry.missed,
);

/// Corpus-level means. Scalar accuracies (portions/time) are computed only
/// over the recipes whose facit actually asserts that field — see
/// [portionsAsserted] / [timeAsserted] for the denominators.
class CorpusSummary {
  final int count;

  /// Of [count], how many the parser produced no matching recipe for. They are
  /// scored as zeros in every mean below except the `found*` ones.
  final int missed;
  final double foundIngredientNameF1;
  final double foundIngredientFullF1;
  final double foundInstructionF1;
  final double titleMatchRate;
  final double meanTitleSimilarity;
  final double meanIngredientNameF1;
  final double meanIngredientFullF1;
  final double meanInstructionF1;

  /// Over the [detailScored] recipes whose facit says more about an ingredient
  /// than its core name; a missed recipe counts as zero here too.
  final double meanIngredientDetailF1;
  final int detailScored;
  final double meanOcrRecall;
  final int portionsAsserted;
  final double portionsAccuracy;
  final int timeAsserted;
  final double timeAccuracy;

  const CorpusSummary({
    required this.count,
    this.missed = 0,
    this.foundIngredientNameF1 = 0,
    this.foundIngredientFullF1 = 0,
    this.foundInstructionF1 = 0,
    required this.titleMatchRate,
    required this.meanTitleSimilarity,
    required this.meanIngredientNameF1,
    required this.meanIngredientFullF1,
    required this.meanInstructionF1,
    this.meanIngredientDetailF1 = 0,
    this.detailScored = 0,
    required this.meanOcrRecall,
    required this.portionsAsserted,
    required this.portionsAccuracy,
    required this.timeAsserted,
    required this.timeAccuracy,
  });

  Map<String, dynamic> toJson() => {
    'count': count,
    'missed': missed,
    'foundIngredientNameF1': _round(foundIngredientNameF1),
    'foundIngredientFullF1': _round(foundIngredientFullF1),
    'foundInstructionF1': _round(foundInstructionF1),
    'titleMatchRate': _round(titleMatchRate),
    'meanTitleSimilarity': _round(meanTitleSimilarity),
    'meanIngredientNameF1': _round(meanIngredientNameF1),
    'meanIngredientFullF1': _round(meanIngredientFullF1),
    'meanInstructionF1': _round(meanInstructionF1),
    'meanIngredientDetailF1': _round(meanIngredientDetailF1),
    'detailScored': detailScored,
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

  final found = reports.where((r) => !r.missed).toList();
  double meanOfFound(double Function(RecipeReport) f) =>
      found.isEmpty ? 0 : found.map(f).reduce((a, b) => a + b) / found.length;

  final portionsScored = reports
      .where((r) => r.score.portionsMatch != null)
      .toList();
  final timeScored = reports.where((r) => r.score.timeMatch != null).toList();
  final detailScores = [
    for (final r in reports)
      if (r.score.ingredientDetails != null) r.score.ingredientDetails!.f1,
  ];

  double rate(List<RecipeReport> rs, bool Function(RecipeReport) ok) =>
      rs.isEmpty ? 0 : rs.where(ok).length / rs.length;

  return CorpusSummary(
    count: n,
    missed: reports.where((r) => r.missed).length,
    foundIngredientNameF1: meanOfFound((r) => r.score.ingredientNames.f1),
    foundIngredientFullF1: meanOfFound((r) => r.score.ingredientsFull.f1),
    foundInstructionF1: meanOfFound((r) => r.score.instructions.f1),
    titleMatchRate: rate(reports, (r) => r.score.titleMatch),
    meanTitleSimilarity: mean((r) => r.score.titleSimilarity),
    meanIngredientNameF1: mean((r) => r.score.ingredientNames.f1),
    meanIngredientFullF1: mean((r) => r.score.ingredientsFull.f1),
    meanInstructionF1: mean((r) => r.score.instructions.f1),
    meanIngredientDetailF1: detailScores.isEmpty
        ? 0
        : detailScores.reduce((a, b) => a + b) / detailScores.length,
    detailScored: detailScores.length,
    meanOcrRecall: mean((r) => r.ocrRecall.recall),
    portionsAsserted: portionsScored.length,
    portionsAccuracy: rate(
      portionsScored,
      (r) => r.score.portionsMatch == true,
    ),
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
  b.writeln(
    'Scored recipes: ${summary.count} (${summary.missed} of them missed by '
    'the parser, scored as zero)   Skipped: ${skipped.length}',
  );
  b.writeln('');
  if (reports.isNotEmpty) {
    b.writeln('Per-recipe (ingredient name-F1 / full-F1 / OCR-recall):');
    for (final r in reports) {
      b.writeln(
        '  ${r.bookSlug}/${r.recipeId}: '
        '${_pct(r.score.ingredientNames.f1)} / '
        '${_pct(r.score.ingredientsFull.f1)} / '
        '${_pct(r.ocrRecall.recall)}'
        '${r.ocrRecall.missing.isEmpty ? '' : '  (OCR missed: ${r.ocrRecall.missing.join(', ')})'}',
      );
    }
    b.writeln('');
  }
  b.writeln('--- Summary ---');
  b.writeln('  Title match rate     : ${_pct(summary.titleMatchRate)}');
  b.writeln('  Title similarity     : ${_pct(summary.meanTitleSimilarity)}');
  b.writeln('  Ingredient name-F1   : ${_pct(summary.meanIngredientNameF1)}');
  b.writeln('  Ingredient full-F1   : ${_pct(summary.meanIngredientFullF1)}');
  b.writeln('  Instruction F1       : ${_pct(summary.meanInstructionF1)}');
  b.writeln(
    '  Preparation/alt. F1  : ${_pct(summary.meanIngredientDetailF1)} '
    '(${summary.detailScored} recipes have one)',
  );
  b.writeln('  OCR token recall     : ${_pct(summary.meanOcrRecall)}');
  b.writeln(
    '  Only recipes the parser found (${summary.count - summary.missed}): '
    'name ${_pct(summary.foundIngredientNameF1)}, '
    'full ${_pct(summary.foundIngredientFullF1)}, '
    'steps ${_pct(summary.foundInstructionF1)}',
  );
  b.writeln(
    '  Portions accuracy    : ${_pct(summary.portionsAccuracy)} '
    '(${summary.portionsAsserted} asserted)',
  );
  b.writeln(
    '  Time accuracy        : ${_pct(summary.timeAccuracy)} '
    '(${summary.timeAsserted} asserted)',
  );
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
            'missed': r.missed,
            'ingredientNameF1': _round(r.score.ingredientNames.f1),
            'ingredientFullF1': _round(r.score.ingredientsFull.f1),
            'instructionF1': _round(r.score.instructions.f1),
            if (r.score.ingredientDetails != null)
              'ingredientDetailF1': _round(r.score.ingredientDetails!.f1),
            'ocrRecall': _round(r.ocrRecall.recall),
            'ocrMissing': r.ocrRecall.missing,
          },
      ],
    }),
  );
  return file;
}

/// Appends one line per run to `_reports/trend.jsonl`. Unlike the per-run
/// `eval-*.json` files, this is the series a parser change is judged against, so
/// it carries only what is comparable between runs. [date] and [parserVersion]
/// are injected so this stays deterministic.
File appendTrendLine(
  CorpusPaths paths,
  CorpusSummary summary, {
  required String date,
  required String parserVersion,
}) {
  Directory(paths.reportsDir()).createSync(recursive: true);
  final file = File('${paths.reportsDir()}/trend.jsonl');
  final line = jsonEncode({
    'date': date,
    'parserVersion': parserVersion,
    'verified': summary.count,
    'missed': summary.missed,
    'foundIngredientNameF1': _round(summary.foundIngredientNameF1),
    'foundIngredientFullF1': _round(summary.foundIngredientFullF1),
    'foundInstructionF1': _round(summary.foundInstructionF1),
    'ingredientNameF1': _round(summary.meanIngredientNameF1),
    'ingredientFullF1': _round(summary.meanIngredientFullF1),
    'instructionF1': _round(summary.meanInstructionF1),
    'ingredientDetailF1': _round(summary.meanIngredientDetailF1),
    'ocrRecall': _round(summary.meanOcrRecall),
    // Bump on any change to ingredientCoreName or its word lists: the names it
    // produces are the yardstick, and corpus_measure flags a change of key.
    'nameKey': 'core-1',
    // The text the parser is fed: `app-reflow` rejoins wrapped lines as the
    // photo path does. A trend line without the key was read without reflow.
    'reader': 'app-reflow',
  });
  file.writeAsStringSync('$line\n', mode: FileMode.append);
  return file;
}

/// Reads `parserVersion` out of the parser service's source. The constant lives
/// in a file that imports Flutter, which `dart run` cannot load, so the tool
/// reads the text instead of importing it. Null when the declaration is gone.
String? readParserVersion(String repoRoot) {
  final file = File(
    '$repoRoot/lib/services/parsing/recipe_parser_service.dart',
  );
  if (!file.existsSync()) return null;
  return parseParserVersion(file.readAsStringSync());
}

String? parseParserVersion(String source) => RegExp(
  '''const String parserVersion = ['"]([^'"]+)['"];''',
).firstMatch(source)?.group(1);

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
