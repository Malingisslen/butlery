import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/services/nutrition/nutrient_values.dart';
import 'package:butlery/services/nutrition/nutrition_amount.dart';
import 'package:butlery/services/nutrition/nutrition_key.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';
import 'package:butlery/utils/text/ingredient_normalizer.dart';
import 'package:butlery/utils/text/structured_ingredient_deriver.dart';

enum NutritionLineStatus {
  counted,

  /// Salt, pepper or herbs with no amount: left out of both the total and
  /// the "x av y" count.
  skipped,

  /// No food matched the name; the user can pick one.
  noMatch,

  /// A food matched but the amount could not be turned into grams.
  noAmount,
}

class NutritionLine {
  final String name;
  final String? storageKey;
  final NutritionFood? food;
  final double? grams;
  final NutritionLineStatus status;

  /// The food came from the household's own choice.
  final bool chosenByHousehold;

  const NutritionLine({
    required this.name,
    required this.storageKey,
    required this.status,
    this.food,
    this.grams,
    this.chosenByHousehold = false,
  });
}

class NutritionSummary {
  /// The whole recipe as written, at [basePortions].
  final NutrientValues total;
  final int? basePortions;
  final List<NutritionLine> lines;

  const NutritionSummary({
    required this.total,
    required this.basePortions,
    required this.lines,
  });

  int get countedLines =>
      lines.where((l) => l.status == NutritionLineStatus.counted).length;

  int get countableLines =>
      lines.where((l) => l.status != NutritionLineStatus.skipped).length;

  List<NutritionLine> get missing => lines
      .where(
        (l) =>
            l.status == NutritionLineStatus.noMatch ||
            l.status == NutritionLineStatus.noAmount,
      )
      .toList();

  /// Null when the recipe states no portion count.
  NutrientValues? get perPortion {
    final base = basePortions;
    if (base == null || base <= 0) return null;
    return total.scale(1 / base);
  }

  /// The whole recipe scaled to [portions]; the stated total when the recipe
  /// has no portion count to scale from.
  NutrientValues forPortions(int portions) =>
      perPortion?.scale(portions.toDouble()) ?? total;
}

/// Computes a recipe's nutrition from its ingredient lines. Deterministic:
/// it never guesses a food or a weight, and anything it cannot count is
/// reported as missing.
class NutritionCalculator {
  final NutritionTable table;

  /// The household's own picks: storage key → food id.
  final Map<String, int> householdChoices;

  const NutritionCalculator({
    required this.table,
    this.householdChoices = const {},
  });

  NutritionSummary calculate({
    required List<RecipeIngredient> ingredients,
    required int? portions,
  }) {
    var total = NutrientValues.zero;
    final lines = <NutritionLine>[];
    for (final entry in ingredients) {
      final line = _line(_structured(entry));
      if (line.status == NutritionLineStatus.counted) {
        total += line.food!.per100g.scale(line.grams! / 100);
      }
      lines.add(line);
    }
    return NutritionSummary(
      total: total,
      basePortions: portions,
      lines: lines,
    );
  }

  // A legacy line has no parsed amount yet; derive one the same way the
  // recipe form does.
  RecipeIngredient _structured(RecipeIngredient entry) =>
      entry.amount == null && entry.unit == null
      ? StructuredIngredientDeriver.derive(entry.raw)
      : entry;

  NutritionLine _line(RecipeIngredient entry) {
    final name = entry.name.trim().isEmpty ? entry.raw.trim() : entry.name;
    final storageKey = NutritionKey.storageKey(name);
    final candidates = _candidates(name);
    final curated = _firstOrNull(candidates.map(table.curated));
    final chosenId = storageKey == null ? null : householdChoices[storageKey];
    final chosenFood = chosenId == null ? null : table.food(chosenId);
    final food =
        chosenFood ?? (curated == null ? null : table.food(curated.foodId));

    if (food == null && candidates.any(table.isNegligible)) {
      return NutritionLine(
        name: name,
        storageKey: storageKey,
        status: NutritionLineStatus.skipped,
      );
    }
    if (food == null) {
      return NutritionLine(
        name: name,
        storageKey: storageKey,
        status: NutritionLineStatus.noMatch,
      );
    }
    final weights = curated ?? IngredientMatch(foodId: food.id);
    final amount = entry.amount;
    if (amount == null) {
      return NutritionLine(
        name: name,
        storageKey: storageKey,
        food: food,
        chosenByHousehold: chosenFood != null,
        status: weights.toTaste
            ? NutritionLineStatus.skipped
            : NutritionLineStatus.noAmount,
      );
    }
    final grams = NutritionAmount.grams(
      amount: amount,
      unit: entry.unit,
      match: weights,
    );
    return NutritionLine(
      name: name,
      storageKey: storageKey,
      food: food,
      grams: grams,
      chosenByHousehold: chosenFood != null,
      status: grams == null
          ? NutritionLineStatus.noAmount
          : NutritionLineStatus.counted,
    );
  }

  /// Names to look [name] up under, most specific first: as written, then
  /// normalised ("hackad gul lök" → "gul lök"), each also with leading words
  /// dropped ("färsk koriander" → "koriander").
  List<String> _candidates(String name) {
    final key = NutritionKey.lookupKey(name);
    if (key.isEmpty) return const [];
    final normalized = NutritionKey.lookupKey(
      IngredientNormalizer.normalize(key).normalized,
    );
    return [
      for (final candidate in {key, normalized})
        if (candidate.isNotEmpty)
          for (final words in [candidate.split(' ')])
            for (var i = 0; i < words.length; i++) words.sublist(i).join(' '),
    ];
  }

  static T? _firstOrNull<T>(Iterable<T?> values) {
    for (final v in values) {
      if (v != null) return v;
    }
    return null;
  }
}
