/// BUT-1048: pins the symmetric link/unlink contract on
/// `RecipeRelationsService`. The service takes two narrow callbacks
/// (getRecipe + updateRecipe) so tests stub them with plain functions —
/// no `Mock implements Interface` noSuchMethod trap that blocked the
/// BUT-989 attempt.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/recipe_relations_service.dart';

Recipe _recipe({
  required String id,
  List<String>? related,
}) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: 'r-$id',
      description: '',
      ingredients: const [],
      instructions: const [],
      mealType: 'middag',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      relatedRecipeIds: related,
    ),
    type: RecipeType.personal,
  );
}

void main() {
  group('RecipeRelationsService (BUT-1048)', () {
    late Map<String, Recipe> store;
    late List<Recipe> writes;
    late RecipeRelationsService relations;

    setUp(() {
      store = {};
      writes = [];
      relations = RecipeRelationsService(
        getRecipe: (id) => store[id],
        updateRecipe: (recipe) async {
          writes.add(recipe);
          store[recipe.id] = recipe;
          return true;
        },
      );
    });

    test('link adds bId to A and aId to B (symmetric)', () async {
      store['a'] = _recipe(id: 'a');
      store['b'] = _recipe(id: 'b');

      final ok = await relations.link('a', 'b');

      expect(ok, isTrue);
      expect(writes, hasLength(2));
      expect(store['a']!.core.relatedRecipeIds, equals(['b']));
      expect(store['b']!.core.relatedRecipeIds, equals(['a']));
    });

    test('link is idempotent when already symmetric — no writes', () async {
      store['a'] = _recipe(id: 'a', related: ['b']);
      store['b'] = _recipe(id: 'b', related: ['a']);

      final ok = await relations.link('a', 'b');

      expect(ok, isTrue);
      expect(writes, isEmpty, reason: 'already-symmetric is a no-op');
    });

    test('link normalises asymmetric prior state (one-sided → both)', () async {
      // A points at B; B doesn't point back. link should write only the
      // missing side (B's update).
      store['a'] = _recipe(id: 'a', related: ['b']);
      store['b'] = _recipe(id: 'b');

      final ok = await relations.link('a', 'b');

      expect(ok, isTrue);
      expect(writes, hasLength(1));
      expect(writes.first.id, equals('b'));
      expect(store['b']!.core.relatedRecipeIds, equals(['a']));
    });

    test('link rejects self-link', () async {
      store['a'] = _recipe(id: 'a');

      final ok = await relations.link('a', 'a');

      expect(ok, isFalse);
      expect(writes, isEmpty);
    });

    test('link rejects missing recipe', () async {
      store['a'] = _recipe(id: 'a');
      // b is not seeded

      final ok = await relations.link('a', 'b');

      expect(ok, isFalse);
      expect(writes, isEmpty);
    });

    test(
        'link returns false on update failure (preserves partial-fail '
        'semantics)', () async {
      store['a'] = _recipe(id: 'a');
      store['b'] = _recipe(id: 'b');
      relations = RecipeRelationsService(
        getRecipe: (id) => store[id],
        // First write succeeds, second fails — emulates partial Firestore
        // outage. link returns false; future link/unlink normalises.
        updateRecipe: (recipe) async {
          writes.add(recipe);
          if (writes.length == 2) return false;
          store[recipe.id] = recipe;
          return true;
        },
      );

      final ok = await relations.link('a', 'b');

      expect(ok, isFalse);
      expect(writes, hasLength(2));
    });

    test('unlink removes both back-references', () async {
      store['a'] = _recipe(id: 'a', related: ['b']);
      store['b'] = _recipe(id: 'b', related: ['a']);

      final ok = await relations.unlink('a', 'b');

      expect(ok, isTrue);
      expect(writes, hasLength(2));
      expect(store['a']!.core.relatedRecipeIds, isEmpty);
      expect(store['b']!.core.relatedRecipeIds, isEmpty);
    });

    test('unlink is idempotent when already unlinked — no writes', () async {
      store['a'] = _recipe(id: 'a');
      store['b'] = _recipe(id: 'b');

      final ok = await relations.unlink('a', 'b');

      expect(ok, isTrue);
      expect(writes, isEmpty);
    });

    test('unlink rejects self-unlink', () async {
      store['a'] = _recipe(id: 'a', related: ['a']);

      final ok = await relations.unlink('a', 'a');

      expect(ok, isFalse);
    });

    test('unlink preserves other relations (only removes the named pair)',
        () async {
      store['a'] = _recipe(id: 'a', related: ['b', 'c']);
      store['b'] = _recipe(id: 'b', related: ['a']);
      store['c'] = _recipe(id: 'c', related: ['a']);

      final ok = await relations.unlink('a', 'b');

      expect(ok, isTrue);
      expect(store['a']!.core.relatedRecipeIds, equals(['c']));
      expect(store['b']!.core.relatedRecipeIds, isEmpty);
      // c untouched — not part of the unlinked pair.
      expect(store['c']!.core.relatedRecipeIds, equals(['a']));
    });
  });
}
