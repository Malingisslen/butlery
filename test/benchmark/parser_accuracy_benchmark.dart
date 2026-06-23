import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:butlery/utils/text/ingredient_processor.dart';

/// Fixture entry representing a single benchmark test case.
class BenchmarkFixture {
  final String input;
  final double expectedQuantity;
  final String expectedUnit;
  final String expectedNormalizedName;
  final bool expectedIsKnown;
  final String? expectedCategory;
  final List<String> tags;
  final String description;

  const BenchmarkFixture({
    required this.input,
    required this.expectedQuantity,
    required this.expectedUnit,
    required this.expectedNormalizedName,
    required this.expectedIsKnown,
    required this.expectedCategory,
    required this.tags,
    required this.description,
  });

  factory BenchmarkFixture.fromJson(Map<String, dynamic> json) {
    final expected = json['expected'] as Map<String, dynamic>;
    return BenchmarkFixture(
      input: json['input'] as String,
      expectedQuantity: (expected['quantity'] as num).toDouble(),
      expectedUnit: expected['unit'] as String,
      expectedNormalizedName: expected['normalizedName'] as String,
      expectedIsKnown: expected['isKnown'] as bool,
      expectedCategory: expected['category'] as String?,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      description: json['description'] as String,
    );
  }

  /// Short label for test names: first tag + truncated input.
  String get label {
    final tag = tags.first;
    final display = input.length > 40 ? '${input.substring(0, 37)}...' : input;
    return '$tag: $display';
  }
}

/// Per-field comparison result for a single fixture.
class FieldResult {
  final bool quantityMatch;
  final bool unitMatch;
  final bool normalizedNameMatch;
  final bool isKnownMatch;
  final bool categoryMatch;

  const FieldResult({
    required this.quantityMatch,
    required this.unitMatch,
    required this.normalizedNameMatch,
    required this.isKnownMatch,
    required this.categoryMatch,
  });

  bool get allMatch =>
      quantityMatch &&
      unitMatch &&
      normalizedNameMatch &&
      isKnownMatch &&
      categoryMatch;
}

/// Accumulated accuracy metrics across all fixtures.
class AccuracyMetrics {
  int total = 0;
  int exactMatches = 0;
  int quantityMatches = 0;
  int unitMatches = 0;
  int normalizedNameMatches = 0;
  int isKnownMatches = 0;
  int categoryMatches = 0;

  final Map<String, TagMetrics> tagMetrics = {};
  final List<FailureEntry> failures = [];

  void record(
    BenchmarkFixture fixture,
    ProcessedIngredient actual,
    FieldResult result,
  ) {
    total++;
    if (result.quantityMatch) quantityMatches++;
    if (result.unitMatch) unitMatches++;
    if (result.normalizedNameMatch) normalizedNameMatches++;
    if (result.isKnownMatch) isKnownMatches++;
    if (result.categoryMatch) categoryMatches++;
    if (result.allMatch) exactMatches++;

    for (final tag in fixture.tags) {
      tagMetrics.putIfAbsent(tag, () => TagMetrics(tag));
      tagMetrics[tag]!.record(result);
    }

    if (!result.allMatch) {
      failures.add(
        FailureEntry(
          fixture: fixture,
          actual: actual,
          result: result,
        ),
      );
    }
  }

  String generateReport() {
    final buf = StringBuffer()
      ..writeln('')
      ..writeln('=== PARSER ACCURACY BENCHMARK REPORT ===')
      ..writeln('')
      ..writeln('OVERALL:')
      ..writeln(
        '  Exact match: $exactMatches/$total (${_pct(exactMatches, total)})',
      )
      ..writeln('')
      ..writeln('PER-FIELD ACCURACY:')
      ..writeln(
        '  quantity:       $quantityMatches/$total (${_pct(quantityMatches, total)})',
      )
      ..writeln(
        '  unit:           $unitMatches/$total (${_pct(unitMatches, total)})',
      )
      ..writeln(
        '  normalizedName: $normalizedNameMatches/$total (${_pct(normalizedNameMatches, total)})',
      )
      ..writeln(
        '  isKnown:        $isKnownMatches/$total (${_pct(isKnownMatches, total)})',
      )
      ..writeln(
        '  category:       $categoryMatches/$total (${_pct(categoryMatches, total)})',
      )
      ..writeln('')
      ..writeln('PER-TAG BREAKDOWN:');

    final sortedTags = tagMetrics.keys.toList()..sort();
    for (final tag in sortedTags) {
      final m = tagMetrics[tag]!;
      buf.writeln(
        '  $tag: ${m.exactMatches}/${m.total} exact (${_pct(m.exactMatches, m.total)})',
      );
    }

    if (failures.isNotEmpty) {
      buf
        ..writeln('')
        ..writeln('REGRESSIONS (${failures.length} failures):');
      for (final f in failures) {
        buf
          ..writeln('')
          ..writeln(
            '  INPUT: "${f.fixture.input}" [${f.fixture.tags.join(", ")}]',
          )
          ..writeln('  DESC:  ${f.fixture.description}');
        _writeFieldDiff(buf, f);
      }
    }

    buf
      ..writeln('')
      ..writeln('=== END REPORT ===');
    return buf.toString();
  }

