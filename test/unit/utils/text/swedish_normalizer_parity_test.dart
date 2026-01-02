import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';

/// CRIT-5: Parity test for Dart ↔ TypeScript normalization.
///
/// This test ensures the Dart normalization matches the expected output
/// defined in the shared fixture file. The TypeScript side has a matching
/// test that reads the same fixture file.
///
/// If this test fails, the normalization contract is broken and cascade
/// retagging will fail silently.
void main() {
  group('SwedishCharacterNormalizer Parity Tests', () {
    late Map<String, dynamic> fixture;

    setUpAll(() {
      final file = File('test/fixtures/swedish_normalization.json');
      final content = file.readAsStringSync();
      fixture = json.decode(content) as Map<String, dynamic>;
    });

    test('fixture file exists and is valid', () {
      expect(fixture['version'], isNotNull);
      expect(fixture['normalizations'], isA<List>());
      expect((fixture['normalizations'] as List).isNotEmpty, isTrue);
    });

    test('all fixture normalizations match Dart implementation', () {
      final normalizations = fixture['normalizations'] as List;
      final failures = <String>[];

      for (final testCase in normalizations) {
        final input = testCase['input'] as String;
        final expected = testCase['expected'] as String;
        final actual = SwedishCharacterNormalizer.normalize(input);

        if (actual != expected) {
          failures.add(
            'Input "$input": expected "$expected", got "$actual"',
          );
        }
      }

      if (failures.isNotEmpty) {
        fail(
          'Normalization parity failures:\n${failures.join('\n')}\n\n'
          'CRITICAL: This breaks the Dart/TypeScript contract!\n'
          'See: functions/src/ingredients/on-ingredient-soft-deleted.ts',
        );
      }

      // Log success count
      expect(normalizations.length, greaterThan(0));
    });

    test('internal testVectors match fixture', () {
      final normalizations = fixture['normalizations'] as List;
      final fixtureMap = <String, String>{};

      for (final testCase in normalizations) {
        fixtureMap[testCase['input'] as String] =
            testCase['expected'] as String;
      }

      // Verify all internal test vectors are in fixture
      for (final entry in SwedishCharacterNormalizer.testVectors.entries) {
        expect(
          fixtureMap[entry.key],
          entry.value,
          reason: 'Internal vector "${entry.key}" should match fixture',
        );
      }
    });
  });
}
