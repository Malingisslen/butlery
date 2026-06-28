/// Direct unit tests for [PropertyRegistry] (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Validates that ingredient-property names used in the allergen/dietary configs
/// are real (catches typos at startup — safety-critical for allergen claims).
/// Covers isValid, getInvalidProperties, validateOrWarn, and — the high-value
/// guard — validateAllConfigs() passing against the SHIPPED configs (proving no
/// property typos have crept in).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/tagging/config/property_registry.dart';

void main() {
  group('isValid', () {
    test('true for known properties', () {
      expect(PropertyRegistry.isValid('dairy'), isTrue);
      expect(PropertyRegistry.isValid('vegan-friendly'), isTrue);
      expect(PropertyRegistry.isValid('contains-gluten'), isTrue);
    });

    test('false for unknown / mistyped properties', () {
      expect(PropertyRegistry.isValid('daiyr'), isFalse); // typo
      expect(PropertyRegistry.isValid('bogus'), isFalse);
    });
  });

  group('getInvalidProperties', () {
    test('returns only the unknown entries', () {
      final invalid = PropertyRegistry.getInvalidProperties([
        'dairy',
        'egg',
        'bogus',
        'daiyr',
      ]);
      expect(invalid, {'bogus', 'daiyr'});
    });

    test('is empty when all are valid', () {
      expect(
        PropertyRegistry.getInvalidProperties(['dairy', 'soy']),
        isEmpty,
      );
    });
  });

  group('validateOrWarn', () {
    test('returns true for a valid property, false otherwise', () {
      expect(PropertyRegistry.validateOrWarn('dairy', 'test'), isTrue);
      expect(PropertyRegistry.validateOrWarn('bogus', 'test'), isFalse);
    });
  });

  group('validateAllConfigs (shipped-config typo guard)', () {
    test(
      'the real allergen + dietary configs reference only valid properties',
      () {
        expect(PropertyRegistry.validateAllConfigs, returnsNormally);
      },
    );
  });
}
