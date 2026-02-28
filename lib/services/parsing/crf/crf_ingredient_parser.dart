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

  /// Parses a single ingredient line into a structured ingredient.
  ParsedIngredient parseLine(String line) {
    final tokens = tokenize(line);
    if (tokens.isEmpty) {
      return ParsedIngredient.simple(line);
    }

    final labels = _decoder.decode(tokens);
    return _assembleIngredient(tokens, labels, line);
  }

  /// Parses multiple ingredient lines.
  List<ParsedIngredient> parseLines(List<String> lines) {
    return lines
        .where((l) => l.trim().isNotEmpty)
        .map((l) => parseLine(l.trim()))
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

  ParsedIngredient _assembleIngredient(
    List<String> tokens,
    List<BioLabel> labels,
    String originalLine,
  ) {
    final spans = _groupSpans(tokens, labels);

    final quantity = spans[_SpanType.qty];
    final unit = spans[_SpanType.unit];
    final size = spans[_SpanType.size];
    final rawName = spans[_SpanType.name];
    // Fold size into name (e.g., "stor" + "lök" → "stor lök")
    final name =
        size != null && rawName != null ? '$size $rawName' : rawName ?? size;
    final prep = spans[_SpanType.prep];

    // Determine confidence based on label coverage
    final labeledCount = labels.where((l) => l != BioLabel.other).length;
    final coverage = tokens.isEmpty ? 0.0 : labeledCount / tokens.length;

    ParseConfidence confidence;
    if (name != null && quantity != null && coverage >= 0.6) {
      confidence = ParseConfidence.high;
    } else if (name != null && coverage >= 0.3) {
      confidence = ParseConfidence.medium;
    } else {
      confidence = ParseConfidence.low;
    }

    return ParsedIngredient(
      name: name ?? originalLine.trim(),
      originalLine: originalLine,
      quantity: quantity,
      unit: unit,
      preparation: prep,
      confidence: confidence,
    );
  }

  /// Groups consecutive tokens by their BIO label type into span strings.
  Map<_SpanType, String> _groupSpans(
    List<String> tokens,
    List<BioLabel> labels,
  ) {
    final result = <_SpanType, List<String>>{};

    for (var i = 0; i < tokens.length; i++) {
      final type = _spanTypeFor(labels[i]);
      if (type == null) continue;

      result.putIfAbsent(type, () => []).add(tokens[i]);
    }

    return result.map((k, v) => MapEntry(k, v.join(' ')));
  }

  _SpanType? _spanTypeFor(BioLabel label) {
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
