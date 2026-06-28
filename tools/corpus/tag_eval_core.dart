/// Evaluation engine for the tag-accuracy scorecard.
///
/// Loads `tags.gold.json` (the hand-verified answer key) + `tags.draft.json`
/// (the tagging pipeline's prediction, produced by the harness-as-test) per
/// recipe, scores each via [tag_metrics], and aggregates. Pure Dart — IO is
/// `dart:io`, scoring is side-effect-free and unit-tested.
///
/// Regression workflow: re-run the tag harness (free) to refresh
/// `tags.draft.json` against the CURRENT tagger, then run this. Movement in the
/// summary — especially the false-FREE count — is the regression signal.
library;

import 'dart:convert';
import 'dart:io';

import 'corpus_paths.dart';
import 'tag_metrics.dart';
import 'tag_models.dart';

/// One scorable recipe: the tag answer key and the tagger's prediction.
class TagEntry {
  final String bookSlug;
  final String recipeId;
  final GoldTags gold;
  final PredictedTags prediction;

  const TagEntry({
    required this.bookSlug,
    required this.recipeId,
    required this.gold,
    required this.prediction,
  });
}

class TagReport {
  final String bookSlug;
  final String recipeId;
  final RecipeTagScore score;

  const TagReport({
    required this.bookSlug,
    required this.recipeId,
    required this.score,
  });
}

class TagLoad {
  final List<TagEntry> entries;
  final List<String> skipped;

  const TagLoad({required this.entries, required this.skipped});
}

// The tag answer key + prediction live in the SAME recipe directory as the
// recipe's gold.json/draft.json. In every RecipeEntry layout (flat and nested)
// goldPath and draftPath share one directory, so both resolvers just swap the
// filename of a known sibling.

/// `<recipe-dir>/gold.json` → `<recipe-dir>/tags.gold.json`.
String tagsGoldPath(String goldPath) => _sibling(goldPath, 'tags.gold.json');

/// `<recipe-dir>/draft.json` → `<recipe-dir>/tags.draft.json`.
String tagsDraftPath(String draftPath) =>
    _sibling(draftPath, 'tags.draft.json');

String _sibling(String filePath, String name) {
  final clean = filePath.replaceAll('\\', '/');
  final i = clean.lastIndexOf('/');
  return i < 0 ? name : '${clean.substring(0, i)}/$name';
}

/// Reads every recipe with a VERIFIED `tags.gold.json`. A recipe is skipped
/// (with a logged reason) when the answer key is missing/unverified or no
/// prediction exists — silent under-coverage never reads as a pass.
TagLoad loadTagEntries(CorpusPaths paths) {
  if (!paths.exists) {
    return TagLoad(
      entries: const [],
      skipped: ['corpus root not found: ${paths.root}'],
    );
  }

  final entries = <TagEntry>[];
  final skipped = <String>[];

  for (final bookDir in paths.books()) {
    final bookSlug = _basename(bookDir.path);
    for (final entry in paths.recipeEntries(bookSlug)) {
      final label = '$bookSlug/${entry.recipeId}';

      final goldFile = File(tagsGoldPath(entry.goldPath));
      if (!goldFile.existsSync()) {
        skipped.add('$label: tags.gold.json missing');
        continue;
      }
      final gold = _readGold(goldFile);
      if (gold == null) {
        skipped.add('$label: tags.gold.json malformed (parse error)');
        continue;
      }
      if (!gold.verified) {
        skipped.add('$label: tags.gold.json not verified yet');
        continue;
      }

      final draftFile = File(tagsDraftPath(entry.draftPath));
      if (!draftFile.existsSync()) {
        skipped.add('$label: tags.draft.json (prediction) missing');
        continue;
      }
      final prediction = _readPrediction(draftFile);
      if (prediction == null) {
        skipped.add('$label: tags.draft.json malformed (parse error)');
        continue;
      }

      entries.add(
        TagEntry(
          bookSlug: bookSlug,
          recipeId: entry.recipeId,
          gold: gold,
          prediction: prediction,
        ),
      );
    }
  }

  return TagLoad(entries: entries, skipped: skipped);
}

