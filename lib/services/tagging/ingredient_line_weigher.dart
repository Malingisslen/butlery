import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/services/nutrition/nutrition_calculator.dart';
import 'package:butlery/services/nutrition/nutrition_service.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';
import 'package:butlery/services/tagging/tagging_phase_budgets.dart';
import 'package:butlery/utils/text/structured_ingredient_deriver.dart';
import 'package:butlery/utils/text/unit_converter.dart';

/// Puts each line's weight on a lookup, so the tagging can tell the main
/// ingredients from the rest (kärnflöde steg 5 beslut 7).
abstract final class IngredientLineWeigher {
  /// [weigh] with the app's bundled table. Without weights the main
  /// ingredients come from the line order, so a failure here returns the
  /// lookup unweighed rather than stopping the tagging.
  static Future<IngredientLookupResult> weighWithAppTable(
    IngredientLookupResult lookup,
    Recipe recipe,
    List<String> lookedUp,
  ) async {
    NutritionTable? table;
    try {
      table = await ServiceLocator.tryGet<NutritionService>()?.table().timeout(
        kLookupBudget,
      );
    } catch (e) {
      // A line stated in grams still weighs without the table.
      AppLogger.warning('Tagging: the nutrition table did not load: $e');
    }
    try {
      return weigh(
        lookup: lookup,
        recipe: recipe,
        lookedUp: lookedUp,
        table: table,
      );
    } catch (e) {
      AppLogger.warning('Tagging: weighing the ingredient lines failed: $e');
      return lookup;
    }
  }

  /// [lookedUp] is the list the lookup was made from: the recipe's lines or
  /// their normalized names, which leave out the empty lines. Only an amount
  /// the recipe states counts; the household's own amounts and the usual
  /// amounts are left out, so a recipe gets the same tags in every home.
  /// A line stated in grams or kilos is weighed even when [table] is null or
  /// does not know the food.
  static IngredientLookupResult weigh({
    required IngredientLookupResult lookup,
    required Recipe recipe,
    required List<String> lookedUp,
    required NutritionTable? table,
  }) {
    final lines = lookup.lines;
    if (!lookup.hasRecipeLines || lines.length != lookedUp.length) {
      return lookup;
    }
    final raw = recipe.core.ingredients;
    final nonEmpty = [
      for (var i = 0; i < raw.length; i++)
        if (raw[i].trim().isNotEmpty) i,
    ];
    final List<int> recipeIndex;
    if (_same(lookedUp, raw)) {
      recipeIndex = [for (var i = 0; i < raw.length; i++) i];
    } else if (lookedUp.length == nonEmpty.length) {
      recipeIndex = nonEmpty;
    } else {
      return lookup;
    }
    final structured = recipe.structuredIngredients;
    final weights = table == null
        ? null
        : NutritionCalculator(table: table)
              .calculate(
                ingredients: structured,
                portions: recipe.core.portions,
              )
              .lines;
    double? gramsOf(int i) {
      final line = weights?[i];
      if (line != null && line.status == NutritionLineStatus.counted) {
        return line.grams;
      }
      return _statedWeight(structured[i]);
    }

    return lookup.withLines([
      for (var k = 0; k < lines.length; k++)
        lines[k].withGrams(gramsOf(recipeIndex[k])),
    ]);
  }

  static double? _statedWeight(RecipeIngredient entry) {
    final parsed = entry.amount == null && entry.unit == null
        ? StructuredIngredientDeriver.derive(entry.raw)
        : entry;
    final amount = parsed.amount;
    final unit = parsed.unit?.toLowerCase().trim();
    if (amount == null || unit == null || unit.isEmpty) return null;
    final measure = SmartUnitConverter.toCanonicalBase(amount.toDouble(), unit);
    return measure?.baseUnit == 'g' ? measure!.quantity : null;
  }

  static bool _same(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
