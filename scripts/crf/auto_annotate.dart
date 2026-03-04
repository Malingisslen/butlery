/// Auto-annotates ingredient lines using heuristic labeling.
///
/// Reads raw ingredient lines from stdin, applies rule-based BIO labeling
/// (quantity, unit, prep, size, name), and outputs CoNLL format.
///
/// No Flutter dependency — uses only pure Dart imports.
///
/// Usage: dart run scripts/crf/auto_annotate.dart < ingredients.txt > training.conll
library;

import 'dart:convert';
import 'dart:io';

import 'lib/annotation_engine.dart';

Future<void> main(List<String> args) async {
  var totalLines = 0;
  var annotatedLines = 0;

  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    final trimmed = line.trim();

    // Blank lines pass through as sequence separators
    if (trimmed.isEmpty) {
      stdout.writeln();
      continue;
    }

    totalLines++;
    final labels = annotateLine(trimmed);
    if (labels != null) {
      annotatedLines++;
      for (final entry in labels) {
        stdout.writeln('${entry.token}\t${entry.label}');
      }
      stdout.writeln();
    }
  }

  stderr.writeln('Annotated $annotatedLines / $totalLines lines');
}
