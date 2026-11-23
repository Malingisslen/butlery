import 'package:meta/meta.dart';

import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

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

    cleaned = withReadableAmount(cleaned);

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

  static const _amountPart =
      r'(?:\d+\s+(?:\d+/\d+|[½¼¾⅓⅔⅛])|\d+(?:[.,]\d+)?(?:/\d+)?|[½¼¾⅓⅔⅛])';
  static final _leadingRange = RegExp(
    '^($_amountPart)\\s*[-–—]\\s*($_amountPart)(?=\\s|\$)',
  );
  // The dash the print had between two whole numbers can drop out of the
  // photo ("4 6 dl rödvin"); a second number no larger than twice the first
  // is the other end of the range, not part of the name.
  static final _spacedRange = RegExp(
    r'^(\d{1,2})\s+(\d{1,2})(?=\s+\p{L})',
    unicode: true,
  );
  static final _strayBracket = RegExp(r'^(\d+)\s*[}\]|]+[,.]?(?=\s)');
  static const _unicodeFractions = {
    '½': '1/2',
    '¼': '1/4',
    '¾': '3/4',
    '⅓': '1/3',
    '⅔': '2/3',
    '⅛': '1/8',
  };

  /// The amount cleanups both readers share, so a photographed row reads the
  /// same whichever one handles it.
  static String withReadableAmount(String line) =>
      withWrittenRange(withoutStrayBracket(line));

  /// A bracket the camera read where a fraction stood ("1}, dl mjölk") is
  /// dropped, so the amount is not left inside the name.
  @visibleForTesting
  static String withoutStrayBracket(String line) {
    final m = _strayBracket.firstMatch(line);
    if (m == null) return line;
    return '${m[1]}${line.substring(m.end)}';
  }

  /// A range at the start of the line is one amount ("6–8 ägg", "3 – 4"):
  /// the model sees a spaced dash as a break and keeps only one end.
  @visibleForTesting
  static String withWrittenRange(String line) {
    final m = _leadingRange.firstMatch(line);
    if (m != null) {
      // A mixed number's unicode fraction ("1 ½-2") loses its half in the
      // model; the slash form survives.
      final low = m[1]!.contains(' ') ? _asciiFraction(m[1]!) : m[1]!;
      return '$low-${m[2]}${line.substring(m.end)}';
    }
    final spaced = _spacedRange.firstMatch(line);
    if (spaced != null) {
      final low = int.parse(spaced[1]!);
      final high = int.parse(spaced[2]!);
      if (high > low && high <= low * 2) {
        return '$low-$high${line.substring(spaced.end)}';
      }
    }
    return line;
  }

  static String _asciiFraction(String amount) {
    var out = amount;
    _unicodeFractions.forEach((k, v) => out = out.replaceAll(k, v));
    return out;
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
    List<BioLabel> decoded,
    String originalLine,
  ) {
    final labels = _withUnitAfterAmount(
      tokens,
      _withMixedFractions(tokens, decoded),
    );
    final spans = _groupSpans(tokens, labels);

    var quantity = spans[_SpanType.qty];
    var unit = spans[_SpanType.unit];
    // A fraction the model took for the unit ("½ röd chili") is the amount.
    if (unit != null && _bareFraction.hasMatch(unit)) {
      quantity = quantity == null ? unit : '$quantity $unit';
      unit = null;
    }
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

    var finalName =
        rawName ?? _remainderAfterAmount(tokens, labels, originalLine);
    // "1 knippa persilja": a bunch, a batch or a pouch is counted like a unit.
    if (unit == null && quantity != null) {
      final head = _countingUnit.firstMatch(finalName);
      if (head != null && finalName.length > head.end) {
        unit = head[1];
        finalName = finalName.substring(head.end);
      }
    }

    return ParsedIngredient(
      name: finalName,
      originalLine: originalLine,
      quantity: quantity,
      unit: unit,
      size: size,
      preparation: prep,
      confidence: confidence,
    );
  }

  /// With no NAME span the name is what remains after amount, unit, size and
  /// preparation, so the amount is not repeated inside the name.
  static String _remainderAfterAmount(
    List<String> tokens,
    List<BioLabel> labels,
    String originalLine,
  ) {
    final words = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final type = _spanTypeFor(labels[i]);
      if (type == _SpanType.qty ||
          type == _SpanType.unit ||
          type == _SpanType.size ||
          type == _SpanType.prep) {
        continue;
      }
      words.add(tokens[i]);
    }
    final remainder = words
        .join(' ')
        .replaceAll(' ,', ',')
        .replaceAll('( ', '(')
        .replaceAll(' )', ')')
        .trim();
    final hasWord = RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(remainder);
    return hasWord ? remainder : originalLine.trim();
  }

  static final _countingUnit = RegExp(
    r'^(knippa|sats|klase|klasar|påse|påsar|kuvert)\s+',
    caseSensitive: false,
  );

  static final _bareFraction = RegExp(r'^(?:\d+/\d+|[½¼¾⅓⅔⅛⅜⅝⅞⅕⅖⅗])$');

  /// The model labels the fraction of "3 ½ dl" as other, which turns the
  /// amount into "3" and silently drops half a unit.
  static List<BioLabel> _withMixedFractions(
    List<String> tokens,
    List<BioLabel> labels,
  ) {
    List<BioLabel>? fixed;
    for (var i = 1; i < tokens.length; i++) {
      final afterQty =
          labels[i - 1] == BioLabel.bQty || labels[i - 1] == BioLabel.iQty;
      final isQty = labels[i] == BioLabel.bQty || labels[i] == BioLabel.iQty;
      if (afterQty && !isQty && _bareFraction.hasMatch(tokens[i])) {
        fixed ??= List.of(labels);
        fixed[i] = BioLabel.iQty;
      }
    }
    return fixed ?? labels;
  }

  /// The model leaves a plain unit inside the name when the ingredient after
  /// it is a word it has not seen ("2 dl vinbärsgelé"): a known unit straight
  /// after the amount is the unit.
  static List<BioLabel> _withUnitAfterAmount(
    List<String> tokens,
    List<BioLabel> labels,
  ) {
    if (labels.contains(BioLabel.bUnit)) return labels;
    for (var i = 1; i < tokens.length; i++) {
      final afterQty =
          labels[i - 1] == BioLabel.bQty || labels[i - 1] == BioLabel.iQty;
      final isQty = labels[i] == BioLabel.bQty || labels[i] == BioLabel.iQty;
      if (!afterQty ||
          isQty ||
          !UnitDefinitions.isKnownUnit(tokens[i].toLowerCase())) {
        continue;
      }
      final fixed = List.of(labels);
      fixed[i] = BioLabel.bUnit;
      // The rest of the old name span continues as the name.
      if (i + 1 < tokens.length && fixed[i + 1] == BioLabel.iName) {
        fixed[i + 1] = BioLabel.bName;
      }
      return fixed;
    }
    return labels;
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
    final lastIndex = <_SpanType, int>{};
    final firstIndex = <_SpanType, int>{};

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
          final suppress =
              parenDepth > 0 &&
              (type == _SpanType.qty || type == _SpanType.unit);
          // A second amount further along the line ("2 dl mjöl + 4 dl vatten",
          // "4 äggvitor, ca 1 dl") belongs to another part of the line, not
          // to this ingredient's amount.
          final laterAmount =
              ((type == _SpanType.qty || type == _SpanType.unit) &&
                  result.containsKey(type) &&
                  lastIndex[type] != i - 1) ||
              (type == _SpanType.unit &&
                  firstIndex.containsKey(_SpanType.name) &&
                  firstIndex.containsKey(_SpanType.qty) &&
                  firstIndex[_SpanType.qty]! < firstIndex[_SpanType.name]!);
          if (!suppress && !laterAmount) {
            result.putIfAbsent(type, () => []).add(tokens[i]);
            lastType = type;
            lastIndex[type] = i;
            firstIndex.putIfAbsent(type, () => i);
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