TagReport scoreTagEntry(TagEntry e) => TagReport(
  bookSlug: e.bookSlug,
  recipeId: e.recipeId,
  score: scoreRecipeTags(e.gold, e.prediction),
);

/// Human-readable console report.
String formatTagReport(
  List<TagReport> reports,
  TagSummary summary,
  List<String> skipped,
) {
  final b = StringBuffer();
  b.writeln('=== Tag-accuracy scorecard ===');
  b.writeln('Scored recipes: ${summary.count}   Skipped: ${skipped.length}');
  b.writeln('');
  if (reports.isNotEmpty) {
    b.writeln('Per-recipe (allergen acc / false-FREE / coverage):');
    for (final r in reports) {
      final a = r.score.allergens;
      b.writeln(
        '  ${r.bookSlug}/${r.recipeId}: '
        '${_pct(a.accuracy)} / '
        '${a.falseFree} false-FREE / '
        '${_pct(r.score.coverage)} cov',
      );
    }
    b.writeln('');
  }
  b.writeln('--- Summary ---');
  b.writeln(
    '  Allergen accuracy    : ${_pct(summary.allergens.accuracy)} '
    '(${summary.allergens.total} verdicts)',
  );
  b.writeln(
    '  Allergen FALSE-FREE  : ${summary.allergens.falseFree} '
    '(${_pct(summary.allergens.falseFreeRate)}) ⚠️ safety',
  );
  b.writeln('  Allergen missed-CONT : ${summary.allergens.missedContains}');
  b.writeln(
    '  Dietary accuracy     : ${_pct(summary.dietary.accuracy)} '
    '(${summary.dietary.total} verdicts)',
  );
  b.writeln('  Dietary FALSE-FREE   : ${summary.dietary.falseFree}');
  b.writeln('  Classification tag F1: ${_pct(summary.meanTagF1)}');
  b.writeln('  Mean coverage        : ${_pct(summary.meanCoverage)}');
  if (skipped.isNotEmpty) {
    b.writeln('');
    b.writeln('--- Skipped (${skipped.length}) ---');
    for (final s in skipped) {
      b.writeln('  • $s');
    }
  }
  return b.toString();
}

/// Writes the machine-readable summary to `_reports/tags/scorecard-<ts>.json`.
/// [timestamp] is injected (the caller stamps it) so this stays deterministic.
File writeTagReportJson(
  CorpusPaths paths,
  TagSummary summary,
  List<TagReport> reports,
  String timestamp,
) {
  final dir = Directory('${paths.reportsDir()}/tags');
  dir.createSync(recursive: true);
  final file = File('${dir.path}/scorecard-$timestamp.json');
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'timestamp': timestamp,
      'summary': summary.toJson(),
      'recipes': [
        for (final r in reports)
          {
            'recipe': '${r.bookSlug}/${r.recipeId}',
            'allergenAccuracy': _round(r.score.allergens.accuracy),
            'allergenFalseFree': r.score.allergens.falseFree,
            'allergenMissedContains': r.score.allergens.missedContains,
            'dietaryAccuracy': _round(r.score.dietary.accuracy),
            'tagF1': _round(r.score.tags.f1),
            'coverage': _round(r.score.coverage),
            'unmatchedIngredients': r.score.unmatchedIngredients,
          },
      ],
    }),
  );
  return file;
}

GoldTags? _readGold(File file) {
  if (!file.existsSync()) return null;
  try {
    final json = jsonDecode(file.readAsStringSync());
    if (json is! Map) return null;
    return GoldTags.fromJson(json.cast<String, dynamic>());
  } catch (_) {
    return null;
  }
}

PredictedTags? _readPrediction(File file) {
  if (!file.existsSync()) return null;
  try {
    final json = jsonDecode(file.readAsStringSync());
    if (json is! Map) return null;
    return PredictedTags.fromJson(json.cast<String, dynamic>());
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
