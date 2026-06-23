/// CRF ingredient parser evaluation framework.
///
/// Runs the CRF parser against a golden dataset of annotated Swedish
/// ingredient lines, computing per-label precision/recall/F1 at both
/// token level and span level, plus field-level exact match accuracy.
///
/// Usage: flutter test test/evaluation/crf_evaluator.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:butlery/services/parsing/crf/crf_ingredient_parser.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:test/test.dart';

/// A single golden test case with BIO labels and expected fields.
class CrfGoldenEntry {
  final String input;
  final List<String> tokens;
  final List<String> labels;
  final Map<String, String> expected;
  final List<String> tags;
  final String description;

  const CrfGoldenEntry({
    required this.input,
    required this.tokens,
    required this.labels,
    required this.expected,
    required this.tags,
    required this.description,
  });

  factory CrfGoldenEntry.fromJson(Map<String, dynamic> json) {
    return CrfGoldenEntry(
      input: json['input'] as String,
      tokens: (json['tokens'] as List<dynamic>).cast<String>(),
      labels: (json['labels'] as List<dynamic>).cast<String>(),
      expected: (json['expected'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v.toString()),
      ),
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      description: json['description'] as String,
    );
  }
}

/// Per-label precision/recall/F1 metrics.
class LabelMetrics {
  int truePositives = 0;
  int falsePositives = 0;
  int falseNegatives = 0;

  double get precision => truePositives + falsePositives == 0
      ? 0.0
      : truePositives / (truePositives + falsePositives);

  double get recall => truePositives + falseNegatives == 0
      ? 0.0
      : truePositives / (truePositives + falseNegatives);

  double get f1 {
    final p = precision;
    final r = recall;
    return p + r == 0 ? 0.0 : 2 * p * r / (p + r);
  }

  int get support => truePositives + falseNegatives;
}

/// Accumulated evaluation metrics across all golden entries.
class CrfEvaluationResult {
  /// Token-level metrics per label.
  final Map<String, LabelMetrics> tokenMetrics = {};

  /// Span-level metrics per entity type.
  final Map<String, LabelMetrics> spanMetrics = {};

  /// Field-level exact match counts.
  int totalEntries = 0;
  int quantityExact = 0;
  int unitExact = 0;
  int nameExact = 0;
  int sizeExact = 0;
  int prepExact = 0;
  int allFieldsExact = 0;

  /// Per-tag accuracy tracking.
  final Map<String, TagStats> tagStats = {};

  /// Failures for debugging.
  final List<FailureEntry> failures = [];

  void recordTokenMetrics(
    List<String> goldLabels,
    List<String> predLabels,
  ) {
    for (var i = 0; i < goldLabels.length && i < predLabels.length; i++) {
      final gold = goldLabels[i];
      final pred = predLabels[i];

      // True positive: both agree
      if (gold == pred) {
        tokenMetrics.putIfAbsent(gold, () => LabelMetrics()).truePositives++;
      } else {
        // False negative for gold label
        tokenMetrics.putIfAbsent(gold, () => LabelMetrics()).falseNegatives++;
        // False positive for predicted label
        tokenMetrics.putIfAbsent(pred, () => LabelMetrics()).falsePositives++;
      }
    }
  }

  void recordSpanMetrics(
    List<String> goldLabels,
    List<String> goldTokens,
    List<String> predLabels,
    List<String> predTokens,
  ) {
    final goldSpans = _extractSpans(goldLabels, goldTokens);
    final predSpans = _extractSpans(predLabels, predTokens);

    for (final type in {...goldSpans.keys, ...predSpans.keys}) {
      final gold = goldSpans[type] ?? '';
      final pred = predSpans[type] ?? '';
      final metrics = spanMetrics.putIfAbsent(type, () => LabelMetrics());

      if (gold == pred && gold.isNotEmpty) {
        metrics.truePositives++;
      } else {
        if (gold.isNotEmpty) metrics.falseNegatives++;
        if (pred.isNotEmpty) metrics.falsePositives++;
      }
    }
  }

