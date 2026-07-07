// lib/services/shopping/menu_shopping_aggregator.dart

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/shopping/ingredient_categorizer.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';
import 'package:butlery/utils/text/unit_converter.dart';

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
/// Rules:
/// - Quantities sum when the normalized name matches AND the units are either
///   identical ("2 dl mjöl" + "1 dl mjöl" → "3 dl mjöl") or compatible within
///   the same measurement family (BUT-1278: "3 dl" + "200 ml" → "500 ml";
///   "1 kg" + "300 g" → "1.3 kg"). Cross-FAMILY pairs never merge — "200 g" +
///   "1 dl" stay two honest lines (weight vs volume), and unit-less counts
///   like "st" only sum on an exact unit-string match.
/// - Entries without a usable amount (ranges, "efter smak", legacy raw-only)
///   aggregate by name into a single amount-less line — present, un-summed.
/// - Name key: [SwedishCharacterNormalizer] + lowercase/trim, so "Mjöl" and
///   "mjol" merge; display keeps the first-seen casing.
class MenuShoppingAggregator {
  const MenuShoppingAggregator._();

  /// [excludeNames] (BUT-1279): normalized ingredient names to drop from the
  /// result — used to keep pantry staples off the generated list. Each name
  /// must already be passed through [SwedishCharacterNormalizer.normalize].
  static List<AggregatedShoppingItem> aggregate(
    List<Recipe> recipes, {
    Set<String> excludeNames = const {},
  }) {
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
        if (excludeNames.contains(nameKey)) continue;
        final hasAmount = entry.amount != null;
        final unit = hasAmount ? entry.unit.orEmpty().toLowerCase().trim() : '';
        final key = '$nameKey|$unit';

        final acc = byKey.putIfAbsent(
          key,
          () => _Accumulator(
            displayName: displayName,
            nameKey: nameKey,
            unit: unit,
          ),
        );
        acc.sourceCount++;
        if (hasAmount) {
          acc.sum += entry.amount!.toDouble();
          acc.hasAmount = true;
        }
      }
    }

    final merged = _mergeCompatibleUnits(byKey.values);

    final items =
        merged
            .map(
              (acc) => AggregatedShoppingItem(
                name: acc.displayName,
                amount: acc.hasAmount ? acc.sum : null,
                unit: acc.unit,
                category: IngredientCategorizer.categorize(acc.displayName),
                sourceCount: acc.sourceCount,
              ),
            )
            .toList()
          // Stable, shopping-friendly order: by category, then name.
          ..sort((a, b) {
            final byCategory = a.category.compareTo(b.category);
            if (byCategory != 0) return byCategory;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    return items;
  }

  /// BUT-1278: second pass that collapses same-name lines whose units share a
  /// measurement family (dl+ml, g+kg) into one line, summed in the family base
  /// unit and re-displayed in the most readable Swedish unit.
  ///
  /// Lines that can't be reduced to a canonical base (unit-less counts like
  /// "st", amount-less lines, unknown units) pass through untouched — they
  /// already merged exactly-by-unit-string in the first pass.
  static Iterable<_Accumulator> _mergeCompatibleUnits(
    Iterable<_Accumulator> accumulators,
  ) {
    // Keyed by "<nameKey>|<baseUnit>" — only entries with a usable amount AND
    // a recognized family unit are candidates; everything else stays as-is.
    final byBase = <String, _MergeGroup>{};
    final passthrough = <_Accumulator>[];

    for (final acc in accumulators) {
      final canonical = acc.hasAmount
          ? SmartUnitConverter.toCanonicalBase(acc.sum, acc.unit)
          : null;
      if (canonical == null) {
        passthrough.add(acc);
        continue;
      }
      final group = byBase.putIfAbsent(
        '${acc.nameKey}|${canonical.baseUnit}',
        () => _MergeGroup(firstSeen: acc, baseUnit: canonical.baseUnit),
      );
      group.baseQuantity += canonical.quantity;
      group.sourceCount += acc.sourceCount;
    }

    final result = <_Accumulator>[...passthrough];
    for (final group in byBase.values) {
      result.add(group.toAccumulator());
    }
    return result;
  }
}

class _Accumulator {
  _Accumulator({
    required this.displayName,
    required this.nameKey,
    required this.unit,
  });
  final String displayName;
  final String nameKey;
  final String unit;
  double sum = 0;
  bool hasAmount = false;
  int sourceCount = 0;
}

/// BUT-1278: in-progress merge of compatible-unit lines for one ingredient,
/// accumulated in the family base unit (ml or g).
class _MergeGroup {
  _MergeGroup({required this.firstSeen, required this.baseUnit});

  /// Keeps the first-seen display casing for the merged line.
  final _Accumulator firstSeen;

  /// The family base unit ('ml' or 'g') the group accumulates in.
  final String baseUnit;
  double baseQuantity = 0;
  int sourceCount = 0;

  _Accumulator toAccumulator() {
    // Sum lives in the base unit; convert up to the most readable Swedish
    // unit for display (e.g. 500 ml stays ml, 1300 g → 1.3 kg).
    final display = SmartUnitConverter.convertToReadableUnit(
      baseQuantity,
      baseUnit,
    );
    return _Accumulator(
        displayName: firstSeen.displayName,
        nameKey: firstSeen.nameKey,
        unit: display.unit,
      )
      ..sum = display.quantity
      ..hasAmount = true
      ..sourceCount = sourceCount;
  }
}