  void _writeFieldDiff(StringBuffer buf, FailureEntry f) {
    if (!f.result.quantityMatch) {
      buf.writeln(
        '    quantity:       expected=${f.fixture.expectedQuantity}, '
        'actual=${f.actual.quantity}',
      );
    }
    if (!f.result.unitMatch) {
      buf.writeln(
        '    unit:           expected="${f.fixture.expectedUnit}", '
        'actual="${f.actual.unit}"',
      );
    }
    if (!f.result.normalizedNameMatch) {
      buf.writeln(
        '    normalizedName: expected="${f.fixture.expectedNormalizedName}", '
        'actual="${f.actual.normalizedName}"',
      );
    }
    if (!f.result.isKnownMatch) {
      buf.writeln(
        '    isKnown:        expected=${f.fixture.expectedIsKnown}, '
        'actual=${f.actual.isKnown}',
      );
    }
    if (!f.result.categoryMatch) {
      buf.writeln(
        '    category:       expected=${f.fixture.expectedCategory}, '
        'actual=${f.actual.category}',
      );
    }
  }

  static String _pct(int n, int d) {
    if (d == 0) return 'N/A';
    return '${(n / d * 100).toStringAsFixed(1)}%';
  }
}

class TagMetrics {
  final String tag;
  int total = 0;
  int exactMatches = 0;

  TagMetrics(this.tag);

  void record(FieldResult result) {
    total++;
    if (result.allMatch) exactMatches++;
  }
}

class FailureEntry {
  final BenchmarkFixture fixture;
  final ProcessedIngredient actual;
  final FieldResult result;

  const FailureEntry({
    required this.fixture,
    required this.actual,
    required this.result,
  });
}

String _resolveFixturePath() {
  final candidates = [
    'test/benchmark/fixtures/swedish_ingredients.json',
    '../test/benchmark/fixtures/swedish_ingredients.json',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  final scriptDir = File(Platform.script.toFilePath()).parent.path;
  return '$scriptDir/fixtures/swedish_ingredients.json';
}

List<BenchmarkFixture> _loadFixtures() {
  final path = _resolveFixturePath();
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError(
      'Fixture file not found at "$path". '
      'Run from project root: flutter test test/benchmark/parser_accuracy_benchmark.dart',
    );
  }
  final jsonList = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  return jsonList
      .map((e) => BenchmarkFixture.fromJson(e as Map<String, dynamic>))
      .toList();
}

FieldResult _compare(BenchmarkFixture fixture, ProcessedIngredient actual) {
  return FieldResult(
    quantityMatch: _quantityClose(actual.quantity, fixture.expectedQuantity),
    unitMatch: actual.unit == fixture.expectedUnit,
    normalizedNameMatch:
        actual.normalizedName == fixture.expectedNormalizedName,
    isKnownMatch: actual.isKnown == fixture.expectedIsKnown,
    categoryMatch: actual.category == fixture.expectedCategory,
  );
}

bool _quantityClose(double a, double b, {double epsilon = 0.001}) {
  return (a - b).abs() < epsilon;
}

void _runFixture(BenchmarkFixture fixture, AccuracyMetrics metrics) {
  final actual = IngredientProcessor.processRawIngredient(fixture.input);
  final result = _compare(fixture, actual);
  metrics.record(fixture, actual, result);

  if (!result.allMatch) {
    final mismatches = <String>[];
    if (!result.quantityMatch) {
      mismatches.add(
        'quantity: expected=${fixture.expectedQuantity}, '
        'actual=${actual.quantity}',
      );
    }
    if (!result.unitMatch) {
      mismatches.add(
        'unit: expected="${fixture.expectedUnit}", '
        'actual="${actual.unit}"',
      );
    }
    if (!result.normalizedNameMatch) {
      mismatches.add(
        'normalizedName: expected="${fixture.expectedNormalizedName}", '
        'actual="${actual.normalizedName}"',
      );
    }
    if (!result.isKnownMatch) {
      mismatches.add(
        'isKnown: expected=${fixture.expectedIsKnown}, '
        'actual=${actual.isKnown}',
      );
    }
    if (!result.categoryMatch) {
      mismatches.add(
        'category: expected=${fixture.expectedCategory}, '
        'actual=${actual.category}',
      );
    }
    fail(
      'Mismatch for "${fixture.input}" (${fixture.description}):\n'
      '  ${mismatches.join('\n  ')}',
    );
  }
}

void main() {
  final fixtures = _loadFixtures();
  final metrics = AccuracyMetrics();

  for (final fixture in fixtures) {
    test(fixture.label, () {
      _runFixture(fixture, metrics);
    });
  }

  // Summary report runs last, after all individual fixture tests.
  test('BENCHMARK SUMMARY', () {
    final report = metrics.generateReport();
    // ignore: avoid_print
    print(report);

    final exactPct = metrics.exactMatches / metrics.total * 100;
    expect(
      exactPct,
      greaterThanOrEqualTo(80.0),
      reason:
          'Overall exact match rate should be at least 80%. '
          'Got ${exactPct.toStringAsFixed(1)}% '
          '(${metrics.exactMatches}/${metrics.total})',
    );

    final qtyPct = metrics.quantityMatches / metrics.total * 100;
    expect(
      qtyPct,
      greaterThanOrEqualTo(90.0),
      reason:
          'Quantity accuracy should be at least 90%. '
          'Got ${qtyPct.toStringAsFixed(1)}%',
    );

    final unitPct = metrics.unitMatches / metrics.total * 100;
    expect(
      unitPct,
      greaterThanOrEqualTo(90.0),
      reason:
          'Unit accuracy should be at least 90%. '
          'Got ${unitPct.toStringAsFixed(1)}%',
    );

    final namePct = metrics.normalizedNameMatches / metrics.total * 100;
    expect(
      namePct,
      greaterThanOrEqualTo(85.0),
      reason:
          'NormalizedName accuracy should be at least 85%. '
          'Got ${namePct.toStringAsFixed(1)}%',
    );
  });
}