  void recordFieldMatch(
    CrfGoldenEntry entry,
    String? predQuantity,
    String? predUnit,
    String? predName,
    String? predSize,
    String? predPrep,
  ) {
    totalEntries++;
    if (entry.tokens.isEmpty) return;

    final expQty = entry.expected['quantity'];
    final expUnit = entry.expected['unit'];
    final expName = entry.expected['name'];
    final expSize = entry.expected['size'];
    final expPrep = entry.expected['preparation'];

    final qtyMatch = _fieldMatch(expQty, predQuantity);
    final unitMatch = _fieldMatch(expUnit, predUnit);
    final nameMatch = _fieldMatch(expName, predName);
    final sizeMatch = _fieldMatch(expSize, predSize);
    final prepMatch = _fieldMatch(expPrep, predPrep);

    if (qtyMatch) quantityExact++;
    if (unitMatch) unitExact++;
    if (nameMatch) nameExact++;
    if (sizeMatch) sizeExact++;
    if (prepMatch) prepExact++;
    final allMatch =
        qtyMatch && unitMatch && nameMatch && sizeMatch && prepMatch;
    if (allMatch) {
      allFieldsExact++;
    }

    for (final tag in entry.tags) {
      final stats = tagStats.putIfAbsent(tag, () => TagStats(tag));
      stats.total++;
      if (allMatch) stats.exact++;
    }

    if (!allMatch) {
      failures.add(
        FailureEntry(
          input: entry.input,
          tags: entry.tags,
          description: entry.description,
          expectedQty: expQty,
          expectedUnit: expUnit,
          expectedName: expName,
          expectedSize: expSize,
          expectedPrep: expPrep,
          actualQty: predQuantity,
          actualUnit: predUnit,
          actualName: predName,
          actualSize: predSize,
          actualPrep: predPrep,
        ),
      );
    }
  }

  bool _fieldMatch(String? expected, String? actual) {
    if (expected == null && actual == null) return true;
    if (expected == null && (actual == null || actual.isEmpty)) return true;
    if (expected != null && actual != null) {
      return expected.toLowerCase() == actual.toLowerCase();
    }
    return false;
  }

  Map<String, String> _extractSpans(
    List<String> labels,
    List<String> tokens,
  ) {
    final spans = <String, List<String>>{};

    for (var i = 0; i < labels.length && i < tokens.length; i++) {
      final label = labels[i];
      if (label == 'O') continue;

      // Map BIO label to entity type
      String type;
      if (label.contains('QTY')) {
        type = 'QTY';
      } else if (label.contains('UNIT')) {
        type = 'UNIT';
      } else if (label.contains('NAME')) {
        type = 'NAME';
      } else if (label.contains('PREP')) {
        type = 'PREP';
      } else if (label.contains('SIZE')) {
        type = 'SIZE';
      } else {
        continue;
      }

      spans.putIfAbsent(type, () => []).add(tokens[i]);
    }

    return spans.map((k, v) => MapEntry(k, v.join(' ')));
  }

