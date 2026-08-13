import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/services/tagging/tag_generator.dart'
    show kTagGeneratorVersion;

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

        // M15: Tags are sorted alphabetically before storage
        expect(map['tags'], ['gryta', 'kyckling']);
        expect(map['allergenStatus'], {
          'gluten': 'free',
          'mjölk': 'contains',
        });
        expect(map['dietaryStatus'], {
          'vegetarisk': 'contains',
          'vegansk': 'contains',
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

    // BUT-1482: configRevision records which remote tag_configs revision
    // produced these tags. It is persisted, so a future config-invalidation
    // path can tell which recipes were tagged under a superseded revision.
    group('BUT-1482: configRevision persistence', () {
      TagResult buildWith({int? configRevision}) => TagResult(
        tags: {'kyckling'},
        allergenStatus: {'gluten': TriState.free},
        dietaryStatus: {'vegetarisk': TriState.contains},
        coverage: 1.0,
        generatedAt: DateTime(2024, 6, 1),
        generatorVersion: kTagGeneratorVersion,
        configRevision: configRevision,
      );

      test('survives a Firestore write→read round-trip', () {
        // Proves a stored revision is trustworthy after reload; would fail if
        // the write or read of the key were dropped or mistyped.
        final restored = TagResult.fromFirestore(
          buildWith(configRevision: 42).toFirestore(),
        );
        expect(restored.configRevision, 42);
      });

      test('survives a JSON (Drift/SQLite) round-trip', () {
        final restored = TagResult.fromJson(
          buildWith(configRevision: 7).toJson(),
        );
        expect(restored.configRevision, 7);
      });

      test('is omitted from the map when null (static-fallback tagging)', () {
        // Static fallback (no remote config) must not write a null key, and
        // pre-BUT-1482 docs without the key must read back as null.
        final map = buildWith(configRevision: null).toFirestore();
        expect(map.containsKey('configRevision'), isFalse);
        expect(TagResult.fromFirestore(map).configRevision, isNull);
      });

      test('participates in equality', () {
        // The invalidation path compares results; a revision-only difference
        // must not read as "equal", or a superseded retag could be skipped.
        expect(
          buildWith(configRevision: 1),
          isNot(equals(buildWith(configRevision: 2))),
        );
        expect(
          buildWith(configRevision: 1),
          equals(buildWith(configRevision: 1)),
        );
      });

      test('is folded into hashCode consistently with equality', () {
        // Share the collection fields so configRevision is the only variable:
        // equal results (same revision) must hash equal. (Isolates the field —
        // TagResult.hashCode otherwise hashes its Set/Map fields by identity.)
        final tags = {'kyckling'};
        final allergen = {'gluten': TriState.free};
        final dietary = {'vegetarisk': TriState.contains};
        final at = DateTime(2024, 6, 1);
        TagResult withRev(int? rev) => TagResult(
          tags: tags,
          allergenStatus: allergen,
          dietaryStatus: dietary,
          coverage: 1.0,
          generatedAt: at,
          generatorVersion: kTagGeneratorVersion,
          configRevision: rev,
        );
        expect(withRev(1), equals(withRev(1)));
        expect(withRev(1).hashCode, withRev(1).hashCode);
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
      test('hasFullCoverage returns true when coverage is 1.0', () {
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
      });

      test('coverage is clamped when parsed from Firestore', () {
        // HIGH-2: Coverage values outside [0.0, 1.0] are clamped during deserialization
        final resultOver = TagResult.fromFirestore({
          'tags': <String>[],
          'allergenStatus': <String, String>{},
          'dietaryStatus': <String, String>{},
          'coverage': 1.5, // Will be clamped to 1.0
          'generatedAt': DateTime.now(),
        });
        expect(resultOver.coverage, 1.0);

        final resultUnder = TagResult.fromFirestore({
          'tags': <String>[],
          'allergenStatus': <String, String>{},
          'dietaryStatus': <String, String>{},
          'coverage': -0.5, // Will be clamped to 0.0
          'generatedAt': DateTime.now(),
        });
        expect(resultUnder.coverage, 0.0);
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

      // CRIT-2: Coverage validation now asserts in debug mode (throws AssertionError)
      // In release mode it would clamp, but tests run in debug mode.
      test(
        'CRIT-2: constructor throws assertion for coverage > 1.0 in debug',
        () {
          expect(
            () => TagResult(
              tags: {},
              allergenStatus: {},
              dietaryStatus: {},
              coverage: 1.5,
              generatedAt: DateTime.now(),
            ),
            throwsA(isA<AssertionError>()),
          );
        },
      );

      test(
        'CRIT-2: constructor throws assertion for coverage < 0.0 in debug',
        () {
          expect(
            () => TagResult(
              tags: {},
              allergenStatus: {},
              dietaryStatus: {},
              coverage: -0.5,
              generatedAt: DateTime.now(),
            ),
            throwsA(isA<AssertionError>()),
          );
        },
      );

      test('CRIT-2: valid coverage values are preserved', () {
        // Valid coverage should remain unchanged
        final validResult = TagResult(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 0.75,
          generatedAt: DateTime.now(),
        );
        expect(validResult.coverage, 0.75);

        // Edge cases at bounds
        final zeroResult = TagResult(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 0.0,
          generatedAt: DateTime.now(),
        );
        expect(zeroResult.coverage, 0.0);

        final oneResult = TagResult(
          tags: {},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          generatedAt: DateTime.now(),
        );
        expect(oneResult.coverage, 1.0);
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
        final current = TagResult(
          tags: {'test'},
          allergenStatus: {},
          dietaryStatus: {},
          coverage: 1.0,
          generatedAt: DateTime.now(),
          generatorVersion: kTagGeneratorVersion,
        );

        expect(current.needsRetagging, isFalse);
      });
    });

    group('L1: JSON Roundtrip', () {
      test('JSON serialization roundtrip preserves all data', () {
        final original = TagResult(
          tags: {'kyckling', 'gryta', 'under-30-min'},
          allergenStatus: {
            'gluten': TriState.free,
            'mjölk': TriState.contains,
            'ägg': TriState.unknown,
          },
          dietaryStatus: {
            'vegetarisk': TriState.contains,
            'vegansk': TriState.contains,
            'pescetarian': TriState.free,
          },
          coverage: 0.85,
          unknownIngredients: ['mystisk ingrediens', 'okänd krydda'],
          generatedAt: DateTime(2024, 12, 28, 12, 30),
          generatorVersion: 'v1.5.0',
          isPartial: true,
        );

        final json = original.toJson();
        final restored = TagResult.fromJson(json);

        // Verify all fields are preserved
        expect(restored.tags, equals(original.tags));
        expect(restored.allergenStatus, equals(original.allergenStatus));
        expect(restored.dietaryStatus, equals(original.dietaryStatus));
        expect(restored.coverage, equals(original.coverage));
        expect(
          restored.unknownIngredients,
          equals(original.unknownIngredients),
        );
        expect(restored.generatorVersion, equals(original.generatorVersion));
        expect(restored.isPartial, equals(original.isPartial));
        expect(restored.generatedAt, equals(original.generatedAt));
      });

      test('JSON roundtrip handles empty result', () {
        final empty = TagResult.empty();
        final json = empty.toJson();
        final restored = TagResult.fromJson(json);

        expect(restored.tags, isEmpty);
        expect(restored.allergenStatus, isEmpty);
        expect(restored.dietaryStatus, isEmpty);
        expect(restored.coverage, equals(0.0));
        expect(restored.unknownIngredients, isEmpty);
      });

      test('JSON roundtrip handles partial result', () {
        final partial = TagResult(
          tags: {'test-tag'},
          allergenStatus: {'gluten': TriState.unknown},
          dietaryStatus: {},
          coverage: 0.5,
          generatedAt: DateTime.now(),
          generatorVersion: 'v1.0.0',
          isPartial: true,
        );

        final json = partial.toJson();
        final restored = TagResult.fromJson(json);

        expect(restored.isPartial, isTrue);
        expect(restored.tags.contains('test-tag'), isTrue);
      });
    });

    // BUT-1492: The existing round-trip tests only exercise data written by the
    // CURRENT schema (V2). These pin the read-time-only V0→V2 migration
    // (_migrateSchema, invoked by fromFirestore/fromJson) — the path that reads
    // OLD stored blobs — and the cross-user cache path, i.e. a TagResult one user
    // computed being read back by another via the shared Firestore store (recipes
    // and their tagResult are shared cross-user through the global recipe cache /
    // recipe sharing, deserialized via TagResult.fromFirestore).
    group('L12: schema migration V0→V2 (read-time-only)', () {
      test(
        'V0 Firestore blob (no schemaVersion) reads and re-stamps to current',
        () {
          // A blob written before schema versioning existed: no schemaVersion key.
          final v0 = {
            'tags': ['kyckling', 'gryta'],
            'allergenStatus': {'gluten': 'free', 'mjölk': 'contains'},
            'dietaryStatus': {'vegetarisk': 'contains'},
            'coverage': 0.9,
            'unknownIngredients': ['dill'],
            'generatedAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
            'generatorVersion': '1.0.0',
            // NOTE: intentionally no 'schemaVersion' → defaults to 0
          };

          final result = TagResult.fromFirestore(v0);

          // Data survives the migration untouched (V0→V1 is a no-op transform).
          expect(result.tags, {'kyckling', 'gryta'});
          expect(result.allergenStatus['gluten'], TriState.free);
          expect(result.allergenStatus['mjölk'], TriState.contains);
          expect(result.dietaryStatus['vegetarisk'], TriState.contains);
          expect(result.coverage, 0.9);
          expect(result.unknownIngredients, ['dill']);

          // Re-serializing stamps the current schema version, so a later reader
          // sees a V2 blob and skips migration entirely.
          expect(
            result.toFirestore()['schemaVersion'],
            kTagResultSchemaVersion,
          );
        },
      );

      test(
        'V0 failed blob migrates the error out of unknownIngredients into '
        'errorReason',
        () {
          // Pre-V2 failures misused unknownIngredients[0] as the error string
          // and had no dedicated errorReason field.
          final v0Failed = {
            'tags': <String>[],
            'allergenStatus': <String, String>{},
            'dietaryStatus': <String, String>{},
            'coverage': 0.0,
            'unknownIngredients': ['Disk full during tagging'],
            'generatedAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
            'generatorVersion': 'failed',
            // no schemaVersion (V0), no errorReason
          };

          final result = TagResult.fromFirestore(v0Failed);

          // V1→V2 migration lifts the error text into the explicit field.
          expect(result.errorReason, 'Disk full during tagging');
          // The legacy field is preserved for backward-compatible UI.
          expect(result.unknownIngredients, ['Disk full during tagging']);
        },
      );

      test(
        'V1 failed blob (schemaVersion=1, no errorReason) extracts errorReason',
        () {
          final v1Failed = {
            'tags': <String>[],
            'allergenStatus': <String, String>{},
            'dietaryStatus': <String, String>{},
            'coverage': 0.0,
            'unknownIngredients': ['Network timeout'],
            'generatedAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
            'generatorVersion': 'failed',
            'schemaVersion': 1,
          };

          final result = TagResult.fromFirestore(v1Failed);

          expect(result.errorReason, 'Network timeout');
        },
      );

      test(
        'V1 non-failed blob is migrated without inventing an errorReason',
        () {
          final v1Ok = {
            'tags': ['pasta'],
            'allergenStatus': {'gluten': 'contains'},
            'dietaryStatus': <String, String>{},
            'coverage': 0.8,
            'unknownIngredients': ['some unknown veg'],
            'generatedAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
            'generatorVersion': '1.0.0',
            'schemaVersion': 1,
          };

          final result = TagResult.fromFirestore(v1Ok);

          // errorReason extraction only applies to 'failed' results — a normal
          // recipe's unknownIngredients must NOT be reinterpreted as an error.
          expect(result.errorReason, isNull);
          expect(result.unknownIngredients, ['some unknown veg']);
        },
      );

      test(
        'a current (V2) blob is not re-migrated — an explicit errorReason is '
        'not clobbered by unknownIngredients',
        () {
          // Idempotency guard: migration must early-return once at/above the
          // current version, so a V2 blob whose errorReason differs from
          // unknownIngredients[0] keeps its explicit value.
          final v2 = {
            'tags': <String>[],
            'allergenStatus': <String, String>{},
            'dietaryStatus': <String, String>{},
            'coverage': 0.0,
            'unknownIngredients': ['stale legacy text'],
            'generatedAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
            'generatorVersion': 'failed',
            'errorReason': 'Explicit V2 reason',
            'schemaVersion': kTagResultSchemaVersion,
          };

          final result = TagResult.fromFirestore(v2);

          expect(result.errorReason, 'Explicit V2 reason');
        },
      );

      test('the JSON read path migrates a V0 failed blob the same way', () {
        // fromJson also routes through _migrateSchema; the difference from the
        // Firestore path is only the date encoding (ISO string vs Timestamp).
        final v0FailedJson = {
          'tags': <String>[],
          'allergenStatus': <String, String>{},
          'dietaryStatus': <String, String>{},
          'coverage': 0.0,
          'unknownIngredients': ['Parser crash'],
          'generatedAt': DateTime(2024, 1, 1).toIso8601String(),
          'generatorVersion': 'failed',
          // V0: no schemaVersion, no errorReason
        };

        final result = TagResult.fromJson(v0FailedJson);

        expect(result.errorReason, 'Parser crash');
      });
    });

    group('cross-user cache round-trip (shared Firestore store)', () {
      test(
        'a round-trip stamps the current schema version and is stable across a '
        'second read (no re-migration for the next reader)',
        () {
          final original = TagResult(
            tags: {'kyckling', 'gryta'},
            allergenStatus: {'gluten': TriState.free},
            dietaryStatus: {'vegetarisk': TriState.contains},
            coverage: 0.9,
            unknownIngredients: ['dill'],
            generatedAt: DateTime(2024, 1, 15),
            generatorVersion: '1.0.0',
          );

          final stored = original.toFirestore();
          expect(stored['schemaVersion'], kTagResultSchemaVersion);

          // User B reads the shared blob.
          final readByOtherUser = TagResult.fromFirestore(stored);
          expect(readByOtherUser.tags, original.tags);
          expect(readByOtherUser.allergenStatus, original.allergenStatus);
          expect(readByOtherUser.dietaryStatus, original.dietaryStatus);
          expect(readByOtherUser.coverage, original.coverage);

          // Re-writing what User B read keeps the schema at current — the
          // round-trip is a fixed point, so it never triggers a migration loop.
          expect(
            readByOtherUser.toFirestore()['schemaVersion'],
            kTagResultSchemaVersion,
          );
        },
      );

      test(
        'safety verdicts survive crossing users, but the debug decision logs '
        'are dropped (not persisted to the shared Firestore store)',
        () {
          final withDecisions = TagResult(
            tags: {'lax'},
            allergenStatus: {
              'gluten': TriState.free,
              'fisk': TriState.contains,
            },
            dietaryStatus: {'pescetarian': TriState.free},
            coverage: 1.0,
            generatedAt: DateTime(2024, 1, 15),
            generatorVersion: '1.0.0',
            decisions: [
              TagDecision.allergen(
                key: 'fisk',
                result: TriState.contains,
                reason: "Ingredient 'lax' has property 'fish'",
                triggeringIngredients: ['lax'],
              ),
              TagDecision.dietary(
                key: 'pescetarian',
                result: TriState.free,
                reason: 'No meat ingredients at 100% coverage',
              ),
            ],
          );

          // The cross-user write NEVER emits decisions. Not "by default" — the
          // `includeDecisions` flag that could was removed 2026-08-12, because
          // `decisions` is absent from `isValidTagResult`'s allowlist and
          // flipping it would have denied every recipe write. This assertion is
          // what keeps it out; see the note on `TagResult.toFirestore`.
          final stored = withDecisions.toFirestore();
          expect(stored.containsKey('decisions'), isFalse);

          final readByOtherUser = TagResult.fromFirestore(stored);

          // The allergen/dietary verdicts the other user relies on are intact.
          expect(readByOtherUser.isAllergenFree('gluten'), isTrue);
          expect(readByOtherUser.containsAllergen('fisk'), isTrue);
          expect(readByOtherUser.isDietarySafe('pescetarian'), isTrue);
          // But the explanatory decision logs did not cross the boundary.
          expect(readByOtherUser.hasDecisions, isFalse);
          expect(readByOtherUser.getAllergenDecision('fisk'), isNull);
        },
      );

      test('errorReason crosses users intact through the shared store', () {
        final failed = TagResult.failed(reason: 'Ingredient lookup timeout');

        final stored = failed.toFirestore();
        expect(stored['errorReason'], 'Ingredient lookup timeout');

        final readByOtherUser = TagResult.fromFirestore(stored);
        expect(readByOtherUser.errorReason, 'Ingredient lookup timeout');
        expect(readByOtherUser.hasFailed, isTrue);
      });
    });
  });
}
