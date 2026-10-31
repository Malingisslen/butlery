import 'package:butlery/models/tagging/ingredient_data.dart';

/// One ingredient line of a recipe as the tagging sees it: the names parsed
/// from it ("salt och peppar" is two), the database rows they matched, and
/// its weight when the amount could be turned into grams.
class IngredientLine {
  final List<String> names;
  final List<IngredientData> ingredients;

  /// Every name on the line matched a database row.
  final bool known;

  final double? grams;

  const IngredientLine({
    required this.names,
    required this.ingredients,
    required this.known,
    this.grams,
  });

  IngredientLine withGrams(double? grams) => IngredientLine(
    names: names,
    ingredients: ingredients,
    known: known,
    grams: grams,
  );

  @override
  String toString() =>
      'IngredientLine(${names.join(' + ')}, ${grams?.round() ?? '?'} g)';
}
