import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/firebase_tag_config.dart';
import 'package:butlery/services/tagging/ingredient_tag_preview.dart';

import '../../../test_support/ingredient_review_fixtures.dart';

void main() {
  final config = ingredientReviewConfig();

  group('allergens', () {
    test('gives gluten when the trigger property is present', () {
      final p = previewIngredientTags({'contains-gluten'}, config);
      expect(p.allergenKeys, ['gluten']);
    });

    test('gives no gluten without the trigger property', () {
      final p = previewIngredientTags({'meat'}, config);
      expect(p.allergenKeys, isEmpty);
    });

    test('a combined allergen fires on any of its trigger properties', () {
      expect(previewIngredientTags({'peanut'}, config).allergenKeys, [
        'nötter',
      ]);
      expect(
        previewIngredientTags({'tree-nut'}, config).allergenKeys,
        ['nötter'],
      );
    });
  });

  group('diets', () {
    test('an excluded property breaks the diet', () {
      final p = previewIngredientTags({'meat'}, config);
      expect(p.brokenDietKeys, ['vegetarian']);
    });

    test('an ingredient without excluded properties breaks nothing', () {
      final p = previewIngredientTags({'contains-gluten'}, config);
      expect(p.brokenDietKeys, isEmpty);
    });
  });

  group('rules the shared config does not exercise', () {
    FirebaseTagConfig configWith({
      required List<Map<String, Object?>> allergens,
      required List<Map<String, Object?>> diets,
    }) => FirebaseTagConfig.fromDocuments(
      allergensData: {
        'schemaVersion': 1,
        'version': 1,
        'updatedBy': 'test',
        'displayOrder': [for (final a in allergens) a['key']],
        'entries': allergens,
      },
      dietaryData: {
        'schemaVersion': 1,
        'version': 1,
        'updatedBy': 'test',
        'displayOrder': [for (final d in diets) d['key']],
        'entries': diets,
      },
      cuisinesData: const {},
      propertiesData: const {},
      displayData: const {},
    );

    test('a required property alone never breaks a diet', () {
      final c = configWith(
        allergens: const [],
        diets: [
          {
            'key': 'vegan',
            'tags': {'sv': 'vegansk'},
            'excludedProperties': ['dairy'],
            'requiredProperties': ['plant-based'],
            'enabled': true,
          },
        ],
      );
      expect(previewIngredientTags({'meat'}, c).brokenDietKeys, isEmpty);
      expect(previewIngredientTags({'dairy'}, c).brokenDietKeys, ['vegan']);
    });

    test('a disabled allergen and a disabled diet are ignored', () {
      final c = configWith(
        allergens: [
          {
            'key': 'gluten',
            'triggerProperties': ['contains-gluten'],
            'enabled': false,
          },
        ],
        diets: [
          {
            'key': 'vegetarian',
            'tags': {'sv': 'vegetarisk'},
            'excludedProperties': ['meat'],
            'enabled': false,
          },
        ],
      );
      final p = previewIngredientTags({'contains-gluten', 'meat'}, c);
      expect(p.allergenKeys, isEmpty);
      expect(p.brokenDietKeys, isEmpty);
    });

    test('an allergen with no trigger properties is skipped, not a crash', () {
      final c = configWith(
        allergens: [
          {'key': 'tom', 'triggerProperties': <String>[], 'enabled': true},
          {
            'key': 'gluten',
            'triggerProperties': ['contains-gluten'],
            'enabled': true,
          },
        ],
        diets: const [],
      );
      expect(c.allergens.enabledEntries.map((e) => e.key), ['tom', 'gluten']);
      expect(
        previewIngredientTags({'contains-gluten'}, c).allergenKeys,
        ['gluten'],
      );
    });

    test('allergens come back in config display order', () {
      final p = previewIngredientTags({'peanut', 'contains-gluten'}, config);
      expect(p.allergenKeys, ['gluten', 'nötter']);
    });
  });
}
