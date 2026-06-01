/// CLI: score the cookbook gold corpus and write a report.
///
///   dart run tools/corpus_eval.dart
///   BUTLERY_CORPUS_DIR=/path/to/corpus dart run tools/corpus_eval.dart
///
/// Reads gold.json + draft.json + ocr.txt per recipe, prints a console
/// summary, and writes `_reports/eval-<timestamp>.json`. Pure file IO — never
/// calls OCR or the parser, so it is free to run as often as you like.
library;

import 'dart:io';

import 'corpus/corpus_eval_core.dart';
import 'corpus/corpus_paths.dart';

void main(List<String> args) {
  final paths = CorpusPaths.resolve();
  stdout.writeln('Corpus root: ${paths.root}');

  final load = loadEntries(paths);
  final reports = load.entries.map(scoreEntry).toList();
  final summary = summarize(reports);

  stdout.writeln(formatReport(reports, summary, load.skipped));

  if (reports.isNotEmpty) {
    // Filesystem-safe ISO timestamp (no colons) for the report filename.
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = writeReportJson(paths, summary, reports, ts);
    stdout.writeln('Report written: ${file.path}');
  }

  // Non-zero exit when there is nothing to score, so CI/scripts notice an
  // empty or unverified corpus instead of treating it as a pass.
  if (reports.isEmpty) {
    stderr.writeln('No verified recipes scored.');
    exit(1);
  }
}