  String generateReport() {
    final buf = StringBuffer()
      ..writeln('')
      ..writeln('=== CRF EVALUATION REPORT ===')
      ..writeln('')
      ..writeln('FIELD-LEVEL EXACT MATCH:')
      ..writeln(
        '  All fields:   $allFieldsExact/$totalEntries '
        '(${_pct(allFieldsExact, totalEntries)})',
      )
      ..writeln(
        '  Quantity:     $quantityExact/$totalEntries '
        '(${_pct(quantityExact, totalEntries)})',
      )
      ..writeln(
        '  Unit:         $unitExact/$totalEntries '
        '(${_pct(unitExact, totalEntries)})',
      )
      ..writeln(
        '  Name:         $nameExact/$totalEntries '
        '(${_pct(nameExact, totalEntries)})',
      )
      ..writeln(
        '  Size:         $sizeExact/$totalEntries '
        '(${_pct(sizeExact, totalEntries)})',
      )
      ..writeln(
        '  Preparation:  $prepExact/$totalEntries '
        '(${_pct(prepExact, totalEntries)})',
      )
      ..writeln('')
      ..writeln('TOKEN-LEVEL METRICS (per label):');

    final sortedLabels = tokenMetrics.keys.toList()..sort();
    for (final label in sortedLabels) {
      final m = tokenMetrics[label]!;
      buf.writeln(
        '  $label: P=${m.precision.toStringAsFixed(3)} '
        'R=${m.recall.toStringAsFixed(3)} '
        'F1=${m.f1.toStringAsFixed(3)} '
        '(support=${m.support})',
      );
    }

    // Macro-average F1
    final labelF1s = tokenMetrics.values
        .where((m) => m.support > 0)
        .map((m) => m.f1)
        .toList();
    if (labelF1s.isNotEmpty) {
      final macroF1 = labelF1s.reduce((a, b) => a + b) / labelF1s.length;
      buf.writeln('  --- Macro-avg F1: ${macroF1.toStringAsFixed(3)} ---');
    }

    buf.writeln('');
    buf.writeln('SPAN-LEVEL METRICS (per entity type):');
    final sortedSpans = spanMetrics.keys.toList()..sort();
    for (final type in sortedSpans) {
      final m = spanMetrics[type]!;
      buf.writeln(
        '  $type: P=${m.precision.toStringAsFixed(3)} '
        'R=${m.recall.toStringAsFixed(3)} '
        'F1=${m.f1.toStringAsFixed(3)} '
        '(support=${m.support})',
      );
    }

    buf.writeln('');
    buf.writeln('PER-TAG BREAKDOWN:');
    final sortedTags = tagStats.keys.toList()..sort();
    for (final tag in sortedTags) {
      final s = tagStats[tag]!;
      buf.writeln(
        '  $tag: ${s.exact}/${s.total} '
        '(${_pct(s.exact, s.total)})',
      );
    }

    if (failures.isNotEmpty) {
      buf.writeln('');
      buf.writeln('FAILURES (${failures.length}):');
      for (final f in failures.take(20)) {
        buf.writeln('');
        buf.writeln('  INPUT: "${f.input}" [${f.tags.join(", ")}]');
        buf.writeln('  DESC:  ${f.description}');
        if (f.expectedQty != f.actualQty) {
          buf.writeln(
            '    qty:  expected="${f.expectedQty}" '
            'actual="${f.actualQty}"',
          );
        }
        if (f.expectedUnit != f.actualUnit) {
          buf.writeln(
            '    unit: expected="${f.expectedUnit}" '
            'actual="${f.actualUnit}"',
          );
        }
        if (f.expectedName?.toLowerCase() != f.actualName?.toLowerCase()) {
          buf.writeln(
            '    name: expected="${f.expectedName}" '
            'actual="${f.actualName}"',
          );
        }
        if (f.expectedSize?.toLowerCase() != f.actualSize?.toLowerCase()) {
          buf.writeln(
            '    size: expected="${f.expectedSize}" '
            'actual="${f.actualSize}"',
          );
        }
        if (f.expectedPrep?.toLowerCase() != f.actualPrep?.toLowerCase()) {
          buf.writeln(
            '    prep: expected="${f.expectedPrep}" '
            'actual="${f.actualPrep}"',
          );
        }
      }
      if (failures.length > 20) {
        buf.writeln('  ... and ${failures.length - 20} more');
      }
    }

    buf.writeln('');
    buf.writeln('=== END REPORT ===');
    return buf.toString();
  }

  static String _pct(int n, int d) {
    if (d == 0) return 'N/A';
    return '${(n / d * 100).toStringAsFixed(1)}%';
  }
}

class TagStats {
  final String tag;
  int total = 0;
  int exact = 0;
  TagStats(this.tag);
}

class FailureEntry {
  final String input;
  final List<String> tags;
  final String description;
  final String? expectedQty;
  final String? expectedUnit;
  final String? expectedName;
  final String? expectedSize;
  final String? expectedPrep;
  final String? actualQty;
  final String? actualUnit;
  final String? actualName;
  final String? actualSize;
  final String? actualPrep;

