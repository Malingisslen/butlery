/// Unit tests for parsedIngredientFromExtracted — ingredient field mapping.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../test_support/base_unit_test.dart';
import 'package:butlery/services/parsing/ingredient_conversion.dart';
import 'package:butlery/services/llm/llm_models.dart';
import 'package:butlery/models/parsing/field_result.dart';

void main() {
  group('parsedIngredientFromExtracted', () {
    setUp(() async => await BaseUnitTest.setupUnit());
    tearDown(() => BaseUnitTest.resetMocks());

    test('whole number amount formatted as int string', () {
      final extracted = ExtractedIngredient(
        amount: 1.0,
        unit: 'dl',
        name: 'mjöl',
      );
      final result = parsedIngredientFromExtracted(extracted);
      expect(result.quantity, '1');
    });

    test('decimal amount preserved', () {
      final extracted = ExtractedIngredient(
        amount: 1.5,
        unit: 'dl',
        name: 'mjöl',
      );
      final result = parsedIngredientFromExtracted(extracted);
      expect(result.quantity, '1.5');
    });

    test('null amount gives null quantity', () {
      final extracted = ExtractedIngredient(
        name: 'salt',
      );
      final result = parsedIngredientFromExtracted(extracted);
      expect(result.quantity, isNull);
    });

    test('unit passed through', () {
      final extracted = ExtractedIngredient(
        amount: 2.0,
        unit: 'msk',
        name: 'socker',
      );
      final result = parsedIngredientFromExtracted(extracted);
      expect(result.unit, 'msk');
    });

    test('name passed through', () {
      final extracted = ExtractedIngredient(
        name: 'smör',
      );
      final result = parsedIngredientFromExtracted(extracted);
      expect(result.name, 'smör');
    });

    test('default confidence is medium', () {
      final extracted = ExtractedIngredient(name: 'salt');
      final result = parsedIngredientFromExtracted(extracted);
      expect(result.confidence, ParseConfidence.medium);
    });

    test('custom confidence passed through', () {
      final extracted = ExtractedIngredient(name: 'salt');
      final result = parsedIngredientFromExtracted(
        extracted,
        confidence: ParseConfidence.high,
      );
      expect(result.confidence, ParseConfidence.high);
    });

    test('originalLine defaults to formatted', () {
      final extracted = ExtractedIngredient(
        amount: 2.0,
        unit: 'dl',
        name: 'mjöl',
      );
      final result = parsedIngredientFromExtracted(extracted);
      expect(result.originalLine, extracted.formatted);
    });

    test('custom originalLine overrides formatted', () {
      final extracted = ExtractedIngredient(name: 'salt');
      final result = parsedIngredientFromExtracted(
        extracted,
        originalLine: 'en nypa salt',
      );
      expect(result.originalLine, 'en nypa salt');
    });

    test('section passes through the bridge', () {
      final result = parsedIngredientFromExtracted(
        ExtractedIngredient(
          name: 'jäst',
          amount: 25.0,
          unit: 'g',
          section: 'Deg',
        ),
      );
      expect(result.section, 'Deg');
    });

    test('blank section normalizes to null at the bridge — ParsedIngredient '
        'itself never normalizes, so this is the last line of defense', () {
      final result = parsedIngredientFromExtracted(
        ExtractedIngredient(name: 'salt', section: '   '),
      );
      expect(result.section, isNull);
    });
  });
}
