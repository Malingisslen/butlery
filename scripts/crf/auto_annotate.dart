/// Auto-annotates ingredient lines using the existing IngredientParser.
///
/// Reads raw ingredient lines from stdin, parses each with IngredientParser,
/// matches parsed fields back to tokens, and outputs CoNLL format
/// (tab-separated token\tlabel, blank lines between sequences).
///
/// Usage: dart run scripts/crf/auto_annotate.dart < ingredients.txt > training.conll
library;

import 'dart:convert';
import 'dart:io';

import 'package:butlery/constants/preparation_words.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';
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

  // Parse with existing parser
  final parsed = IngredientParser.parseIngredient(line);
  final labels = List.filled(tokens.length, 'O');

  // Match quantity tokens
  if (parsed.quantity > 0) {
    _labelTokens(tokens, labels, _isQuantityToken, 'B-QTY', 'I-QTY');
  }

  // Match unit token
  if (parsed.unit.isNotEmpty) {
    for (var i = 0; i < tokens.length; i++) {
      if (labels[i] == 'O' &&
          UnitDefinitions.isKnownUnit(tokens[i].toLowerCase())) {
        labels[i] = 'B-UNIT';
        break;
      }
    }
  }

  // Match preparation words
  for (var i = 0; i < tokens.length; i++) {
    if (labels[i] == 'O' &&
        PreparationWords.isPreparationState(tokens[i].toLowerCase())) {
      labels[i] = 'B-PREP';
    }
  }

  // Match size descriptors
  for (var i = 0; i < tokens.length; i++) {
    if (labels[i] == 'O' &&
        PreparationWords.isSizeDescriptor(tokens[i].toLowerCase())) {
      labels[i] = 'B-SIZE';
    }
  }

  // Remaining unlabeled tokens that are part of the ingredient name
  if (parsed.name.isNotEmpty) {
    final nameTokens = parsed.name.toLowerCase().split(RegExp(r'\s+'));
    var inName = false;
    for (var i = 0; i < tokens.length; i++) {
      if (labels[i] != 'O') {
        inName = false;
        continue;
      }

      final lower = tokens[i].toLowerCase();
      if (nameTokens.contains(lower) || _couldBeName(lower)) {
        labels[i] = inName ? 'I-NAME' : 'B-NAME';
        inName = true;
      } else {
        inName = false;
      }
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
  // Not a number, not a unit, not punctuation
  if (_isQuantityToken(token)) return false;
  if (UnitDefinitions.isKnownUnit(token)) return false;
  if (RegExp(r'^[(),;:]+$').hasMatch(token)) return false;
  if ({'ca', 'eller', 'och', 'ev', 'ev.', 'till'}.contains(token)) return false;
  return token.length > 1;
}

List<String> _tokenize(String line) {
  return line.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
}

class _TokenLabel {
  final String token;
  final String label;
  _TokenLabel(this.token, this.label);
}
