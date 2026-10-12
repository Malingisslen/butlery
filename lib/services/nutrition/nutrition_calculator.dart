import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/services/nutrition/nutrient_values.dart';
import 'package:butlery/services/nutrition/nutrition_amount.dart';
import 'package:butlery/models/nutrition/nutrition_amount_choice.dart';
import 'package:butlery/services/nutrition/nutrition_key.dart';
import 'package:butlery/services/nutrition/nutrition_table.dart';
import 'package:butlery/utils/text/ingredient_normalizer.dart';
import 'package:butlery/utils/text/structured_ingredient_deriver.dart';

enum NutritionLineStatus {
  counted,

  /// Counted from a usual amount, or one the household entered.
  estimated,

  /// Salt, pepper or herbs with no amount: left out of both the total and
  /// the "x av y" count.
  skipped,

  /// No food matched the name; the user can pick one.
  noMatch,

  /// A food matched but the amount could not be turned into grams.
  noAmount,
}

/// Where the amount of an [NutritionLineStatus.estimated] line came from.
enum NutritionAmountSource { usual, household, thisRecipe }

class NutritionLine {
  final String name;
  final String? storageKey;
  final NutritionFood? food;
  final double? grams;
  final NutritionLineStatus status;

  /// The food came from the household's own choice.
  final bool chosenByHousehold;

  /// The amount an estimated line was counted from, in [amountUnit].
  final double? amount;
  final String? amountUnit;
  final NutritionAmountSource? amountSource;

  /// Units the user can enter for this line: those that weigh out to grams
  /// for its food. Empty when no food matched.
  final List<String> enterableUnits;

  const NutritionLine({
    required this.name,
    required this.storageKey,
    required this.status,
    this.food,
    this.grams,
    this.chosenByHousehold = false,
    this.amount,
    this.amountUnit,
    this.amountSource,
    this.enterableUnits = const [],
  });

  bool get isCounted =>
      status == NutritionLineStatus.counted ||
      status == NutritionLineStatus.estimated;
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

  int get countedLines => lines.where((l) => l.isCounted).length;

  int get estimatedLines =>
      lines.where((l) => l.status == NutritionLineStatus.estimated).length;

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
/// it never guesses a food.
class NutritionCalculator {
  final NutritionTable table;

  /// The household's own picks: storage key → food id.
  final Map<String, int> householdChoices;

  /// The household's own amounts: an ingredient key (every recipe, per four
  /// portions) or a recipe key (that recipe, as entered).
  final Map<String, NutritionAmountChoice> amountChoices;

  /// The portions the curated usual amounts and an all-recipes amount are
  /// written for.
  static const int referencePortions = 4;

  const NutritionCalculator({
    required this.table,
    this.householdChoices = const {},
    this.amountChoices = const {},
  });

  NutritionSummary calculate({
    required List<RecipeIngredient> ingredients,
    required int? portions,
    String? recipeId,
  }) {
    var total = NutrientValues.zero;
    final lines = <NutritionLine>[];
    final scale =
        (portions == null || portions <= 0 ? referencePortions : portions) /
        referencePortions;
    for (final entry in ingredients) {
      final line = _line(_structured(entry), recipeId, scale);
      if (line.isCounted) {
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

  NutritionLine _line(RecipeIngredient entry, String? recipeId, double scale) {
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
    final enterable = _enterableUnits(weights);
    final amount = entry.amount;
    final ownGrams = amount == null
        ? null
        : NutritionAmount.grams(
            amount: amount,
            unit: entry.unit,
            match: weights,
          );
    if (ownGrams != null) {
      return NutritionLine(
        name: name,
        storageKey: storageKey,
        food: food,
        grams: ownGrams,
        chosenByHousehold: chosenFood != null,
        status: NutritionLineStatus.counted,
        enterableUnits: enterable,
      );
    }
    // A stated amount the table cannot weigh ("1 nypa") is the recipe's own
    // word, so only the household's amount may replace it, not a usual one.
    final estimate = _estimate(
      storageKey,
      recipeId,
      scale,
      weights,
      allowUsual: amount == null,
    );
    if (estimate != null) {
      return NutritionLine(
        name: name,
        storageKey: storageKey,
        food: food,
        grams: estimate.grams,
        chosenByHousehold: chosenFood != null,
        status: NutritionLineStatus.estimated,
        amount: estimate.amount,
        amountUnit: estimate.unit,
        amountSource: estimate.source,
        enterableUnits: enterable,
      );
    }
    return NutritionLine(
      name: name,
      storageKey: storageKey,
      food: food,
      chosenByHousehold: chosenFood != null,
      enterableUnits: enterable,
      status: amount == null && weights.toTaste
          ? NutritionLineStatus.skipped
          : NutritionLineStatus.noAmount,
    );
  }

  /// The amount to count a line with none of its own: the household's amount
  /// for this recipe, then its amount for every recipe, then the curated
  /// usual amount. Null when none of them weighs out.
  ({double grams, double amount, String unit, NutritionAmountSource source})?
  _estimate(
    String? storageKey,
    String? recipeId,
    double scale,
    IngredientMatch weights, {
    required bool allowUsual,
  }) {
    final recipeKey = storageKey == null || recipeId == null
        ? null
        : NutritionAmountChoice.recipeKey(recipeId, storageKey);
    final candidates = [
      (amountChoices[recipeKey], 1.0, NutritionAmountSource.thisRecipe),
      (amountChoices[storageKey], scale, NutritionAmountSource.household),
      (
        allowUsual ? weights.defaultAmount : null,
        scale,
        NutritionAmountSource.usual,
      ),
    ];
    for (final (choice, factor, source) in candidates) {
      if (choice == null) continue;
      final amount = choice.amount * factor;
      final grams = NutritionAmount.grams(
        amount: amount,
        unit: choice.unit,
        match: weights,
      );
      if (grams != null) {
        return (
          grams: grams,
          amount: amount,
          unit: choice.unit,
          source: source,
        );
      }
    }
    return null;
  }

  List<String> _enterableUnits(IngredientMatch weights) => [
    for (final unit in NutritionAmountChoice.allowedUnits)
      if (unit == 'g' ||
          unit == 'kg' ||
          (unit == 'st'
              ? weights.gramsPerUnit.containsKey('st')
              : weights.gramsPerDl != null))
        unit,
  ];

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
