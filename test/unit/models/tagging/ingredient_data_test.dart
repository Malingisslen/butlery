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
          properties: const {'meat', 'poultry', 'animal-product'},
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
        expect(ingredient.isCompoundName, isFalse);
      });

      test('creates with all optional parameters', () {
        final now = DateTime.now();
        final ingredient = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables/fruits',
          properties: const {'plant-based', 'vegan-friendly'},
          aliasesSv: const ['tomater', 'krossade tomater'],
          aliasesEn: const ['tomatoes'],
          searchTerms: const ['röd', 'frukt'],
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
          properties: const {'plant-based'},
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat (röda)', // Different swedish name
          english: 'red tomato', // Different english name
          group: 'vegetables/fruits', // Different group
          properties: const {
            'plant-based',
            'vegan-friendly'
          }, // Different properties
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
          properties: const {'plant-based'},
        );
        final b = IngredientData(
          id: 'sun-dried-tomato', // Different ID
          swedish: 'tomat', // Same swedish name
          english: 'tomato', // Same english name
          group: 'vegetables', // Same group
          properties: const {'plant-based'}, // Same properties
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
          properties: const {},
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
          properties: const {'plant-based'},
        );
        final b = IngredientData(
          id: 'tomato', // Same ID = same ingredient
          swedish: 'röd tomat',
          english: 'red tomato',
          group: 'vegetables/fruits',
          properties: const {'plant-based', 'colored'},
        );
        final c = IngredientData(
          id: 'onion', // Different ID
          swedish: 'lök',
          english: 'onion',
          group: 'vegetables',
          properties: const {'plant-based'},
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
          properties: const {},
        );
        final b = IngredientData(
          id: 'tomato', // Same ID
          swedish: 'annat namn',
          english: 'different name',
          group: 'other',
          properties: const {'different'},
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
          properties: const {'plant-based', 'vegan-friendly'},
          aliasesSv: const ['tomater'],
          aliasesEn: const ['tomatoes'],
          searchTerms: const ['red'],
          status: 'verified',
          createdAt: now,
          updatedAt: now,
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {'plant-based', 'vegan-friendly'},
          aliasesSv: const ['tomater'],
          aliasesEn: const ['tomatoes'],
          searchTerms: const ['red'],
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
          properties: const {},
        );
        final b = IngredientData(
          id: 'tomato-red',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when swedish differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'röd tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when english differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'red tomato',
          group: 'vegetables',
          properties: const {},
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when group differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables/fruits',
          properties: const {},
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when properties differ', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {'plant-based'},
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {'plant-based', 'vegan-friendly'},
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when aliasesSv differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
          aliasesSv: const ['tomater'],
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
          aliasesSv: const ['krossade tomater'],
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when aliasesEn differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
          aliasesEn: const ['tomatoes'],
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
          aliasesEn: const ['red tomatoes'],
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when searchTerms differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
          searchTerms: const ['red'],
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
          searchTerms: const ['red', 'fruit'],
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('returns false when status differs', () {
        final a = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
          status: 'verified',
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
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
          properties: const {},
          createdAt: DateTime(2024, 1, 1),
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
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
          properties: const {},
          updatedAt: DateTime(2024, 1, 1),
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
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
          properties: const {},
          createdAt: null,
          updatedAt: null,
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
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
          properties: const {'a', 'b', 'c'},
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {
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
          properties: const {},
          aliasesSv: const ['a', 'b'],
        );
        final b = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {},
          aliasesSv: const ['b', 'a'], // Same elements, different order
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
          properties: const {'meat', 'poultry'},
          aliasesSv: const ['kycklingfilé'],
          aliasesEn: const ['chicken fillet'],
          searchTerms: const ['kyckling'],
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
          properties: const {'prop1', 'prop2'},
          aliasesSv: const ['alias1'],
          aliasesEn: const ['alias2'],
          searchTerms: const ['search'],
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
          properties: const {},
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
          properties: const {},
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
          properties: const {'meat', 'poultry', 'animal-product'},
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
          properties: const {'plant-based'},
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
          properties: const {'vegan-friendly', 'plant-based'},
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
          properties: const {},
          aliasesSv: const ['kycklingfilé', 'kyckling'],
          aliasesEn: const ['chicken fillet'],
          searchTerms: const ['poultry'],
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
          properties: const {'plant-based'},
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
          properties: const {'prop'},
          aliasesSv: const ['alias'],
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
          properties: const {},
        );

        final str = ingredient.toString();

        expect(str, contains('chicken-breast'));
        expect(str, contains('kycklingbröst'));
      });
    });

    group('Sprint 1: sustainability and metadata fields', () {
      test('creates with all new optional parameters', () {
        final ingredient = IngredientData(
          id: 'tomato',
          swedish: 'tomat',
          english: 'tomato',
          group: 'vegetables',
          properties: const {'plant-based'},
          seasonAvailability: const ['sommar', 'höst'],
          priceCategory: 'budget',
          carbonFootprintCategory: 'low',
          notesSv: 'Bra för sallader',
          notesEn: 'Good for salads',
          typicalStorage: 'ambient',
          typicalUnit: 'st',
          avgPriceSek: 15.50,
        );

        expect(ingredient.seasonAvailability, ['sommar', 'höst']);
        expect(ingredient.priceCategory, 'budget');
        expect(ingredient.carbonFootprintCategory, 'low');
        expect(ingredient.notesSv, 'Bra för sallader');
        expect(ingredient.notesEn, 'Good for salads');
        expect(ingredient.typicalStorage, 'ambient');
        expect(ingredient.typicalUnit, 'st');
        expect(ingredient.avgPriceSek, 15.50);
      });

      test('new fields default to null/empty', () {
        final ingredient = IngredientData(
          id: 'test',
          swedish: 'test',
          english: 'test',
          group: 'test',
          properties: const {},
        );

        expect(ingredient.seasonAvailability, isEmpty);
        expect(ingredient.priceCategory, isNull);
        expect(ingredient.carbonFootprintCategory, isNull);
        expect(ingredient.notesSv, isNull);
        expect(ingredient.notesEn, isNull);
        expect(ingredient.typicalStorage, isNull);
        expect(ingredient.typicalUnit, isNull);
        expect(ingredient.avgPriceSek, isNull);
        expect(ingredient.isCompoundName, isFalse);
      });

      group('contentEquals with new fields', () {
        test('returns false when seasonAvailability differs', () {
          final a = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            seasonAvailability: const ['sommar'],
          );
          final b = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            seasonAvailability: const ['sommar', 'höst'],
          );

          expect(a.contentEquals(b), isFalse);
        });

        test('returns false when priceCategory differs', () {
          final a = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            priceCategory: 'budget',
          );
          final b = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            priceCategory: 'premium',
          );

          expect(a.contentEquals(b), isFalse);
        });

        test('returns false when carbonFootprintCategory differs', () {
          final a = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            carbonFootprintCategory: 'low',
          );
          final b = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            carbonFootprintCategory: 'high',
          );

          expect(a.contentEquals(b), isFalse);
        });

        test('returns false when avgPriceSek differs', () {
          final a = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            avgPriceSek: 10.0,
          );
          final b = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            avgPriceSek: 20.0,
          );

          expect(a.contentEquals(b), isFalse);
        });

        test('returns true when all new fields are equal', () {
          final a = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            seasonAvailability: const ['sommar', 'höst'],
            priceCategory: 'budget',
            carbonFootprintCategory: 'low',
            notesSv: 'Notes',
            notesEn: 'Notes',
            typicalStorage: 'ambient',
            typicalUnit: 'st',
            avgPriceSek: 15.0,
          );
          final b = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            seasonAvailability: const ['sommar', 'höst'],
            priceCategory: 'budget',
            carbonFootprintCategory: 'low',
            notesSv: 'Notes',
            notesEn: 'Notes',
            typicalStorage: 'ambient',
            typicalUnit: 'st',
            avgPriceSek: 15.0,
          );

          expect(a.contentEquals(b), isTrue);
        });
      });

      group('Firestore serialization with new fields', () {
        test('toFirestore includes new fields when set', () {
          final ingredient = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            seasonAvailability: const ['sommar', 'höst'],
            priceCategory: 'budget',
            carbonFootprintCategory: 'low',
            notesSv: 'Notes SV',
            notesEn: 'Notes EN',
            typicalStorage: 'ambient',
            typicalUnit: 'st',
            avgPriceSek: 15.50,
          );

          final map = ingredient.toFirestore();

          expect(map['seasonAvailability'], ['sommar', 'höst']);
          expect(map['priceCategory'], 'budget');
          expect(map['carbonFootprintCategory'], 'low');
          expect(map['notesSv'], 'Notes SV');
          expect(map['notesEn'], 'Notes EN');
          expect(map['typicalStorage'], 'ambient');
          expect(map['typicalUnit'], 'st');
          expect(map['avgPriceSek'], 15.50);
        });

        test('toFirestore excludes null/empty new fields', () {
          final ingredient = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
          );

          final map = ingredient.toFirestore();

          expect(map.containsKey('seasonAvailability'), isFalse);
          expect(map.containsKey('priceCategory'), isFalse);
          expect(map.containsKey('carbonFootprintCategory'), isFalse);
          expect(map.containsKey('notesSv'), isFalse);
          expect(map.containsKey('notesEn'), isFalse);
          expect(map.containsKey('typicalStorage'), isFalse);
          expect(map.containsKey('typicalUnit'), isFalse);
          expect(map.containsKey('avgPriceSek'), isFalse);
        });

        test('fromMap parses new fields', () {
          final map = {
            'id': 'tomato',
            'swedish': 'tomat',
            'english': 'tomato',
            'group': 'vegetables',
            'properties': <String>[],
            'seasonAvailability': ['sommar', 'höst'],
            'priceCategory': 'budget',
            'carbonFootprintCategory': 'low',
            'notesSv': 'Notes SV',
            'notesEn': 'Notes EN',
            'typicalStorage': 'ambient',
            'typicalUnit': 'st',
            'avgPriceSek': 15.50,
          };

          final ingredient = IngredientData.fromMap(map);

          expect(ingredient.seasonAvailability, ['sommar', 'höst']);
          expect(ingredient.priceCategory, 'budget');
          expect(ingredient.carbonFootprintCategory, 'low');
          expect(ingredient.notesSv, 'Notes SV');
          expect(ingredient.notesEn, 'Notes EN');
          expect(ingredient.typicalStorage, 'ambient');
          expect(ingredient.typicalUnit, 'st');
          expect(ingredient.avgPriceSek, 15.50);
        });

        test('fromMap handles missing new fields gracefully', () {
          final map = {
            'id': 'tomato',
            'swedish': 'tomat',
            'english': 'tomato',
            'group': 'vegetables',
            'properties': <String>[],
          };

          final ingredient = IngredientData.fromMap(map);

          expect(ingredient.seasonAvailability, isEmpty);
          expect(ingredient.priceCategory, isNull);
          expect(ingredient.carbonFootprintCategory, isNull);
          expect(ingredient.notesSv, isNull);
          expect(ingredient.notesEn, isNull);
          expect(ingredient.typicalStorage, isNull);
          expect(ingredient.typicalUnit, isNull);
          expect(ingredient.avgPriceSek, isNull);
        });

        test('roundtrip preserves new fields', () {
          final original = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            seasonAvailability: const ['vår', 'sommar'],
            priceCategory: 'medium',
            carbonFootprintCategory: 'medium',
            notesSv: 'Test notes SV',
            notesEn: 'Test notes EN',
            typicalStorage: 'refrigerated',
            typicalUnit: 'g',
            avgPriceSek: 25.99,
          );

          final map = original.toFirestore();
          // Remove Timestamp fields for fromMap
          map.remove('createdAt');
          map.remove('updatedAt');

          final restored = IngredientData.fromMap(map);

          expect(restored.seasonAvailability, original.seasonAvailability);
          expect(restored.priceCategory, original.priceCategory);
          expect(restored.carbonFootprintCategory,
              original.carbonFootprintCategory);
          expect(restored.notesSv, original.notesSv);
          expect(restored.notesEn, original.notesEn);
          expect(restored.typicalStorage, original.typicalStorage);
          expect(restored.typicalUnit, original.typicalUnit);
          expect(restored.avgPriceSek, original.avgPriceSek);
        });
      });

      group('copyWith with new fields', () {
        test('copies new fields correctly', () {
          final original = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            seasonAvailability: const ['sommar'],
            priceCategory: 'budget',
          );

          final copy = original.copyWith(
            seasonAvailability: ['sommar', 'höst'],
            carbonFootprintCategory: 'low',
          );

          expect(copy.seasonAvailability, ['sommar', 'höst']);
          expect(copy.priceCategory, 'budget'); // Unchanged
          expect(copy.carbonFootprintCategory, 'low'); // New
        });

        test('preserves new fields when not specified', () {
          final original = IngredientData(
            id: 'tomato',
            swedish: 'tomat',
            english: 'tomato',
            group: 'vegetables',
            properties: const {},
            seasonAvailability: const ['vår'],
            priceCategory: 'premium',
            carbonFootprintCategory: 'high',
            avgPriceSek: 99.99,
          );

          final copy = original.copyWith(swedish: 'röd tomat');

          expect(copy.seasonAvailability, ['vår']);
          expect(copy.priceCategory, 'premium');
          expect(copy.carbonFootprintCategory, 'high');
          expect(copy.avgPriceSek, 99.99);
        });
      });
    });

    group('isCompoundName field', () {
      test('defaults to false', () {
        final ingredient = IngredientData(
          id: 'salt',
          swedish: 'salt',
          english: 'salt',
          group: 'spice',
          properties: const {},
        );

        expect(ingredient.isCompoundName, isFalse);
      });

      test('can be set to true', () {
        final ingredient = IngredientData(
          id: 'white-pepper',
          swedish: 'vitpeppar',
          english: 'white pepper',
          group: 'spice',
          properties: const {'is-spicy'},
          isCompoundName: true,
        );

        expect(ingredient.isCompoundName, isTrue);
      });

      test('fromMap parses isCompoundName true', () {
        final map = {
          'id': 'white-pepper',
          'swedish': 'vitpeppar',
          'english': 'white pepper',
          'group': 'spice',
          'properties': <String>[],
          'isCompoundName': true,
        };

        final ingredient = IngredientData.fromMap(map);
        expect(ingredient.isCompoundName, isTrue);
      });

      test('fromMap handles missing isCompoundName gracefully', () {
        final map = {
          'id': 'salt',
          'swedish': 'salt',
          'english': 'salt',
          'group': 'spice',
          'properties': <String>[],
        };

        final ingredient = IngredientData.fromMap(map);
        expect(ingredient.isCompoundName, isFalse);
      });

      test('fromMap handles null isCompoundName gracefully', () {
        final map = {
          'id': 'salt',
          'swedish': 'salt',
          'english': 'salt',
          'group': 'spice',
          'properties': <String>[],
          'isCompoundName': null,
        };

        final ingredient = IngredientData.fromMap(map);
        expect(ingredient.isCompoundName, isFalse);
      });

      test('toFirestore includes isCompoundName', () {
        final ingredient = IngredientData(
          id: 'white-pepper',
          swedish: 'vitpeppar',
          english: 'white pepper',
          group: 'spice',
          properties: const {},
          isCompoundName: true,
        );

        final map = ingredient.toFirestore();
        expect(map['isCompoundName'], isTrue);
      });

      test('toFirestore includes isCompoundName even when false', () {
        final ingredient = IngredientData(
          id: 'salt',
          swedish: 'salt',
          english: 'salt',
          group: 'spice',
          properties: const {},
        );

        final map = ingredient.toFirestore();
        expect(map['isCompoundName'], isFalse);
      });

      test('contentEquals detects isCompoundName difference', () {
        final a = IngredientData(
          id: 'white-pepper',
          swedish: 'vitpeppar',
          english: 'white pepper',
          group: 'spice',
          properties: const {},
          isCompoundName: true,
        );
        final b = IngredientData(
          id: 'white-pepper',
          swedish: 'vitpeppar',
          english: 'white pepper',
          group: 'spice',
          properties: const {},
          isCompoundName: false,
        );

        expect(a.contentEquals(b), isFalse);
      });

      test('copyWith can change isCompoundName', () {
        final original = IngredientData(
          id: 'test',
          swedish: 'test',
          english: 'test',
          group: 'test',
          properties: const {},
          isCompoundName: false,
        );

        final copy = original.copyWith(isCompoundName: true);
        expect(copy.isCompoundName, isTrue);
      });

      test('copyWith preserves isCompoundName when not specified', () {
        final original = IngredientData(
          id: 'test',
          swedish: 'test',
          english: 'test',
          group: 'test',
          properties: const {},
          isCompoundName: true,
        );

        final copy = original.copyWith(swedish: 'changed');
        expect(copy.isCompoundName, isTrue);
      });

      test('roundtrip preserves isCompoundName', () {
        final original = IngredientData(
          id: 'white-pepper',
          swedish: 'vitpeppar',
          english: 'white pepper',
          group: 'spice',
          properties: const {},
          isCompoundName: true,
        );

        final map = original.toFirestore();
        final restored = IngredientData.fromMap(map);

        expect(restored.isCompoundName, isTrue);
      });
    });
  });
}
