import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';

/// Converts BIO label sequences into structured ParsedIngredient objects.
///
/// Tokenizes an ingredient line, runs the CRF decoder, then groups
/// consecutive token spans by label type to assemble the ingredient.
class CrfIngredientParser {
  final CrfViterbiDecoder _decoder;

  CrfIngredientParser(this._decoder);

  static final _bulletPrefix = RegExp(r'^[•●▪★→]\s*');
  static final _dashBullet = RegExp(r'^[-–—]\s+');
  static final _starBullet = RegExp(r'^\*\s+');
  static final _numberedBullet = RegExp(r'^\d+[.)]\s+');
  static final _emojiPrefix = RegExp(
    r'^[\u{1F300}-\u{1F9FF}\u{2600}-\u{27BF}]+\s*',
    unicode: true,
  );
  static final _mergedQtyUnit = RegExp(r'(\d)([a-zåäöA-ZÅÄÖ])');
  static final _purposeClause = RegExp(
    r'(?:^|\s+)till\s+(stekning|garnering|servering|redning|jäsning|utbakning'
    r'|panering|dusting|topping|formen|pensling|fritering|gratinering'
    r'|bakning|glazering|inläggning|marinering)$',
    caseSensitive: false,
  );
  static final _efterPhrase = RegExp(
    r'\s+efter\s+(smak|behov|önskan)$',
    caseSensitive: false,
  );
  static const _freshnessWords = {'färsk', 'färskt', 'färska'};

  /// Parses a single ingredient line into a structured ingredient.
  ParsedIngredient parseLine(String line) {
    final trimmed = line.trim();

    // Group headers (e.g., "Fyllning:", "Deg:") → empty ingredient
    if (trimmed.endsWith(':') && trimmed.length > 1 && trimmed.length < 40) {
      return ParsedIngredient(
        name: '',
        originalLine: line,
        confidence: ParseConfidence.low,
      );
    }

    // Strip bullet/emoji prefixes from social media formatting
    var cleaned = trimmed;
    cleaned = cleaned.replaceFirst(_bulletPrefix, '');
    cleaned = cleaned.replaceFirst(_dashBullet, '');
    cleaned = cleaned.replaceFirst(_starBullet, '');
    cleaned = cleaned.replaceFirst(_numberedBullet, '');
    cleaned = cleaned.replaceFirst(_emojiPrefix, '');

    // Split merged quantity+unit tokens ("2dl" → "2 dl", "1MSK" → "1 MSK")
    cleaned = cleaned.replaceAllMapped(
      _mergedQtyUnit,
      (m) => '${m[1]} ${m[2]}',
    );

    // Strip purpose clauses ("till stekning", "till garnering")
    cleaned = cleaned.replaceFirst(_purposeClause, '');
    // Strip "efter smak/behov" phrases
    cleaned = cleaned.replaceFirst(_efterPhrase, '');
    cleaned = cleaned.trim();

    final tokens = tokenize(cleaned);
    if (tokens.isEmpty) {
      return ParsedIngredient.simple(line);
    }

    final labels = _decoder.decode(tokens);

    // Post-processing: "färsk"/"färskt"/"färska" before a NAME token is part
    // of the name (e.g., "färsk basilika"), not a preparation descriptor
    _relabelFreshnessAsName(tokens, labels);

    return assembleFromLabels(tokens, labels, line);
  }

  /// Parses multiple ingredient lines, filtering out group headers.
  List<ParsedIngredient> parseLines(List<String> lines) {
    return lines
        .where((l) => l.trim().isNotEmpty)
        .map((l) => parseLine(l.trim()))
        .where((p) => p.name.isNotEmpty)
        .toList();
  }

  /// Tokenizes an ingredient line on whitespace, preserving punctuation
  /// attached to words as separate tokens.
  static List<String> tokenize(String line) {
    final tokens = <String>[];
    for (final part in line.trim().split(RegExp(r'\s+'))) {
      if (part.isEmpty) continue;

      // Separate leading punctuation
      var start = 0;
      while (start < part.length && _isPunctuation(part[start])) {
        tokens.add(part[start]);
        start++;
      }

      // Separate trailing punctuation
      var end = part.length;
      final trailing = <String>[];
      while (end > start && _isPunctuation(part[end - 1])) {
        trailing.add(part[end - 1]);
        end--;
      }

      // Core token
      if (start < end) {
        tokens.add(part.substring(start, end));
      }

      // Add trailing punctuation in order
      tokens.addAll(trailing.reversed);
    }
    return tokens;
  }

  static bool _isPunctuation(String ch) {
    return ch == '(' || ch == ')' || ch == ',' || ch == ';';
  }

