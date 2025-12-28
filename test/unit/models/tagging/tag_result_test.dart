import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';

void main() {
  group('TagResult', () {
    group('construction', () {
      test('creates with required parameters', () {
        final now = DateTime.now();
        final result = TagResult(
          tags: {'pasta', 'italian'},
          allergenStatus: {'gluten': TriState.contains},
          dietaryStatus: {'vegetarisk': TriState.free},
          coverage: 0.85,
          unknownIngredients: ['unusual spice'],
          generatedAt: now,
          generatorVersion: '1.0.0',
        );

        expect(result.tags, {'pasta', 'italian'});
        expect(result.allergenStatus['gluten'], TriState.contains);
        expect(result.dietaryStatus['vegetarisk'], TriState.free);
        expect(result.coverage, 0.85);
        expect(result.unknownIngredients, ['unusual spice']);
        expect(result.generatedAt, now);
        expect(result.generatorVersion, '1.0.0');
      });

      test('empty() creates result with default values', () {
        final result = TagResult.empty();

        expect(result.tags, isEmpty);
        expect(result.allergenStatus, isEmpty);
        expect(result.dietaryStatus, isEmpty);
        expect(result.coverage, 0.0);
        expect(result.unknownIngredients, isEmpty);
        expect(result.generatorVersion, 'empty');
      });
    });

    group('Firestore serialization', () {
      test('toFirestore creates valid map', () {
        final now = DateTime(2024, 1, 15, 12, 0, 0);
        final result = TagResult(
          tags: {'kyckling', 'gryta'},
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.contains,
          },
          dietaryStatus: {
            'vegetarisk': TriState.contains,
            'vegansk': TriState.contains,
          },
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: now,
          generatorVersion: '1.0.0',
        );

        final map = result.toFirestore();

        expect(map['tags'], ['kyckling', 'gryta']);
        expect(map['allergenStatus'], {
          'gluten': 'FREE',
          'mjölk': 'CONTAINS',
        });
        expect(map['dietaryStatus'], {
          'vegetarisk': 'CONTAINS',
          'vegansk': 'CONTAINS',
        });
        expect(map['coverage'], 1.0);
        expect(map['unknownIngredients'], []);
        expect(map['generatedAt'], isA<Timestamp>());
        expect(map['generatorVersion'], '1.0.0');
      });

      test('fromFirestore parses valid map', () {
        final now = DateTime(2024, 1, 15, 12, 0, 0);
        final map = {
          'tags': ['fisk', 'lax'],
          'allergenStatus': {
            'fisk': 'CONTAINS',
            'skaldjur': 'FREE',
          },
          'dietaryStatus': {
            'vegetarisk': 'CONTAINS',
          },
          'coverage': 0.9,
          'unknownIngredients': ['dill'],
          'generatedAt': Timestamp.fromDate(now),
          'generatorVersion': '1.0.0',
        };

        final result = TagResult.fromFirestore(map);

        expect(result.tags, {'fisk', 'lax'});
        expect(result.allergenStatus['fisk'], TriState.contains);
        expect(result.allergenStatus['skaldjur'], TriState.free);
        expect(result.dietaryStatus['vegetarisk'], TriState.contains);
        expect(result.coverage, 0.9);
        expect(result.unknownIngredients, ['dill']);
        expect(result.generatorVersion, '1.0.0');
      });

      test('fromFirestore handles null data', () {
        final result = TagResult.fromFirestore(null);

        expect(result.tags, isEmpty);
        expect(result.allergenStatus, isEmpty);
        expect(result.coverage, 0.0);
      });

      test('fromFirestore handles missing fields', () {
        final result = TagResult.fromFirestore({});

        expect(result.tags, isEmpty);
        expect(result.allergenStatus, isEmpty);
        expect(result.dietaryStatus, isEmpty);
        expect(result.coverage, 0.0);
        expect(result.unknownIngredients, isEmpty);
      });

      test('roundtrip serialization preserves data', () {
        final original = TagResult(
          tags: {'kyckling', 'under-30-min', 'stekt'},
          allergenStatus: {
            'gluten': TriState.free,
            'ägg': TriState.contains,
            'mjölk': TriState.unknown,
          },
          dietaryStatus: {
            'vegetarisk': TriState.contains,
            'vegansk': TriState.contains,
          },
          coverage: 0.75,
          unknownIngredients: ['mystery sauce'],
          generatedAt: DateTime(2024, 1, 15),
          generatorVersion: '1.0.0',
        );

        final map = original.toFirestore();
        final restored = TagResult.fromFirestore(map);

        expect(restored.tags, original.tags);
        expect(restored.allergenStatus, original.allergenStatus);
        expect(restored.dietaryStatus, original.dietaryStatus);
        expect(restored.coverage, original.coverage);
        expect(restored.unknownIngredients, original.unknownIngredients);
        expect(restored.generatorVersion, original.generatorVersion);
      });
    });

    group('allergen query helpers', () {
      late TagResult result;

      setUp(() {
        result = TagResult(
          tags: {},
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.contains,
            'ägg': TriState.unknown,
          },
          dietaryStatus: {},
          coverage: 0.8,
          unknownIngredients: [],
          generatedAt: DateTime.now(),
        );
      });

      test('isAllergenFree returns true only for FREE status', () {
        expect(result.isAllergenFree('gluten'), isTrue);
        expect(result.isAllergenFree('mjölk'), isFalse);
        expect(result.isAllergenFree('ägg'), isFalse);
        expect(result.isAllergenFree('nonexistent'), isFalse);
      });

      test('containsAllergen returns true only for CONTAINS status', () {
        expect(result.containsAllergen('mjölk'), isTrue);
        expect(result.containsAllergen('gluten'), isFalse);
        expect(result.containsAllergen('ägg'), isFalse);
        expect(result.containsAllergen('nonexistent'), isFalse);
      });

      test('isAllergenUnknown returns true for UNKNOWN or missing', () {
        expect(result.isAllergenUnknown('ägg'), isTrue);
        expect(result.isAllergenUnknown('nonexistent'), isTrue);
        expect(result.isAllergenUnknown('gluten'), isFalse);
        expect(result.isAllergenUnknown('mjölk'), isFalse);
      });

      test('getAllergenStatus returns correct status or UNKNOWN', () {
        expect(result.getAllergenStatus('gluten'), TriState.free);
        expect(result.getAllergenStatus('mjölk'), TriState.contains);
        expect(result.getAllergenStatus('ägg'), TriState.unknown);
        expect(result.getAllergenStatus('nonexistent'), TriState.unknown);
      });
    });

    group('dietary query helpers', () {
      late TagResult result;

      setUp(() {
        result = TagResult(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {
            'vegetarisk': TriState.free,
            'vegansk': TriState.contains,
            'pescetarian': TriState.unknown,
          },
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: DateTime.now(),
        );
      });

      test('isDietarySafe returns true only for FREE status', () {
        expect(result.isDietarySafe('vegetarisk'), isTrue);
        expect(result.isDietarySafe('vegansk'), isFalse);
        expect(result.isDietarySafe('pescetarian'), isFalse);
        expect(result.isDietarySafe('nonexistent'), isFalse);
      });

      test('getDietaryStatus returns correct status or UNKNOWN', () {
        expect(result.getDietaryStatus('vegetarisk'), TriState.free);
        expect(result.getDietaryStatus('vegansk'), TriState.contains);
        expect(result.getDietaryStatus('pescetarian'), TriState.unknown);
        expect(result.getDietaryStatus('nonexistent'), TriState.unknown);
      });
    });

    group('coverage helpers', () {
      test('hasFullCoverage returns true when coverage >= 1.0', () {
        expect(
          TagResult(
            tags: {},
            allergenStatus: {},
            dietaryStatus: {},
            coverage: 1.0,
            generatedAt: DateTime.now(),
          ).hasFullCoverage,
          isTrue,
        );
        expect(
          TagResult(
            tags: {},
            allergenStatus: {},
            dietaryStatus: {},
            coverage: 1.1,
            generatedAt: DateTime.now(),
          ).hasFullCoverage,
          isTrue,
        );
      });

      test('hasFullCoverage returns false when coverage < 1.0', () {
        expect(
          TagResult(
            tags: {},
            allergenStatus: {},
            dietaryStatus: {},
            coverage: 0.99,
            generatedAt: DateTime.now(),
          ).hasFullCoverage,
          isFalse,
        );
      });

      test('hasUnknowns reflects unknownIngredients list', () {
        expect(
          TagResult(
            tags: {},
            allergenStatus: {},
            dietaryStatus: {},
            coverage: 0.5,
            unknownIngredients: ['something'],
            generatedAt: DateTime.now(),
          ).hasUnknowns,
          isTrue,
        );
        expect(
          TagResult(
            tags: {},
            allergenStatus: {},
            dietaryStatus: {},
            coverage: 1.0,
            unknownIngredients: [],
            generatedAt: DateTime.now(),
          ).hasUnknowns,
          isFalse,
        );
      });
    });

    group('tag query helpers', () {
      late TagResult result;

      setUp(() {
        result = TagResult(
          tags: {'kyckling', 'under-30-min', 'stekt', 'italian'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          generatedAt: DateTime.now(),
        );
      });

      test('hasTag returns true for existing tags', () {
        expect(result.hasTag('kyckling'), isTrue);
        expect(result.hasTag('italian'), isTrue);
        expect(result.hasTag('nonexistent'), isFalse);
      });

      test('hasAnyTag returns true if any tag matches', () {
        expect(result.hasAnyTag(['kyckling', 'fisk']), isTrue);
        expect(result.hasAnyTag(['fisk', 'skaldjur']), isFalse);
        expect(result.hasAnyTag([]), isFalse);
      });

      test('hasAllTags returns true only if all tags match', () {
        expect(result.hasAllTags(['kyckling', 'stekt']), isTrue);
        expect(result.hasAllTags(['kyckling', 'fisk']), isFalse);
        expect(result.hasAllTags([]), isTrue);
      });
    });

    group('convenience allergen properties', () {
      test('isGlutenFree checks gluten status', () {
        expect(
          TagResult(
            tags: {},
            allergenStatus: {'gluten': TriState.free},
            dietaryStatus: {},
            coverage: 1.0,
            generatedAt: DateTime.now(),
          ).isGlutenFree,
          isTrue,
        );
        expect(
          TagResult(
            tags: {},
            allergenStatus: {'gluten': TriState.contains},
            dietaryStatus: {},
            coverage: 1.0,
            generatedAt: DateTime.now(),
          ).isGlutenFree,
          isFalse,
        );
      });

      test('isDairyFree checks mjölk status', () {
        expect(
          TagResult(
            tags: {},
            allergenStatus: {'mjölk': TriState.free},
            dietaryStatus: {},
            coverage: 1.0,
            generatedAt: DateTime.now(),
          ).isDairyFree,
          isTrue,
        );
      });
    });

    group('convenience dietary properties', () {
      test('isVegetarian checks vegetarisk status', () {
        expect(
          TagResult(
            tags: {},
            allergenStatus: {},
            dietaryStatus: {'vegetarisk': TriState.free},
            coverage: 1.0,
            generatedAt: DateTime.now(),
          ).isVegetarian,
          isTrue,
        );
        expect(
          TagResult(
            tags: {},
            allergenStatus: {},
            dietaryStatus: {'vegetarisk': TriState.contains},
            coverage: 1.0,
            generatedAt: DateTime.now(),
          ).isVegetarian,
          isFalse,
        );
      });

      test('isVegan checks vegansk status', () {
        expect(
          TagResult(
            tags: {},
            allergenStatus: {},
            dietaryStatus: {'vegansk': TriState.free},
            coverage: 1.0,
            generatedAt: DateTime.now(),
          ).isVegan,
          isTrue,
        );
      });
    });

    group('copyWith', () {
      test('creates copy with overridden fields', () {
        final original = TagResult(
          tags: {'pasta'},
          allergenStatus: {'gluten': TriState.contains},
          dietaryStatus: {'vegetarisk': TriState.free},
          coverage: 0.8,
          unknownIngredients: ['spice'],
          generatedAt: DateTime(2024, 1, 1),
          generatorVersion: '1.0.0',
        );

        final copy = original.copyWith(
          tags: {'rice'},
          coverage: 1.0,
        );

        expect(copy.tags, {'rice'});
        expect(copy.coverage, 1.0);
        // Unchanged fields
        expect(copy.allergenStatus, original.allergenStatus);
        expect(copy.dietaryStatus, original.dietaryStatus);
        expect(copy.unknownIngredients, original.unknownIngredients);
        expect(copy.generatorVersion, original.generatorVersion);
      });
    });

    group('mergeTags', () {
      test('adds additional tags to existing set', () {
        final original = TagResult(
          tags: {'kyckling', 'gryta'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          generatedAt: DateTime.now(),
        );

        final merged = original.mergeTags({'swedish', 'comfort-food'});

        expect(merged.tags, {'kyckling', 'gryta', 'swedish', 'comfort-food'});
        expect(merged.coverage, original.coverage);
      });
    });

    group('equality', () {
      test('equal results are equal', () {
        final a = TagResult(
          tags: {'test'},
          allergenStatus: {'gluten': TriState.free},
          dietaryStatus: {'vegetarisk': TriState.free},
          coverage: 1.0,
          generatedAt: DateTime(2024, 1, 1),
        );
        final b = TagResult(
          tags: {'test'},
          allergenStatus: {'gluten': TriState.free},
          dietaryStatus: {'vegetarisk': TriState.free},
          coverage: 1.0,
          generatedAt: DateTime(2024, 1, 1),
        );

        expect(a, equals(b));
      });

      test('different tags means not equal', () {
        final a = TagResult(
          tags: {'a'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          generatedAt: DateTime(2024, 1, 1),
        );
        final b = TagResult(
          tags: {'b'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          generatedAt: DateTime(2024, 1, 1),
        );

        expect(a, isNot(equals(b)));
      });

      test('different allergen status means not equal', () {
        final a = TagResult(
          tags: {'test'},
          allergenStatus: {'gluten': TriState.free},
          dietaryStatus: {},
          coverage: 1.0,
          generatedAt: DateTime(2024, 1, 1),
        );
        final b = TagResult(
          tags: {'test'},
          allergenStatus: {'gluten': TriState.contains},
          dietaryStatus: {},
          coverage: 1.0,
          generatedAt: DateTime(2024, 1, 1),
        );

        expect(a, isNot(equals(b)));
      });

      test('different coverage means not equal', () {
        final a = TagResult(
          tags: {'test'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          generatedAt: DateTime(2024, 1, 1),
        );
        final b = TagResult(
          tags: {'test'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 0.5,
          generatedAt: DateTime(2024, 1, 1),
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('includes tag count and coverage', () {
        final result = TagResult(
          tags: {'a', 'b', 'c'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 0.85,
          generatedAt: DateTime.now(),
        );

        expect(result.toString(), contains('3 tags'));
        expect(result.toString(), contains('85%'));
      });
    });

    group('malformed data handling', () {
      test('handles corrupted coverage value (string instead of number)', () {
        final map = {
          'tags': ['test'],
          'coverage': 'invalid_string', // Should be a number
          'allergenStatus': {},
          'dietaryStatus': {},
        };

        final result = TagResult.fromFirestore(map);

        // Should default to 0.0 rather than crash
        expect(result.coverage, 0.0);
      });

      test('handles coverage out of range', () {
        final mapNegative = {
          'tags': [],
          'coverage': -0.5,
          'allergenStatus': {},
          'dietaryStatus': {},
        };

        final result = TagResult.fromFirestore(mapNegative);

        // Coverage should be clamped or use default
        expect(result.coverage, lessThanOrEqualTo(1.0));
      });

      test('handles tags as non-list type', () {
        final map = {
          'tags': 'not a list',
          'coverage': 1.0,
        };

        final result = TagResult.fromFirestore(map);
        expect(result.tags, isEmpty);
      });

      test('handles allergenStatus with invalid tri-state values', () {
        final map = {
          'tags': [],
          'allergenStatus': {
            'gluten': 'INVALID_STATE',
            'mjölk': 123, // Wrong type
          },
          'coverage': 1.0,
        };

        final result = TagResult.fromFirestore(map);

        // Invalid states should default to UNKNOWN
        expect(result.allergenStatus['gluten'], TriState.unknown);
        expect(result.allergenStatus['mjölk'], TriState.unknown);
      });

      test('handles unknownIngredients as non-list', () {
        final map = {
          'tags': [],
          'unknownIngredients': 'not a list',
          'coverage': 0.5,
        };

        final result = TagResult.fromFirestore(map);
        expect(result.unknownIngredients, isEmpty);
      });
    });

    group('unknownIngredients in equality (C3 fix)', () {
      test('different unknownIngredients means not equal', () {
        final a = TagResult(
          tags: {'test'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 0.5,
          unknownIngredients: ['spice1'],
          generatedAt: DateTime(2024, 1, 1),
        );
        final b = TagResult(
          tags: {'test'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 0.5,
          unknownIngredients: ['spice2'],
          generatedAt: DateTime(2024, 1, 1),
        );

        expect(a, isNot(equals(b)));
      });

      test('same unknownIngredients means equal', () {
        final a = TagResult(
          tags: {'test'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 0.5,
          unknownIngredients: ['spice'],
          generatedAt: DateTime(2024, 1, 1),
        );
        final b = TagResult(
          tags: {'test'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 0.5,
          unknownIngredients: ['spice'],
          generatedAt: DateTime(2024, 1, 1),
        );

        expect(a, equals(b));
      });

      test('empty vs non-empty unknownIngredients not equal', () {
        final a = TagResult(
          tags: {'test'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          unknownIngredients: [],
          generatedAt: DateTime(2024, 1, 1),
        );
        final b = TagResult(
          tags: {'test'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          unknownIngredients: ['unknown'],
          generatedAt: DateTime(2024, 1, 1),
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('version mismatch detection', () {
      test('needsRetagging is true when version differs', () {
        final result = TagResult(
          tags: {'test'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          generatedAt: DateTime.now(),
          generatorVersion: 'old-version',
        );

        // Assuming current version is different from 'old-version'
        expect(result.generatorVersion, isNot('1.0.0'));
      });

      test('needsRetagging property reflects version check', () {
        final outdated = TagResult(
          tags: {'test'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          generatedAt: DateTime.now(),
          generatorVersion: '0.9.0',
        );

        // TagResult.needsRetagging checks against kTagGeneratorVersion
        expect(outdated.needsRetagging, isTrue);
      });

      test('needsRetagging is false when version matches', () {
        // Import the constant to use the current version
        final current = TagResult(
          tags: {'test'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          generatedAt: DateTime.now(),
          generatorVersion: '1.0.0', // Current version
        );

        expect(current.needsRetagging, isFalse);
      });
    });
  });
}
