/// Intent: a recipe row is linked to the ingredient registry only when its
/// name is unambiguous; a wrong link would make the pantry "cover" a row it
/// does not hold, so every doubtful row must come back without an id.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/ingredients/ingredient_id_resolver.dart';

/// Keys are the diacritic-folded lower-case names the real repository
/// indexes.
class _FakeIngredients extends Fake implements IngredientRepository {
  _FakeIngredients(this.idsByKey, {this.fail = false});

  final Map<String, Set<String>> idsByKey;
  final bool fail;

  @override
  Future<Set<String>> idsForKey(String name) async {
    if (fail) throw StateError('registry offline');
    return idsByKey[name] ?? const {};
  }

  @override
  Future<int> count() async {
    if (fail) throw StateError('registry offline');
    return idsByKey.length;
  }
}

void main() {
  final registry = {
    'lok': {'onion'},
    'bringa': {'beef-brisket', 'lamb-brisket'},
    'mellanmjolk': {'milk'},
    'salt': {'salt'},
    'peppar': {'pepper'},
  };

  Future<String?> idOf(String raw, {String? storedId}) async {
    final resolver = IngredientIdResolver(
      ingredientRepository: _FakeIngredients(registry),
    );
    final out = await resolver.resolve([
      RecipeIngredient(name: raw, raw: raw, ingredientId: storedId),
    ]);
    return out.single.ingredientId;
  }

  test('a unique name resolves, ignoring amount and preparation', () async {
    expect(await idOf('1 hackad lök'), 'onion');
  });

  test(
    'a grocery brand is stripped when the branded name is unknown',
    () async {
      expect(await idOf('2 dl Arla mellanmjölk'), 'milk');
    },
  );

  test(
    'a product state the normalizer drops keeps the plain id away',
    () async {
      // Smoked salmon at home must not cover fresh salmon on the list, so
      // "rökt lax" never takes the id of "lax".
      final resolver = IngredientIdResolver(
        ingredientRepository: _FakeIngredients(const {
          'lax': {'salmon'},
          'tomat': {'tomato'},
          'tomater': {'tomato'},
        }),
      );
      final out = await resolver.resolve([
        RecipeIngredient.rawOnly('200 g rökt lax'),
        RecipeIngredient.rawOnly('400 g krossade tomater'),
      ]);
      expect(out.map((r) => r.ingredientId), [null, null]);
    },
  );

  test('a registry entry for the name as written wins', () async {
    final resolver = IngredientIdResolver(
      ingredientRepository: _FakeIngredients(const {
        'lax': {'salmon'},
        'rokt lax': {'smoked-salmon'},
      }),
    );
    final out = await resolver.resolve([
      RecipeIngredient.rawOnly('200 g rökt lax'),
    ]);
    expect(out.single.ingredientId, 'smoked-salmon');
  });

  test('an ambiguous name gets no id', () async {
    expect(await idOf('500 g bringa'), isNull);
  });

  test(
    'a line naming two ingredients gets no id although both are known',
    () async {
      expect(await idOf('salt och peppar'), isNull);
    },
  );

  test('an unknown name gets no id', () async {
    expect(await idOf('1 msk zaatar'), isNull);
  });

  test('a stale id that no longer resolves is cleared', () async {
    expect(
      await idOf('1 msk zaatar', storedId: 'removed-from-registry'),
      isNull,
    );
  });

  test('every row is resolved independently and keeps its position', () async {
    final resolver = IngredientIdResolver(
      ingredientRepository: _FakeIngredients(registry),
    );
    final out = await resolver.resolve([
      RecipeIngredient.rawOnly('1 lök'),
      RecipeIngredient.rawOnly('500 g bringa'),
      RecipeIngredient.rawOnly('2 dl mellanmjölk'),
    ]);
    expect(out.map((r) => r.ingredientId), ['onion', null, 'milk']);
    expect(out.map((r) => r.raw), [
      '1 lök',
      '500 g bringa',
      '2 dl mellanmjölk',
    ]);
  });

  test('a registry failure returns the rows unchanged, ids included', () async {
    final resolver = IngredientIdResolver(
      ingredientRepository: _FakeIngredients(registry, fail: true),
    );
    final rows = [
      const RecipeIngredient(name: 'lök', raw: '1 lök', ingredientId: 'onion'),
      RecipeIngredient.rawOnly('2 dl mellanmjölk'),
    ];
    expect(await resolver.resolve(rows), rows);
  });

  test('a registry that never loaded keeps the stored ids', () async {
    final resolver = IngredientIdResolver(
      ingredientRepository: _FakeIngredients(const {}),
    );
    final rows = [
      const RecipeIngredient(name: 'lök', raw: '1 lök', ingredientId: 'onion'),
    ];
    expect(await resolver.resolve(rows), rows);
  });

  test('no rows resolves to no rows without touching the registry', () async {
    final resolver = IngredientIdResolver(
      ingredientRepository: _FakeIngredients(registry, fail: true),
    );
    expect(await resolver.resolve(const []), isEmpty);
  });
}
