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
import 'package:butlery/services/tagging/config/valid_properties.dart';

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

  group('category partition (rule-dialog dropdown source, BUT-1618)', () {
    test('every valid property appears in exactly one category', () {
      final all = kIngredientPropertyCategories.values
          .expand((properties) => properties)
          .toList();
      expect(
        all.length,
        all.toSet().length,
        reason:
            'a property listed in two categories gives the rule dialog '
            'dropdown two items with the same value — a DropdownButton '
            'assertion crash when editing a rule that stores that value',
      );
      expect(all.toSet(), kValidIngredientProperties);
    });

    test('retired wheat stays out of the vocabulary (BUT-1498)', () {
      expect(PropertyRegistry.isValid('wheat'), isFalse);
      expect(PropertyRegistry.isValid('shellfish'), isTrue);
    });

    test('the category id set is fixed — a new one needs a dialog label', () {
      // The rule dialog's `_categoryLabel` switch maps these ids to localized
      // headers. It is parallel to this map, so a new category id here would
      // silently render its raw English id as a Swedish-UI header. Pinning the
      // set forces whoever adds a category to also add the label case.
      expect(kIngredientPropertyCategories.keys.toSet(), {
        'allergens',
        'lactose',
        'meat',
        'seafood',
        'animal',
        'diet',
        'other',
      });
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
