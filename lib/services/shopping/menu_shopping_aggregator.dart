// lib/services/shopping/menu_shopping_aggregator.dart

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/tagging/ingredient_categorizer.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';

/// BUT-956: one aggregated shopping line produced from the week's recipes.
class AggregatedShoppingItem {
  /// Display name — the first-seen original casing of the ingredient name.
  final String name;

  /// Summed amount, or null when the source lines carry no usable quantity
  /// (raw-only entries — they still land on the list, never dropped).
  final double? amount;

  /// Unit as written (post lowercase/trim). Empty for unit-less lines.
  final String unit;

  /// ShoppingCategory constant from [IngredientCategorizer].
  final String category;

  /// How many menu recipes contributed to this line.
  final int sourceCount;

  const AggregatedShoppingItem({
    required this.name,
    this.amount,
    required this.unit,
    required this.category,
    required this.sourceCount,
  });
}

/// BUT-956: pure aggregation of the week's recipe ingredients into shopping
/// lines. Deterministic, no LLM, no IO.
///
/// V1 rules (deliberately narrower than the BUT-1157 epic):
/// - Quantities sum ONLY when the normalized name AND normalized unit match
///   exactly ("2 dl mjöl" + "1 dl mjöl" → "3 dl mjöl"). Cross-unit
///   conversion (200 g + 0.5 cup) stays epic scope — two honest lines beat
///   one wrong sum.
/// - Entries without a usable amount (ranges, "efter smak", legacy raw-only)
///   aggregate by name into a single amount-less line — present, un-summed.
/// - Name key: [SwedishCharacterNormalizer] + lowercase/trim, so "Mjöl" and
///   "mjol" merge; display keeps the first-seen casing.
class MenuShoppingAggregator {
  const MenuShoppingAggregator._();

  static List<AggregatedShoppingItem> aggregate(List<Recipe> recipes) {
    // Keyed by "<normalizedName>|<normalizedUnit>"; amount-less entries use
    // the unit-less key so "1-2 vitlöksklyftor" and "vitlök efter smak"
    // don't multiply into near-duplicate lines per recipe.
    final byKey = <String, _Accumulator>{};

    for (final recipe in recipes) {
      // One entry per ingredient line, structured or raw-only — the facade
      // getter guarantees alignment and fallback.
      for (final entry in recipe.structuredIngredients) {
        final displayName = entry.name.trim();
        if (displayName.isEmpty) continue;
        final nameKey = SwedishCharacterNormalizer.normalize(displayName);
        final hasAmount = entry.amount != null;
        final unit = hasAmount ? entry.unit.orEmpty().toLowerCase().trim() : '';
        final key = '$nameKey|$unit';

        final acc = byKey.putIfAbsent(
          key,
          () => _Accumulator(displayName: displayName, unit: unit),
        );
        acc.sourceCount++;
        if (hasAmount) {
          acc.sum += entry.amount!.toDouble();
          acc.hasAmount = true;
        }
      }
    }

    final items = byKey.values
        .map((acc) => AggregatedShoppingItem(
              name: acc.displayName,
              amount: acc.hasAmount ? acc.sum : null,
              unit: acc.unit,
              category: IngredientCategorizer.categorize(acc.displayName),
              sourceCount: acc.sourceCount,
            ))
        .toList()
      // Stable, shopping-friendly order: by category, then name.
      ..sort((a, b) {
        final byCategory = a.category.compareTo(b.category);
        if (byCategory != 0) return byCategory;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return items;
  }
}

class _Accumulator {
  _Accumulator({required this.displayName, required this.unit});
  final String displayName;
  final String unit;
  double sum = 0;
  bool hasAmount = false;
  int sourceCount = 0;
}
