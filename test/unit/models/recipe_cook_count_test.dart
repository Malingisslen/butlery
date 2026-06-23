/// Tests for the nullable [cookCount] wire semantics on the Recipe model.
///
/// Proves three things:
/// 1. null (legacy) round-trips as null through JSON + Firestore forms.
/// 2. An explicit value round-trips unchanged.
/// 3. copyWith honours the sentinel pattern — `cookCount:` omitted keeps
///    the existing value; `cookCount: null` clears it; `cookCount: n` sets.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe_unified.dart';

Recipe _makeRecipe({int? cookCount}) => Recipe(
  core: RecipeCore(
    id: 'r1',
    title: 'Pasta Carbonara',
    description: 'Classic',
    ingredients: const ['pasta', 'eggs', 'bacon'],
    instructions: const ['Boil', 'Cook', 'Mix'],
    mealType: 'Middag',
    cookCount: cookCount,
  ),
  type: RecipeType.personal,
);

void main() {
  group('Recipe.cookCount serialization', () {
    test('null cookCount is omitted from toJson output (safe-map)', () {
      final json = _makeRecipe().toJson();
      final core = json['core'] as Map<String, dynamic>;
      expect(core.containsKey('cookCount'), isFalse);
    });

    test('null cookCount is omitted from toFirestore output', () {
      final doc = _makeRecipe().toFirestore();
      final core = doc['core'] as Map<String, dynamic>;
      expect(core.containsKey('cookCount'), isFalse);
    });

    test('explicit cookCount survives toJson -> fromJson', () {
      final before = _makeRecipe(cookCount: 7);
      final after = Recipe.fromJson(before.toJson());
      expect(after.core.cookCount, equals(7));
      expect(after.cookCountRaw, equals(7));
      expect(after.cookCount, equals(7));
    });

    test('absent cookCount (legacy doc) deserialises as null', () {
      final legacyJson = {
        'core': {
          'id': 'legacy-1',
          'title': 'Legacy pasta',
          'description': '',
          'ingredients': <String>[],
          'instructions': <String>[],
          'mealType': 'Middag',
          // No cookCount, no lastCookedAt — pre-counter recipe.
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'imageUrls': <String>[],
          'isPublic': false,
          'isFavorite': false,
        },
        'type': RecipeType.personal.index,
      };

      final recipe = Recipe.fromJson(legacyJson);
      expect(recipe.core.cookCount, isNull);
      expect(recipe.cookCountRaw, isNull);
      // Display-facing getter coerces null -> 0 so UI and sort code keeps
      // working without null-aware fallbacks on every call site.
      expect(recipe.cookCount, equals(0));
    });

    test(
      'explicit zero (post-backfill) survives round-trip and is NOT null',
      () {
        final before = _makeRecipe(cookCount: 0);
        final after = Recipe.fromJson(before.toJson());
        expect(after.cookCountRaw, equals(0));
        expect(
          after.cookCountRaw,
          isNotNull,
          reason:
              'zero is a real counted value, distinct from legacy null state',
        );
      },
    );

    test('Firestore round-trip preserves explicit cookCount', () {
      final before = _makeRecipe(cookCount: 12);
      final firestoreMap = before.toFirestore();
      // Simulate what FakeFirebaseFirestore passes back: flat map under 'core'.
      final after = Recipe.fromMap('r1', firestoreMap);
      expect(after.cookCountRaw, equals(12));
    });

    test('Firestore round-trip: null cookCount stays null', () {
      final before = _makeRecipe();
      final after = Recipe.fromMap('r1', before.toFirestore());
      expect(after.cookCountRaw, isNull);
    });

    test(
      'Firestore cookCount set via FieldValue.increment decodes correctly',
      () {
        // Simulates the post-increment document state: Firestore resolves
        // FieldValue.increment(1) server-side, so on re-read the field is an int.
        final firestoreLike = {
          'core': {
            'id': 'r1',
            'title': 'After increment',
            'description': '',
            'ingredients': <String>[],
            'instructions': <String>[],
            'mealType': 'Middag',
            'imageUrls': <String>[],
            'isPublic': false,
            'isFavorite': false,
            'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
            'updatedAt': Timestamp.fromDate(DateTime(2026, 4, 18)),
            'lastCookedAt': Timestamp.fromDate(DateTime(2026, 4, 18)),
            'cookCount': 1, // what FieldValue.increment(1) resolved to
          },
          'type': RecipeType.personal.index,
        };
        final recipe = Recipe.fromMap('r1', firestoreLike);
        expect(recipe.cookCountRaw, equals(1));
        expect(recipe.lastCookedAt, isNotNull);
      },
    );
  });

  group('Recipe.copyWith cookCount sentinel semantics', () {
    test('omitting cookCount keeps existing value', () {
      final original = _makeRecipe(cookCount: 5);
      final updated = original.copyWith(title: 'Renamed');
      expect(
        updated.cookCountRaw,
        equals(5),
        reason: 'copyWith without cookCount must preserve it',
      );
    });

    test('passing cookCount: null explicitly clears it', () {
      final original = _makeRecipe(cookCount: 5);
      final cleared = original.copyWith(cookCount: null);
      expect(
        cleared.cookCountRaw,
        isNull,
        reason: 'sentinel distinguishes "unset" from "set to null"',
      );
    });

    test('passing cookCount: n sets it', () {
      final original = _makeRecipe();
      final bumped = original.copyWith(cookCount: 3);
      expect(bumped.cookCountRaw, equals(3));
    });

    test('legacy null + markAsCooked optimistic bump lands at 1', () {
      final original = _makeRecipe(); // cookCount=null
      final cooked = original.markAsCooked();
      expect(
        cooked.cookCountRaw,
        equals(1),
        reason:
            'optimistic local update on legacy recipe must mirror the '
            'Firestore rule "null -> 1 on first increment" contract',
      );
    });

    test('markAsCooked on counted recipe bumps by exactly 1', () {
      final original = _makeRecipe(cookCount: 4);
      final cooked = original.markAsCooked();
      expect(cooked.cookCountRaw, equals(5));
    });
  });
}
