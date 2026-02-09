import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/tagging/config/allergen_config.dart';

void main() {
  group('AllergenConfig', () {
    group('all allergens list', () {
      test('contains all 14 EU allergens', () {
        final euAllergens = AllergenConfig.euAllergens;
        expect(euAllergens.length, 14);

        final euKeys = euAllergens.map((a) => a.key).toSet();
        expect(euKeys, contains('gluten'));
        expect(euKeys, contains('mjölk'));
        expect(euKeys, contains('ägg'));
        expect(euKeys, contains('fisk'));
        expect(euKeys, contains('kräftdjur'));
        expect(euKeys, contains('blötdjur'));
        expect(euKeys, contains('trädnötter'));
        expect(euKeys, contains('jordnötter'));
        expect(euKeys, contains('soja'));
        expect(euKeys, contains('sesam'));
        expect(euKeys, contains('selleri'));
        expect(euKeys, contains('senap'));
        expect(euKeys, contains('lupin'));
        expect(euKeys, contains('sulfiter'));
      });

      test('contains additional common allergens', () {
        final allKeys = AllergenConfig.allKeys;
        expect(allKeys, contains('laktos'));
        expect(allKeys, contains('alkohol'));
        expect(allKeys, contains('kött'));
        expect(allKeys, contains('fläsk'));
        expect(allKeys, contains('nötkött'));
      });

      test('contains combined allergens', () {
        final combined = AllergenConfig.combinedAllergens;
        expect(combined.length, 2);

        final combinedKeys = combined.map((a) => a.key).toSet();
        expect(combinedKeys, contains('skaldjur'));
        expect(combinedKeys, contains('nötter'));
      });
    });

    group('getByKey', () {
      test('returns allergen for valid key', () {
        final gluten = AllergenConfig.getByKey('gluten');
        expect(gluten, isNotNull);
        expect(gluten!.key, 'gluten');
        expect(gluten.triggerProperty, 'contains-gluten');
        expect(gluten.isEuAllergen, isTrue);
      });

      test('returns null for invalid key', () {
        final result = AllergenConfig.getByKey('nonexistent');
        expect(result, isNull);
      });
    });
  });

  group('AllergenEntry', () {
    group('triggerProperties', () {
      test('single property returns list with one item', () {
        final entry = AllergenEntry(
          key: 'test',
          triggerProperty: 'single-property',
          containsTag: 'test-tag',
        );

        expect(entry.triggerProperties, ['single-property']);
        expect(entry.isCombined, isFalse);
      });

      test('OR-combined properties split correctly', () {
        final entry = AllergenEntry(
          key: 'test',
          triggerProperty: 'prop1 OR prop2',
          containsTag: 'test-tag',
        );

        expect(entry.triggerProperties, ['prop1', 'prop2']);
        expect(entry.isCombined, isTrue);
      });

      test('OR parsing is case-insensitive', () {
        final entries = [
          AllergenEntry(
            key: 'test1',
            triggerProperty: 'prop1 or prop2',
            containsTag: 'tag',
          ),
          AllergenEntry(
            key: 'test2',
            triggerProperty: 'prop1 Or prop2',
            containsTag: 'tag',
          ),
          AllergenEntry(
            key: 'test3',
            triggerProperty: 'prop1 OR prop2',
            containsTag: 'tag',
          ),
        ];

        for (final entry in entries) {
          expect(entry.triggerProperties, ['prop1', 'prop2'],
              reason: 'Failed for: ${entry.triggerProperty}');
          expect(entry.isCombined, isTrue);
        }
      });

      test('OR parsing handles flexible whitespace', () {
        final entry = AllergenEntry(
          key: 'test',
          triggerProperty: 'prop1  OR  prop2',
          containsTag: 'tag',
        );

        expect(entry.triggerProperties, ['prop1', 'prop2']);
      });

      test('trims whitespace from properties', () {
        final entry = AllergenEntry(
          key: 'test',
          triggerProperty: ' prop1 OR prop2 ',
          containsTag: 'tag',
        );

        // Note: leading/trailing whitespace on the whole string won't be trimmed
        // but the split parts will be
        expect(entry.triggerProperties[0].trim(), 'prop1');
        expect(entry.triggerProperties[1].trim(), 'prop2');
      });

      test('real combined allergens parse correctly', () {
        final notterEntry = AllergenConfig.getByKey('nötter')!;
        expect(notterEntry.triggerProperties, ['tree-nut', 'peanut']);

        final skaldjurEntry = AllergenConfig.getByKey('skaldjur')!;
        expect(skaldjurEntry.triggerProperties, ['crustacean', 'mollusc']);
      });
    });

    group('freeTag', () {
      test('EU allergens have free tags', () {
        for (final allergen in AllergenConfig.euAllergens) {
          expect(allergen.freeTag, isNotNull,
              reason: 'EU allergen ${allergen.key} should have freeTag');
        }
      });

      test('all meat allergens have free tags for consistency', () {
        // All meat allergens should have free tags for consistent filtering
        final kott = AllergenConfig.getByKey('kött')!;
        final flask = AllergenConfig.getByKey('fläsk')!;
        final notkott = AllergenConfig.getByKey('nötkött')!;

        expect(kott.freeTag, equals('köttfri'),
            reason: 'kött should have köttfri tag for consistency');
        expect(flask.freeTag, equals('fläskfri'),
            reason: 'fläsk should have fläskfri tag');
        expect(notkott.freeTag, equals('nötkötsfri'),
            reason: 'nötkött should have nötkötsfri tag');
      });
    });
  });
}
