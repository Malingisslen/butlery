/// Converts correction JSON (from export-corrections.ts) to CoNLL training data.
///
/// Reads corrections.json, tokenizes each correctedLine using the same tokenizer
/// as CrfIngredientParser, applies the auto_annotate heuristic labeling,
/// and outputs CoNLL format.
///
/// Usage:
///   dart run scripts/crf/export_corrections.dart \
///     [--input scripts/crf/data/corrections.json] \
///     [--output scripts/crf/data/corrections_training.conll]
library;

import 'dart:convert';
import 'dart:io';

import 'package:butlery/constants/preparation_words.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

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

    final labels = _annotateLine(correctedLine.trim());
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
  stderr.writeln(
    'Merge with training.conll before retraining:\n'
    '  cat scripts/crf/data/training.conll scripts/crf/data/corrections_training.conll > merged.conll',
  );
}

String? _getArg(List<String> args, String flag) {
  final idx = args.indexOf(flag);
  if (idx >= 0 && idx + 1 < args.length) return args[idx + 1];
  return null;
}

// ---------------------------------------------------------------------------
// Annotation logic — mirrors auto_annotate.dart exactly
// ---------------------------------------------------------------------------

List<_TokenLabel>? _annotateLine(String line) {
  final tokens = _tokenize(line);
  if (tokens.isEmpty) return null;

  if (_isGroupHeader(line)) {
    return List.generate(tokens.length, (i) => _TokenLabel(tokens[i], 'O'));
  }

  final labels = List.filled(tokens.length, 'O');

  // Step 1: Numeric quantities
  _labelTokens(tokens, labels, _isQuantityToken, 'B-QTY', 'I-QTY');

  // Step 1b: Swedish text quantities
  for (var i = 0; i < tokens.length; i++) {
    if (labels[i] == 'O' && _textQuantities.contains(tokens[i].toLowerCase())) {
      if (i < 3) labels[i] = 'B-QTY';
    }
  }

  // Step 2: First unlabeled unit
  for (var i = 0; i < tokens.length; i++) {
    if (labels[i] == 'O' &&
        UnitDefinitions.isKnownUnit(tokens[i].toLowerCase())) {
      labels[i] = 'B-UNIT';
      break;
    }
  }

  // Step 3: Preparation words
  for (var i = 0; i < tokens.length; i++) {
    if (labels[i] == 'O' &&
        PreparationWords.isPreparationState(tokens[i].toLowerCase())) {
      labels[i] = 'B-PREP';
    }
  }

  // Step 4: Size descriptors
  for (var i = 0; i < tokens.length; i++) {
    if (labels[i] == 'O' &&
        PreparationWords.isSizeDescriptor(tokens[i].toLowerCase())) {
      labels[i] = 'B-SIZE';
    }
  }

  // Step 5: Purpose clauses → O
  for (var i = 0; i < tokens.length - 1; i++) {
    if (tokens[i].toLowerCase() == 'till') {
      final next = tokens[i + 1].toLowerCase();
      if (_purposeNouns.contains(next) ||
          next.endsWith('ning') ||
          next.endsWith('ring') ||
          next.endsWith('ing')) {
        for (var j = i; j < tokens.length; j++) {
          labels[j] = 'O';
        }
        break;
      }
    }
  }

  // Step 6: Remaining tokens → NAME
  var inName = false;
  var afterEller = false;
  var afterComma = false;
  var parenDepth = 0;
  for (var i = 0; i < tokens.length; i++) {
    final lower = tokens[i].toLowerCase();

    if (lower == '(') {
      parenDepth++;
      inName = false;
      continue;
    }
    if (lower == ')') {
      parenDepth = (parenDepth - 1).clamp(0, 99);
      continue;
    }
    if (parenDepth > 0) continue;

    if (lower == ',') {
      afterComma = true;
      inName = false;
      continue;
    }

    if (lower == 'eller') {
      afterEller = true;
      inName = false;
      continue;
    }

    if (labels[i] != 'O') {
      inName = false;
      continue;
    }

    if (afterEller) continue;
    if (afterComma) continue;

    if (_couldBeName(lower)) {
      labels[i] = inName ? 'I-NAME' : 'B-NAME';
      inName = true;
    } else {
      inName = false;
    }
  }

  return List.generate(
    tokens.length,
    (i) => _TokenLabel(tokens[i], labels[i]),
  );
}

void _labelTokens(
  List<String> tokens,
  List<String> labels,
  bool Function(String) predicate,
  String beginLabel,
  String insideLabel,
) {
  var inSpan = false;
  for (var i = 0; i < tokens.length; i++) {
    if (labels[i] == 'O' && predicate(tokens[i])) {
      labels[i] = inSpan ? insideLabel : beginLabel;
      inSpan = true;
    } else {
      inSpan = false;
    }
  }
}

bool _isQuantityToken(String token) =>
    RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞,./\-]+$').hasMatch(token);

bool _couldBeName(String token) {
  if (_isQuantityToken(token)) return false;
  if (UnitDefinitions.isKnownUnit(token)) return false;
  if (RegExp(r'^[(),;:]+$').hasMatch(token)) return false;
  if (_skipWords.contains(token)) return false;
  if (_textQuantities.contains(token)) return false;
  return token.length > 1;
}

const _textQuantities = {
  'en',
  'ett',
  'två',
  'tre',
  'fyra',
  'fem',
  'sex',
  'sju',
  'åtta',
  'nio',
  'tio',
  'halv',
  'halva',
  'halvt',
};

const _skipWords = {
  'eller',
  'och',
  'alternativt',
  'ev',
  'ev.',
  'eventuellt',
  'gärna',
  'ca',
  'cirka',
  'valfritt',
  'drygt',
  'knappt',
  'lite',
  'till',
  'för',
};

const _purposeNouns = {
  'stekning',
  'garnering',
  'servering',
  'redning',
  'jäsning',
  'utbakning',
  'panering',
  'dusting',
  'topping',
  'formen',
  'pensling',
  'fritering',
  'gratinering',
  'bakning',
};

bool _isGroupHeader(String line) {
  final trimmed = line.trim();
  return trimmed.endsWith(':') && trimmed.length < 40;
}

List<String> _tokenize(String line) {
  final tokens = <String>[];
  for (final part in line.trim().split(RegExp(r'\s+'))) {
    if (part.isEmpty) continue;
    var start = 0;
    while (start < part.length && _isPunctuation(part[start])) {
      tokens.add(part[start]);
      start++;
    }
    var end = part.length;
    final trailing = <String>[];
    while (end > start && _isPunctuation(part[end - 1])) {
      trailing.add(part[end - 1]);
      end--;
    }
    if (start < end) tokens.add(part.substring(start, end));
    tokens.addAll(trailing.reversed);
  }
  return tokens;
}

bool _isPunctuation(String ch) =>
    ch == '(' || ch == ')' || ch == ',' || ch == ';';

class _TokenLabel {
  final String token;
  final String label;
  _TokenLabel(this.token, this.label);
}
