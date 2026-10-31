// The golden is never rewritten by this test: a red case
// here means a recipe would now get different occasion or season tags.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'phase4_equivalence_runner.dart';

void main() {
  final cases =
      (jsonDecode(
                File(
                  'test/fixtures/tagging/phase4_equivalence_golden.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();

  test('the golden holds enough cases to mean something', () {
    expect(cases.length, greaterThan(1000));
  });

  test('every recorded case gives the recorded Phase 4 tags', () {
    final mismatches = <String>[];
    for (final c in cases) {
      final input = (c['input'] as Map).cast<String, dynamic>();
      final expected = (c['expected'] as List).cast<String>();
      final actual = runPhase4Case(input);
      if (actual.join(',') != expected.join(',')) {
        mismatches.add(
          '${jsonEncode(input)}\n  expected $expected\n  actual   $actual',
        );
      }
    }
    expect(mismatches, isEmpty, reason: mismatches.take(10).join('\n'));
  });
}