  /// Assembles BIO labels into a structured [ParsedIngredient].
  ///
  /// Shared between CRF and NER parsers to ensure consistent output.
  /// Handles paren suppression and Swedish "och" bridging.
  static ParsedIngredient assembleFromLabels(
    List<String> tokens,
    List<BioLabel> labels,
    String originalLine,
  ) {
    final spans = _groupSpans(tokens, labels);

    final quantity = spans[_SpanType.qty];
    final unit = spans[_SpanType.unit];
    final size = spans[_SpanType.size];
    final rawName = spans[_SpanType.name];
    final prep = spans[_SpanType.prep];

    // Determine confidence based on label coverage
    final labeledCount = labels.where((l) => l != BioLabel.other).length;
    final coverage = tokens.isEmpty ? 0.0 : labeledCount / tokens.length;

    ParseConfidence confidence;
    if (rawName != null && quantity != null && coverage >= 0.6) {
      confidence = ParseConfidence.high;
    } else if (rawName != null && coverage >= 0.3) {
      confidence = ParseConfidence.medium;
    } else {
      confidence = ParseConfidence.low;
    }

    return ParsedIngredient(
      name: rawName ?? originalLine.trim(),
      originalLine: originalLine,
      quantity: quantity,
      unit: unit,
      size: size,
      preparation: prep,
      confidence: confidence,
    );
  }

  /// Groups consecutive tokens by their BIO label type into span strings.
  /// Filters out punctuation-only tokens and parenthetical content to prevent
  /// comma/paren artifacts in QTY/UNIT spans.
  ///
  /// Retains "och" tokens labeled O when they bridge two tokens of the same
  /// span type (e.g., "hackad och skalad" → prep = "hackad och skalad").
  static Map<_SpanType, String> _groupSpans(
    List<String> tokens,
    List<BioLabel> labels,
  ) {
    final result = <_SpanType, List<String>>{};

    // Track parenthesis depth to suppress QTY/UNIT inside parens
    var parenDepth = 0;
    _SpanType? lastType;

    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i] == '(') parenDepth++;

      final type = _spanTypeFor(labels[i]);
      if (type != null) {
        // Skip punctuation tokens
        if (!_punctuationOnly.hasMatch(tokens[i])) {
          // Inside parens: suppress QTY/UNIT to avoid "1 burk X (400 ml)"
          // leaking 400 into the quantity span
          final suppress = parenDepth > 0 &&
              (type == _SpanType.qty || type == _SpanType.unit);
          if (!suppress) {
            result.putIfAbsent(type, () => []).add(tokens[i]);
            lastType = type;
          }
        }
      } else if (tokens[i].toLowerCase() == 'och' && lastType != null) {
        // "och" labeled O bridging same-type spans: look ahead
        final nextType = _nextNonOSpanType(labels, i + 1);
        if (nextType == lastType) {
          result[lastType]!.add(tokens[i]);
        }
      }

      if (tokens[i] == ')') parenDepth = (parenDepth - 1).clamp(0, 99);
    }

    return result.map((k, v) => MapEntry(k, v.join(' ')));
  }

  static _SpanType? _nextNonOSpanType(List<BioLabel> labels, int from) {
    for (var i = from; i < labels.length; i++) {
      final type = _spanTypeFor(labels[i]);
      if (type != null) return type;
    }
    return null;
  }

  static final _punctuationOnly = RegExp(r'^[(),;]+$');

  /// Mutates [labels] in place: re-labels "färsk"/"färskt"/"färska" from PREP
  /// to NAME when followed by a NAME token. Swedish ingredient names often
  /// include freshness as part of the name: "färsk basilika", "färsk timjan".
  void _relabelFreshnessAsName(List<String> tokens, List<BioLabel> labels) {
    for (var i = 0; i < tokens.length - 1; i++) {
      final isPrep = labels[i] == BioLabel.bPrep || labels[i] == BioLabel.iPrep;
      if (!isPrep) continue;
      if (!_freshnessWords.contains(tokens[i].toLowerCase())) continue;

      // Check if followed by a NAME token
      if (labels[i + 1] == BioLabel.bName || labels[i + 1] == BioLabel.iName) {
        labels[i] = BioLabel.bName;
        // Demote the next token from B-NAME to I-NAME if it was B-NAME
        if (labels[i + 1] == BioLabel.bName) {
          labels[i + 1] = BioLabel.iName;
        }
      }
    }
  }

  static _SpanType? _spanTypeFor(BioLabel label) {
    switch (label) {
      case BioLabel.bQty:
      case BioLabel.iQty:
        return _SpanType.qty;
      case BioLabel.bUnit:
        return _SpanType.unit;
      case BioLabel.bName:
      case BioLabel.iName:
        return _SpanType.name;
      case BioLabel.bPrep:
      case BioLabel.iPrep:
        return _SpanType.prep;
      case BioLabel.bSize:
        return _SpanType.size;
      case BioLabel.other:
        return null;
    }
  }
}

enum _SpanType { qty, unit, name, prep, size }
