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

import 'package:butlery/constants/preparation_words.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

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
    final labels = _annotateLine(trimmed);
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

List<_TokenLabel>? _annotateLine(String line) {
  final tokens = _tokenize(line);
  if (tokens.isEmpty) return null;

  // Detect group headers (e.g. "Fyllning:", "Deg:") — all tokens → O
  if (_isGroupHeader(line)) {
    return List.generate(tokens.length, (i) => _TokenLabel(tokens[i], 'O'));
  }

  final labels = List.filled(tokens.length, 'O');

  // Step 1: Label quantity tokens (digits, fractions, ranges)
  _labelTokens(tokens, labels, _isQuantityToken, 'B-QTY', 'I-QTY');

  // Step 2: Label first unlabeled unit token
  for (var i = 0; i < tokens.length; i++) {
    if (labels[i] == 'O' &&
        UnitDefinitions.isKnownUnit(tokens[i].toLowerCase())) {
      labels[i] = 'B-UNIT';
      break;
    }
  }

  // Step 3: Label preparation words
  for (var i = 0; i < tokens.length; i++) {
    if (labels[i] == 'O' &&
        PreparationWords.isPreparationState(tokens[i].toLowerCase())) {
      labels[i] = 'B-PREP';
    }
  }

  // Step 4: Label size descriptors
  for (var i = 0; i < tokens.length; i++) {
    if (labels[i] == 'O' &&
        PreparationWords.isSizeDescriptor(tokens[i].toLowerCase())) {
      labels[i] = 'B-SIZE';
    }
  }

  // Step 5: Remaining tokens that look like ingredient names
  // Skip tokens after "eller" (alternatives) and inside parentheses
  var inName = false;
  var afterEller = false;
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
    if (parenDepth > 0) continue; // inside parens → stays O

    if (lower == 'eller') {
      afterEller = true;
      inName = false;
      continue;
    }

    if (labels[i] != 'O') {
      inName = false;
      continue;
    }

    // Don't label tokens after "eller" as NAME (alternative ingredient)
    if (afterEller) continue;

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
  var first = true;
  for (var i = 0; i < tokens.length; i++) {
    if (labels[i] == 'O' && predicate(tokens[i])) {
      labels[i] = first ? beginLabel : insideLabel;
      first = false;
    }
  }
}

bool _isQuantityToken(String token) {
  return RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞,./\-]+$').hasMatch(token);
}

bool _couldBeName(String token) {
  if (_isQuantityToken(token)) return false;
  if (UnitDefinitions.isKnownUnit(token)) return false;
  if (RegExp(r'^[(),;:]+$').hasMatch(token)) return false;
  if (_skipWords.contains(token)) return false;
  return token.length > 1;
}

const _skipWords = {
  // Conjunctions
  'eller', 'och', 'alternativt',
  // Optional markers
  'ev', 'ev.', 'eventuellt', 'gärna', 'ca', 'cirka',
  'valfritt', 'drygt', 'knappt', 'lite',
  // Purpose
  'till', 'för',
};

/// Detect group headers like "Fyllning:", "Deg:", "Till servering:"
bool _isGroupHeader(String line) {
  final trimmed = line.trim();
  if (trimmed.endsWith(':') && trimmed.length < 40) return true;
  return false;
}

/// Tokenizes matching CrfIngredientParser.tokenize() — splits on whitespace
/// and separates leading/trailing punctuation `(),;` as individual tokens.
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
