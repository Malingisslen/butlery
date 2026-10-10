import 'dart:convert';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/services/nutrition/nutrient_values.dart';
import 'package:butlery/services/nutrition/nutrition_key.dart';

/// One food in Livsmedelsverket's database, values per 100 g edible part.
class NutritionFood {
  final int id;
  final String name;
  final NutrientValues per100g;

  const NutritionFood({
    required this.id,
    required this.name,
    required this.per100g,
  });
}

/// How a common ingredient maps onto a food, and what its kitchen units
/// weigh. Hand-curated in `assets/data/naring_matchning.json`.
class IngredientMatch {
  final int foodId;

  /// Grams per decilitre; null when the ingredient is not measured by volume.
  final double? gramsPerDl;

  /// Grams per piece-type unit ("st", "klyfta", "burk"...).
  final Map<String, double> gramsPerUnit;

  /// Salt, pepper, herbs: a line without an amount counts as nothing rather
  /// than as an ingredient that could not be counted.
  final bool toTaste;

  const IngredientMatch({
    required this.foodId,
    this.gramsPerDl,
    this.gramsPerUnit = const {},
    this.toTaste = false,
  });

  factory IngredientMatch.fromJson(Map<String, dynamic> json) =>
      IngredientMatch(
        foodId: (json['food'] as num).toInt(),
        gramsPerDl: (json['gPerDl'] as num?)?.toDouble(),
        gramsPerUnit: {
          for (final e
              in ((json['units'] as Map<String, dynamic>?) ?? const {}).entries)
            e.key: (e.value as num).toDouble(),
        },
        toTaste: json['toTaste'] == true,
      );
}

/// The bundled food table plus the curated ingredient table.
class NutritionTable {
  final Map<int, NutritionFood> _foods;
  final Map<String, IngredientMatch> _ingredients;
  final Map<String, String> _aliases;
  final Set<String> _negligible;

  /// Livsmedelsverket's publication date of the bundled table.
  final String version;

  NutritionTable._(
    this._foods,
    this._ingredients,
    this._aliases,
    this._negligible,
    this.version,
  );

  factory NutritionTable.fromJsonStrings({
    required String foodsJson,
    required String matchingJson,
  }) {
    final foodsDoc = jsonDecode(foodsJson) as Map<String, dynamic>;
    final foods = <int, NutritionFood>{
      for (final raw in foodsDoc['foods'] as List<dynamic>)
        (raw as Map<String, dynamic>)['id'] as int: NutritionFood(
          id: raw['id'] as int,
          name: raw['name'] as String,
          per100g: NutrientValues.fromJson(raw),
        ),
    };
    final matchingDoc = jsonDecode(matchingJson) as Map<String, dynamic>;
    // Curated names go through the same key function as recipe lines, so
    // "kycklingfilé" in the file matches "Kycklingfile" in a recipe.
    final ingredients = <String, IngredientMatch>{
      for (final e
          in (matchingDoc['ingredients'] as Map<String, dynamic>).entries)
        NutritionKey.lookupKey(e.key): IngredientMatch.fromJson(
          e.value as Map<String, dynamic>,
        ),
    };
    final aliases = <String, String>{
      for (final e
          in ((matchingDoc['aliases'] as Map<String, dynamic>?) ?? const {})
              .entries)
        NutritionKey.lookupKey(e.key): NutritionKey.lookupKey(
          e.value as String,
        ),
    };
    final negligible = <String>{
      for (final name
          in (matchingDoc['negligible'] as List<dynamic>?) ?? const [])
        NutritionKey.lookupKey(name as String),
    };
    return NutritionTable._(
      foods,
      ingredients,
      aliases,
      negligible,
      (foodsDoc['version'] as String?).orEmpty(),
    );
  }

  NutritionFood? food(int id) => _foods[id];

  // Folded once, on the first search, rather than on every keystroke.
  late final Map<int, String> _searchNames = {
    for (final f in _foods.values) f.id: NutritionKey.lookupKey(f.name),
  };

  /// The curated entry for an already-normalised ingredient name, following
  /// one alias hop.
  IngredientMatch? curated(String name) =>
      _ingredients[name] ?? _ingredients[_aliases[name]];

  /// Spices and the like that are not in Livsmedelsverket's database and
  /// add too little to matter; already-normalised name.
  bool isNegligible(String name) => _negligible.contains(name);

  /// Foods whose name contains every word of [query], shortest names first so
  /// "Mjölk" ranks above "Mjölkchoklad".
  List<NutritionFood> search(String query, {int limit = 50}) {
    // Folded like ingredient names, so "creme fraiche" finds "Crème fraîche".
    final words = NutritionKey.lookupKey(
      query,
    ).split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final hits =
        _foods.values.where((f) {
          final name = _searchNames[f.id].orEmpty();
          return words.every(name.contains);
        }).toList()..sort((a, b) {
          final byLength = a.name.length.compareTo(b.name.length);
          return byLength != 0 ? byLength : a.name.compareTo(b.name);
        });
    return hits.take(limit).toList();
  }
}
