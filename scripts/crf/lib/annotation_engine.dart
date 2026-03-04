/// Shared heuristic BIO annotation engine for Swedish ingredient lines.
///
/// Used by both auto_annotate.dart (bulk training data) and
/// export_corrections.dart (user correction retraining).
///
/// No Flutter dependency — uses only pure Dart imports.
library;

import 'package:butlery/constants/preparation_words.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

/// Result of annotating a single token.
class TokenLabel {
  final String token;
  final String label;
  TokenLabel(this.token, this.label);
}

/// Annotate a single ingredient line with BIO labels.
///
/// Returns null if the line produces no tokens.
List<TokenLabel>? annotateLine(String line) {
  final tokens = tokenize(line);
  if (tokens.isEmpty) return null;

  // Detect group headers (e.g. "Fyllning:", "Deg:") — all tokens → O
  if (isGroupHeader(line)) {
    return List.generate(tokens.length, (i) => TokenLabel(tokens[i], 'O'));
  }

  final labels = List.filled(tokens.length, 'O');

  // Step 1: Label quantity tokens (digits, fractions, ranges)
  labelTokens(tokens, labels, isQuantityToken, 'B-QTY', 'I-QTY');

  // Step 1b: Swedish text quantities ("en", "ett", "två", etc.)
  for (var i = 0; i < tokens.length; i++) {
    if (labels[i] == 'O' && textQuantities.contains(tokens[i].toLowerCase())) {
      if (i < 3) labels[i] = 'B-QTY';
    }
  }

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

  // Step 5: Mark purpose clauses ("till stekning", "till garnering") → O
  for (var i = 0; i < tokens.length - 1; i++) {
    if (tokens[i].toLowerCase() == 'till') {
      final next = tokens[i + 1].toLowerCase();
      if (purposeNouns.contains(next) ||
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

  // Step 6: Remaining tokens that look like ingredient names
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

    if (couldBeName(lower)) {
      labels[i] = inName ? 'I-NAME' : 'B-NAME';
      inName = true;
    } else {
      inName = false;
    }
  }

  return List.generate(
    tokens.length,
    (i) => TokenLabel(tokens[i], labels[i]),
  );
}

/// Apply BIO labeling for contiguous spans matching [predicate].
void labelTokens(
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

bool isQuantityToken(String token) =>
    RegExp(r'^[\d½¼¾⅓⅔⅛⅜⅝⅞,./\-]+$').hasMatch(token);

bool couldBeName(String token) {
  if (isQuantityToken(token)) return false;
  if (UnitDefinitions.isKnownUnit(token)) return false;
  if (RegExp(r'^[(),;:]+$').hasMatch(token)) return false;
  if (skipWords.contains(token)) return false;
  if (textQuantities.contains(token)) return false;
  return token.length > 1;
}

const textQuantities = {
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

const skipWords = {
  // Conjunctions
  'eller', 'och', 'alternativt',
  // Optional markers
  'ev', 'ev.', 'eventuellt', 'gärna', 'ca', 'cirka',
  'valfritt', 'drygt', 'knappt', 'lite',
  // Purpose
  'till', 'för',
};

/// Common nouns in Swedish purpose clauses
const purposeNouns = {
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

/// Detect group headers like "Fyllning:", "Deg:", "Till servering:"
bool isGroupHeader(String line) {
  final trimmed = line.trim();
  return trimmed.endsWith(':') && trimmed.length < 40;
}

/// Tokenizes matching CrfIngredientParser.tokenize() — splits on whitespace
/// and separates leading/trailing punctuation as individual tokens.
List<String> tokenize(String line) {
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

/// Valid BIO labels for format validation.
const validLabels = {
  'O',
  'B-QTY',
  'I-QTY',
  'B-UNIT',
  'B-NAME',
  'I-NAME',
  'B-PREP',
  'I-PREP',
  'B-SIZE',
};
