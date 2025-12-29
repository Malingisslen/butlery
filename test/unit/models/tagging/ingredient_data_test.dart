import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';

void main() {
  group('IngredientData', () {
    group('construction', () {
      test('creates with required parameters', () {
        final ingredient = IngredientData(
          id: 'chicken-breast',
          swedish: 'kycklingbröst',
          english: 'chicken breast',
          group: 'protein/meat/poultry',
          properties: {'meat', 'poultry', 'animal-product'},
        );

        expect(ingredient.id, 'chicken-breast');
        expect(ingredient.swedish, 'kycklingbröst');
        expect(ingredient.english, 'chicken breast');
        expect(ingredient.group, 'protein/meat/poultry');
        expect(ingredient.properties, {'meat', 'poultry', 'animal-product'});
        expect(ingredient.aliasesSv, isEmpty);
        expect(ingredient.aliasesEn, isEmpty);
        expect(ingredient.searchTerms, isEmpty);
        expect(ingredient.status, 'verified');
      });

      test('creates with all optional parameters', () {
        final now = DateTime.now();
        final ingredient = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables/fruits',
          properties: {'plant-based', 'vegan-friendly'},
          aliasesSv: ['tomater', 'krossade tomater'],
          aliasesEn: ['tomatoes'],
          searchTerms: ['röd', 'frukt'],
          status: 'draft',
          createdAt: now,
          updatedAt: now,
        );

        expect(ingredient.aliasesSv, ['tomater', 'krossade tomater']);
        expect(ingredient.aliasesEn, ['tomatoes']);
        expect(ingredient.searchTerms, ['röd', 'frukt']);
        expect(ingredient.status, 'draft');
        expect(ingredient.createdAt, now);
        expect(ingredient.updatedAt, now);
      });
    });

    group('CRIT-1: equality - ID-only contract', () {
      test('same ID means equal, regardless of other fields', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {'plant-based'},
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat (röda)', // Different swedish name
          english: 'red tomato', // Different english name
          group: 'vegetables/fruits', // Different group
          properties: {'plant-based', 'vegan-friendly'}, // Different properties
        );

        // ID-only equality: same ID = equal
        expect(a == b, isTrue);
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different ID means not equal', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {'plant-based'},
        );
        final b = IngredientData(
          id: 'sun-dried-tomato', // Different ID
          swedish: 'tomat', // Same swedish name
          english: 'tomato', // Same english name
          group: 'vegetables', // Same group
          properties: {'plant-based'}, // Same properties
        );

        expect(a == b, isFalse);
        expect(a.hashCode, isNot(equals(b.hashCode)));
      });

      test('identical returns true for same instance', () {
        final ingredient = IngredientData(
          id: 'test',
          swedish: 'test',
          english: 'test',
          group: 'test',
          properties: {},
        );

        expect(identical(ingredient, ingredient), isTrue);
        expect(ingredient == ingredient, isTrue);
      });

      test('works correctly in Set operations', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {'plant-based'},
        );
        final b = IngredientData(
          id: 'tomato', // Same ID = same ingredient
          swedish: 'röd tomat',
          english: 'red tomato',
          group: 'vegetables/fruits',
          properties: {'plant-based', 'colored'},
        );
        final c = IngredientData(
          id: 'onion', // Different ID
          swedish: 'lök',
          english: 'onion',
          group: 'vegetables',
          properties: {'plant-based'},
        );

        final set = <IngredientData>{a, b, c};

        // a and b have same ID, so only one should be in set
        expect(set.length, 2);
        expect(set.contains(a), isTrue);
        expect(set.contains(b), isTrue); // Same as a
        expect(set.contains(c), isTrue);
      });

      test('works correctly in Map operations', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
        );
        final b = IngredientData(
          id: 'tomato', // Same ID
          swedish: 'annat namn',
          english: 'different name',
          group: 'other',
          properties: {'different'},
        );

        final map = <IngredientData, String>{};
        map[a] = 'first';
        map[b] = 'second'; // Should overwrite first

        expect(map.length, 1);
        expect(map[a], 'second');
        expect(map[b], 'second');
      });
    });

    group('CRIT-1: contentEquals - full field comparison', () {
      test('returns true when all fields are equal', () {
        final now = DateTime(2024, 1, 1, 12, 0, 0);
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {'plant-based', 'vegan-friendly'},
          aliasesSv: ['tomater'],
          aliasesEn: ['tomatoes'],
          searchTerms: ['red'],
          status: 'verified',
          createdAt: now,
          updatedAt: now,
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {'plant-based', 'vegan-friendly'},
          aliasesSv: ['tomater'],
          aliasesEn: ['tomatoes'],
          searchTerms: ['red'],
          status: 'verified',
          createdAt: now,
          updatedAt: now,
        );

        expect(a.contentEquals(b), isTrue);
      });

      test('returns false when ID differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
        );
        final b = IngredientData(
          id: 'tomato-red',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when swedish differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'röd tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when english differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'red tomato',
          group: 'vegetables',
          properties: {},
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when group differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables/fruits',
          properties: {},
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when properties differ', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {'plant-based'},
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {'plant-based', 'vegan-friendly'},
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when aliasesSv differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          aliasesSv: ['tomater'],
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          aliasesSv: ['krossade tomater'],
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when aliasesEn differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          aliasesEn: ['tomatoes'],
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          aliasesEn: ['red tomatoes'],
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when searchTerms differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          searchTerms: ['red'],
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          searchTerms: ['red', 'fruit'],
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when status differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          status: 'verified',
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          status: 'draft',
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when createdAt differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          createdAt: DateTime(2024, 1, 1),
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          createdAt: DateTime(2024, 1, 2),
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when updatedAt differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          updatedAt: DateTime(2024, 1, 1),
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          updatedAt: DateTime(2024, 1, 2),
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('handles null DateTime fields correctly', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          createdAt: null,
          updatedAt: null,
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          createdAt: null,
          updatedAt: null,
        );

        expect(a.contentEquals(b), isTrue);
      });

      test('Set order does not affect contentEquals for properties', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {'a', 'b', 'c'},
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {
            'c',
            'b',
            'a'
          }, // Same elements, different insertion order
        );

        expect(a.contentEquals(b), isTrue);
      });

      test('List order affects contentEquals for aliases', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          aliasesSv: ['a', 'b'],
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {},
          aliasesSv: ['b', 'a'], // Same elements, different order
        );

        // List comparison is order-sensitive
        expect(a.contentEquals(b), isFalse);
      });
    });

    group('Firestore serialization', () {
      test('toFirestore creates valid map', () {
        final now = DateTime(2024, 1, 15);
        final ingredient = IngredientData(
          id: 'chicken-breast',
          swedish: 'kycklingbröst',
          english: 'chicken breast',
          group: 'protein/meat/poultry',
          properties: {'meat', 'poultry'},
          aliasesSv: ['kycklingfilé'],
          aliasesEn: ['chicken fillet'],
          searchTerms: ['kyckling'],
          status: 'verified',
          createdAt: now,
          updatedAt: now,
        );

        final map = ingredient.toFirestore();

        expect(map['id'], 'chicken-breast');
        expect(map['swedish'], 'kycklingbröst');
        expect(map['english'], 'chicken breast');
        expect(map['group'], 'protein/meat/poultry');
        expect(map['properties'], containsAll(['meat', 'poultry']));
        expect(map['aliasesSv'], ['kycklingfilé']);
        expect(map['aliasesEn'], ['chicken fillet']);
        expect(map['searchTerms'], ['kyckling']);
        expect(map['status'], 'verified');
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['updatedAt'], isA<Timestamp>());
      });

      test('fromMap parses valid data', () {
        final map = {
          'id': 'tomato',
          'swedish': 'tomat',
          'english': 'tomato',
          'group': 'vegetables',
          'properties': ['plant-based', 'vegan-friendly'],
          'aliasesSv': ['tomater'],
          'aliasesEn': ['tomatoes'],
          'searchTerms': ['red'],
          'status': 'verified',
        };

        final ingredient = IngredientData.fromMap(map);

        expect(ingredient.id, 'tomato');
        expect(ingredient.swedish, 'tomat');
        expect(ingredient.english, 'tomato');
        expect(ingredient.group, 'vegetables');
        expect(ingredient.properties, {'plant-based', 'vegan-friendly'});
        expect(ingredient.aliasesSv, ['tomater']);
        expect(ingredient.aliasesEn, ['tomatoes']);
        expect(ingredient.searchTerms, ['red']);
        expect(ingredient.status, 'verified');
      });

      test('fromMap handles ID override', () {
        final map = {
          'id': 'original-id',
          'swedish': 'test',
          'english': 'test',
          'group': 'test',
          'properties': [],
        };

        final ingredient = IngredientData.fromMap(map, 'override-id');

        expect(ingredient.id, 'override-id');
      });

      test('fromMap handles legacy snake_case fields', () {
        final map = {
          'id': 'test',
          'swedish': 'test',
          'english': 'test',
          'group': 'test',
          'properties': [],
          'aliases_sv': ['alias1'], // Legacy field
          'aliases_en': ['alias2'], // Legacy field
          'search_terms': ['term'], // Legacy field
        };

        final ingredient = IngredientData.fromMap(map);

        expect(ingredient.aliasesSv, ['alias1']);
        expect(ingredient.aliasesEn, ['alias2']);
        expect(ingredient.searchTerms, ['term']);
      });

      test('fromMap handles comma-separated properties string', () {
        final map = {
          'id': 'test',
          'swedish': 'test',
          'english': 'test',
          'group': 'test',
          'properties':
              'plant-based, vegan-friendly, gluten-free', // String format
        };

        final ingredient = IngredientData.fromMap(map);

        expect(ingredient.properties,
            {'plant-based', 'vegan-friendly', 'gluten-free'});
      });

      test('fromMap handles semicolon-separated aliases string', () {
        final map = {
          'id': 'test',
          'swedish': 'test',
          'english': 'test',
          'group': 'test',
          'properties': [],
          'aliasesSv': 'alias1; alias2; alias3', // String format
        };

        final ingredient = IngredientData.fromMap(map);

        expect(ingredient.aliasesSv, ['alias1', 'alias2', 'alias3']);
      });

      test('roundtrip serialization preserves data', () {
        final original = IngredientData(
          id: 'test-ingredient',
          swedish: 'testingrediens',
          english: 'test ingredient',
          group: 'test/group',
          properties: {'prop1', 'prop2'},
          aliasesSv: ['alias1'],
          aliasesEn: ['alias2'],
          searchTerms: ['search'],
          status: 'draft',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final map = original.toFirestore();
        // Convert Timestamps back to DateTime for fromMap
        final normalizedMap = Map<String, dynamic>.from(map);
        normalizedMap['createdAt'] = (map['createdAt'] as Timestamp).toDate();
        normalizedMap['updatedAt'] = (map['updatedAt'] as Timestamp).toDate();

        final restored = IngredientData.fromMap(normalizedMap);

        expect(restored.contentEquals(original), isTrue);
      });
    });

    group('group hierarchy helpers', () {
      late IngredientData ingredient;

      setUp(() {
        ingredient = IngredientData(
          id: 'test',
          swedish: 'test',
          english: 'test',
          group: 'protein/meat/poultry',
          properties: {},
        );
      });

      test('topLevelGroup returns first segment', () {
        expect(ingredient.topLevelGroup, 'protein');
      });

      test('midLevelGroup returns second segment', () {
        expect(ingredient.midLevelGroup, 'meat');
      });

      test('leafGroup returns third segment', () {
        expect(ingredient.leafGroup, 'poultry');
      });

      test('groupDepth returns correct depth', () {
        expect(ingredient.groupDepth, 3);

        final shallow = IngredientData(
          id: 'test',
          swedish: 'test',
          english: 'test',
          group: 'vegetables',
          properties: {},
        );
        expect(shallow.groupDepth, 1);
        expect(shallow.midLevelGroup, isNull);
        expect(shallow.leafGroup, isNull);
      });

      test('isInGroup checks group membership', () {
        expect(ingredient.isInGroup('protein'), isTrue);
        expect(ingredient.isInGroup('protein/meat'), isTrue);
        expect(ingredient.isInGroup('protein/meat/poultry'), isTrue);
        expect(ingredient.isInGroup('vegetables'), isFalse);
        expect(ingredient.isInGroup('protein/fish'), isFalse);
      });
    });

    group('property helpers', () {
      late IngredientData ingredient;

      setUp(() {
        ingredient = IngredientData(
          id: 'test',
          swedish: 'test',
          english: 'test',
          group: 'test',
          properties: {'meat', 'poultry', 'animal-product'},
        );
      });

      test('hasProperty checks single property', () {
        expect(ingredient.hasProperty('meat'), isTrue);
        expect(ingredient.hasProperty('vegan-friendly'), isFalse);
      });

      test('hasAnyProperty checks any match', () {
        expect(ingredient.hasAnyProperty(['meat', 'fish']), isTrue);
        expect(ingredient.hasAnyProperty(['fish', 'shellfish']), isFalse);
      });

      test('hasAllProperties checks all match', () {
        expect(ingredient.hasAllProperties(['meat', 'poultry']), isTrue);
        expect(ingredient.hasAllProperties(['meat', 'fish']), isFalse);
      });

      test('isAnimalProduct convenience getter', () {
        expect(ingredient.isAnimalProduct, isTrue);

        final plant = IngredientData(
          id: 'carrot',
          swedish: 'morot',
          english: 'carrot',
          group: 'vegetables',
          properties: {'plant-based'},
        );
        expect(plant.isAnimalProduct, isFalse);
      });

      test('isVeganFriendly convenience getter', () {
        expect(ingredient.isVeganFriendly, isFalse);

        final vegan = IngredientData(
          id: 'tofu',
          swedish: 'tofu',
          english: 'tofu',
          group: 'protein/plant',
          properties: {'vegan-friendly', 'plant-based'},
        );
        expect(vegan.isVeganFriendly, isTrue);
      });
    });

    group('name matching helpers', () {
      late IngredientData ingredient;

      setUp(() {
        ingredient = IngredientData(
          id: 'chicken-breast',
          swedish: 'kycklingbröst',
          english: 'chicken breast',
          group: 'protein/meat/poultry',
          properties: {},
          aliasesSv: ['kycklingfilé', 'kyckling'],
          aliasesEn: ['chicken fillet'],
          searchTerms: ['poultry'],
        );
      });

      test('allNames returns all name variants', () {
        final names = ingredient.allNames;

        expect(names, contains('kycklingbröst'));
        expect(names, contains('chicken breast'));
        expect(names, contains('kycklingfilé'));
        expect(names, contains('kyckling'));
        expect(names, contains('chicken fillet'));
        expect(names, contains('poultry'));
      });

      test('allNamesNormalized returns lowercase names', () {
        final names = ingredient.allNamesNormalized;

        expect(names.every((n) => n == n.toLowerCase()), isTrue);
      });

      test('matchesName finds exact case-insensitive match', () {
        expect(ingredient.matchesName('kycklingbröst'), isTrue);
        expect(ingredient.matchesName('KYCKLINGBRÖST'), isTrue);
        expect(ingredient.matchesName('chicken breast'), isTrue);
        expect(ingredient.matchesName('kyckling'), isTrue);
        expect(ingredient.matchesName('beef'), isFalse);
      });

      test('containsName finds partial match', () {
        expect(ingredient.containsName('kyckling'), isTrue);
        expect(ingredient.containsName('chicken'), isTrue);
        expect(ingredient.containsName('bröst'), isTrue);
        expect(ingredient.containsName('beef'), isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with specified field changes', () {
        final original = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: {'plant-based'},
          status: 'verified',
        );

        final copy = original.copyWith(
          swedish: 'röd tomat',
          properties: {'plant-based', 'vegan-friendly'},
        );

        expect(copy.id, 'tomato'); // Unchanged
        expect(copy.swedish, 'röd tomat'); // Changed
        expect(copy.english, 'tomato'); // Unchanged
        expect(copy.group, 'vegetables'); // Unchanged
        expect(copy.properties, {'plant-based', 'vegan-friendly'}); // Changed
        expect(copy.status, 'verified'); // Unchanged
      });

      test('copyWith preserves original when no changes', () {
        final original = IngredientData(
          id: 'test',
          swedish: 'test',
          english: 'test',
          group: 'test',
          properties: {'prop'},
          aliasesSv: ['alias'],
          status: 'draft',
        );

        final copy = original.copyWith();

        expect(copy.contentEquals(original), isTrue);
      });
    });

    group('toString', () {
      test('includes id and swedish name', () {
        final ingredient = IngredientData(
          id: 'chicken-breast',
          swedish: 'kycklingbröst',
          english: 'chicken breast',
          group: 'protein',
          properties: {},
        );

        final str = ingredient.toString();

        expect(str, contains('chicken-breast'));
        expect(str, contains('kycklingbröst'));
      });
    });
  });
}
