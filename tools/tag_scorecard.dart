/// CLI: score the tag-accuracy answer keys and write a report.
///
///   dart run tools/tag_scorecard.dart
///   BUTLERY_CORPUS_DIR=/path/to/corpus dart run tools/tag_scorecard.dart
///
/// Reads `tags.gold.json` (answer key) + `tags.draft.json` (the tagger's
/// prediction, produced by `RUN_TAG_SCORECARD=1 flutter test
/// test/corpus/tag_scorecard_test.dart`) per recipe, prints a console summary,
/// and writes `_reports/tags/scorecard-<timestamp>.json`. Pure file IO — never
/// runs the tagger, so it is free to run as often as you like.
library;

import 'dart:io';

import 'corpus/corpus_paths.dart';
import 'corpus/tag_eval_core.dart';
import 'corpus/tag_metrics.dart';

void main(List<String> args) {
  final paths = CorpusPaths.resolve();
  stdout.writeln('Corpus root: ${paths.root}');

  final load = loadTagEntries(paths);
  final reports = load.entries.map(scoreTagEntry).toList();
  final summary = summarizeTags(reports.map((r) => r.score).toList());

  stdout.writeln(formatTagReport(reports, summary, load.skipped));

  if (reports.isNotEmpty) {
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = writeTagReportJson(paths, summary, reports, ts);
    stdout.writeln('Report written: ${file.path}');
  }

  // Non-zero exit when there is nothing to score, so CI/scripts notice an
  // empty or unlabeled corpus instead of treating it as a pass.
  if (reports.isEmpty) {
    stderr.writeln('No verified tag answer keys scored.');
    exit(1);
  }
}
