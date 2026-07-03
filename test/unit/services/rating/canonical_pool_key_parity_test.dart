// Dart side of the cross-language parity contract (condition C4). Reads the
// SAME fixture as functions/src/__tests__/pool-key-parity.test.ts. If the Dart
// hint and the TS authority ever diverge, pool routing breaks — this test and
// its TS twin must both stay green against the shared fixture.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/rating/canonical_pool_key.dart';

void main() {
  final fixtureFile = File('test/fixtures/pool_key_parity.json');
  final fixture =
      jsonDecode(fixtureFile.readAsStringSync()) as Map<String, dynamic>;
  final cases = (fixture['cases'] as List).cast<Map<String, dynamic>>();

  group('CanonicalPoolKey parity fixture', () {
    for (final c in cases) {
      test('${c['name']}', () {
        final actual = CanonicalPoolKey.compute(
          title: c['title'] as String,
          ingredients: (c['ingredients'] as List).cast<String>(),
        );
        final expected = c['expected'];
        // Bootstrap is done — every case must carry a real expected value. Guard
        // against a case being reset to the capture placeholder and passing
        // without asserting.
        expect(
          expected,
          isNot('__CAPTURE__'),
          reason:
              '${c['name']} is uncaptured; run once to capture then pin it.',
        );
        expect(
          actual,
          expected,
          reason:
              'parity drift for ${c['name']} — Dart and the fixture disagree; '
              'the TS twin reads the same fixture.',
        );
      });
    }
  });
}
