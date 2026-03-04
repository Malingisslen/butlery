/// Converts correction JSON (from export-corrections.ts) to CoNLL training data.
///
/// Reads corrections.json, tokenizes each correctedLine using the same tokenizer
/// as CrfIngredientParser, applies the shared annotation engine,
/// and outputs CoNLL format with format validation.
///
/// Usage:
///   dart run scripts/crf/export_corrections.dart \
///     [--input scripts/crf/data/corrections.json] \
///     [--output scripts/crf/data/corrections_training.conll]
library;

import 'dart:convert';
import 'dart:io';

import 'lib/annotation_engine.dart';

void main(List<String> args) {
  final inputPath =
      _getArg(args, '--input') ?? 'scripts/crf/data/corrections.json';
  final outputPath = _getArg(args, '--output') ??
      'scripts/crf/data/corrections_training.conll';

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: $inputPath');
    stderr.writeln(
      'Run: cd functions && npx ts-node src/admin/export-corrections.ts',
    );
    exit(1);
  }

  final json = jsonDecode(inputFile.readAsStringSync()) as List<dynamic>;
  stderr.writeln('Read ${json.length} corrections from $inputPath');

  final buffer = StringBuffer();
  var exported = 0;
  var skippedEmpty = 0;
  var skippedNoName = 0;

  final labelCounts = <String, int>{};
  final typeCounts = <String, int>{};

  for (final entry in json) {
    final map = entry as Map<String, dynamic>;
    final correctedLine = map['correctedLine'] as String?;
    if (correctedLine == null || correctedLine.trim().isEmpty) {
      skippedEmpty++;
      continue;
    }

    final labels = annotateLine(correctedLine.trim());
    if (labels == null) {
      skippedEmpty++;
      continue;
    }

    // Quality check: at least one B-NAME token
    final hasName = labels.any((tl) => tl.label == 'B-NAME');
    if (!hasName) {
      skippedNoName++;
      continue;
    }

    for (final tl in labels) {
      buffer.writeln('${tl.token}\t${tl.label}');
      labelCounts[tl.label] = (labelCounts[tl.label] ?? 0) + 1;
    }
    buffer.writeln(); // blank line = sequence separator

    exported++;
    final type = map['type'] as String? ?? 'unknown';
    typeCounts[type] = (typeCounts[type] ?? 0) + 1;
  }

  File(outputPath)
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());

  stderr.writeln('\nExport summary:');
  stderr.writeln('  Input corrections: ${json.length}');
  stderr.writeln('  Exported sequences: $exported');
  stderr.writeln('  Skipped (empty): $skippedEmpty');
  stderr.writeln('  Skipped (no name token): $skippedNoName');

  stderr.writeln('  By correction type:');
  for (final entry in typeCounts.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key))) {
    stderr.writeln('    ${entry.key}: ${entry.value}');
  }

  stderr.writeln('  Label distribution:');
  for (final entry in labelCounts.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key))) {
    stderr.writeln('    ${entry.key}: ${entry.value}');
  }

  stderr.writeln('\nWritten to: $outputPath');

  // Validate output format
  _validateConll(outputPath);
}

String? _getArg(List<String> args, String flag) {
  final idx = args.indexOf(flag);
  if (idx >= 0 && idx + 1 < args.length) return args[idx + 1];
  return null;
}

/// Validate CoNLL output format and label correctness.
void _validateConll(String path) {
  final lines = File(path).readAsLinesSync();
  var sequences = 0;
  var tokens = 0;
  var errors = 0;
  var inSequence = false;

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) {
      if (inSequence) sequences++;
      inSequence = false;
      continue;
    }

    inSequence = true;
    tokens++;
    final parts = line.split('\t');
    if (parts.length != 2) {
      stderr.writeln(
          '  VALIDATION ERROR line ${i + 1}: expected 2 tab-separated columns, got ${parts.length}');
      errors++;
      continue;
    }

    if (!validLabels.contains(parts[1])) {
      stderr.writeln(
          '  VALIDATION ERROR line ${i + 1}: invalid label "${parts[1]}"');
      errors++;
    }
  }
  if (inSequence) sequences++;

  if (errors == 0) {
    stderr.writeln('\nValidation PASSED: $sequences sequences, $tokens tokens');
  } else {
    stderr
        .writeln('\nValidation FAILED: $errors errors in $sequences sequences');
    exit(1);
  }
}