  const FailureEntry({
    required this.input,
    required this.tags,
    required this.description,
    this.expectedQty,
    this.expectedUnit,
    this.expectedName,
    this.expectedSize,
    this.expectedPrep,
    this.actualQty,
    this.actualUnit,
    this.actualName,
    this.actualSize,
    this.actualPrep,
  });
}

/// Maps BioLabel enum names to their string representations
/// for comparison with golden data labels.
String _bioLabelToString(BioLabel label) {
  switch (label) {
    case BioLabel.bQty:
      return 'B-QTY';
    case BioLabel.iQty:
      return 'I-QTY';
    case BioLabel.bUnit:
      return 'B-UNIT';
    case BioLabel.bName:
      return 'B-NAME';
    case BioLabel.iName:
      return 'I-NAME';
    case BioLabel.bPrep:
      return 'B-PREP';
    case BioLabel.iPrep:
      return 'I-PREP';
    case BioLabel.bSize:
      return 'B-SIZE';
    case BioLabel.other:
      return 'O';
  }
}

String _resolveGoldenPath() {
  final candidates = [
    'test/golden/crf_ingredients.json',
    '../test/golden/crf_ingredients.json',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  return '$scriptDir/../golden/crf_ingredients.json';
}

List<CrfGoldenEntry> _loadGoldenData() {
  final path = _resolveGoldenPath();
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      'Golden data file not found at "$path". '
      'Run from project root: flutter test test/evaluation/crf_evaluator.dart',
    );
  }
  final jsonList = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  return jsonList
      .map((e) => CrfGoldenEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

CrfWeights _loadWeights() {
  final candidates = [
    'assets/data/crf_ingredient_weights.json',
    '../assets/data/crf_ingredient_weights.json',
  ];
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) {
      return CrfWeights.fromJson(file.readAsStringSync());
    }
  }
  throw StateError('CRF weights file not found');
}

void main() {
  late CrfIngredientParser parser;
  late CrfViterbiDecoder decoder;
  late List<CrfGoldenEntry> goldenData;
  late CrfEvaluationResult result;

  setUpAll(() {
    final weights = _loadWeights();
    decoder = CrfViterbiDecoder(weights: weights);
    parser = CrfIngredientParser(decoder);
    goldenData = _loadGoldenData();
    result = CrfEvaluationResult();
  });

  test('CRF evaluation against golden dataset', () {
    for (final entry in goldenData) {
      if (entry.tokens.isEmpty) {
        result.recordFieldMatch(entry, null, null, null, null, null);
        continue;
      }

      // Get CRF predictions
      final tokens = CrfIngredientParser.tokenize(entry.input);
      final predLabels = decoder.decode(tokens);
      final predLabelStrings = predLabels.map(_bioLabelToString).toList();

      // Token-level metrics (only if token counts match golden data)
      if (entry.tokens.length == tokens.length) {
        result.recordTokenMetrics(entry.labels, predLabelStrings);
        result.recordSpanMetrics(
          entry.labels,
          entry.tokens,
          predLabelStrings,
          tokens,
        );
      }

      // Field-level: parse the ingredient line
      final parsed = parser.parseLine(entry.input);
      result.recordFieldMatch(
        entry,
        parsed.quantity,
        parsed.unit,
        parsed.name,
        parsed.size,
        parsed.preparation,
      );
    }

    // Generate and print report
    final report = result.generateReport();
    // ignore: avoid_print
    print(report);

    // Threshold: 433-entry human-verified golden dataset (318 original + 115 new)
    final fieldPct = result.allFieldsExact / result.totalEntries * 100;
    expect(
      fieldPct,
      greaterThanOrEqualTo(85.0),
      reason:
          'All-fields exact match should be at least 85%. '
          'Got ${fieldPct.toStringAsFixed(1)}% '
          '(${result.allFieldsExact}/${result.totalEntries})',
    );
  });
}
