import 'package:butlery/constants/grocery_brands.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';

/// Links a recipe's ingredient rows to the ingredient registry, so the list
/// and the pantry can tell "gul lök" and "lök" are one product by id rather
/// than by spelling.
///
/// Stricter than the tagging lookup on purpose. A row only gets an id when
/// its name, or its name without a grocery brand, is the exact name or alias
/// of ONE global ingredient. An ambiguous name ("bringa" is beef and lamb),
/// a row naming two ingredients ("salt och peppar") or a name the lookup only
/// finds by guessing gets none, and is matched by name as before. A wrong id
/// would make the pantry cover a row it does not hold; a missing one only
/// leaves the old name match.
///
/// The user's own ingredients are not consulted: a recipe can be shared, and
/// an id that only exists in one user's collection means nothing to anyone
/// else.
class IngredientIdResolver {
  IngredientIdResolver({required IngredientRepository ingredientRepository})
    : _repository = ingredientRepository;

  final IngredientRepository _repository;

  /// [rows] with each [RecipeIngredient.ingredientId] set from the registry,
  /// or cleared where it can no longer be decided. On a registry failure the
  /// rows come back unchanged, since a recipe must save without its links.
  Future<List<RecipeIngredient>> resolve(List<RecipeIngredient> rows) async {
    if (rows.isEmpty) return rows;
    try {
      // An empty registry is one that could not load (a cold offline start
      // degrades to an empty cache). Nothing found there says nothing about
      // the links a row already has.
      if (await _repository.count() == 0) return rows;
      final ids = await Future.wait(rows.map(_idFor));
      return [
        for (var i = 0; i < rows.length; i++) rows[i].withIngredientId(ids[i]),
      ];
    } catch (e) {
      AppLogger.warning('Could not link ingredient rows to the registry: $e');
      return rows;
    }
  }

  Future<String?> _idFor(RecipeIngredient row) async {
    final names = IngredientLookupService.namesOf(row.raw);
    if (names.length != 1) return null;
    final key = IngredientLookupService.cleanForLookup(names.single);
    if (key.isEmpty) return null;
    var ids = await _repository.idsForKey(key);
    if (ids.isEmpty) {
      final unbranded = GroceryBrands.strip(key);
      if (unbranded != null) ids = await _repository.idsForKey(unbranded);
    }
    return ids.length == 1 ? ids.single : null;
  }
}
