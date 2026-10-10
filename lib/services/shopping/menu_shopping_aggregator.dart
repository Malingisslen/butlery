// lib/services/shopping/menu_shopping_aggregator.dart

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/shopping/ingredient_categorizer.dart';
import 'package:butlery/utils/text/quantity_parser.dart';
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

  /// BUT-2304: further amounts of the same ingredient whose units could not
  /// be converted into [unit] ("100 g" + "3 dl"), kept visible on the one row.
  final List<({double amount, String unit})> extraAmounts;

  const AggregatedShoppingItem({
    required this.name,
    this.amount,
    required this.unit,
    required this.category,
    required this.sourceCount,
    this.extraAmounts = const [],
  });
}

/// BUT-1613: one recipe placement to aggregate, with the presence-derived
/// [factor] its numeric amounts are multiplied by (1.0 = unchanged). The same
/// recipe planned at two placements with different presence counts appears as
/// two entries at two factors, so each scales independently before the shared
/// name|unit merge sums them.
typedef ScaledRecipe = ({Recipe recipe, double factor});

/// BUT-956: pure aggregation of the week's recipe ingredients into shopping
/// lines. Deterministic, no LLM, no IO.
///
/// Rules:
/// - Quantities sum when the normalized name matches AND the units are either
///   identical ("2 dl mjöl" + "1 dl mjöl" → "3 dl mjöl") or compatible within
///   the same measurement family (BUT-1278: "3 dl" + "200 ml" → "500 ml";
///   "1 kg" + "300 g" → "1.3 kg"). Unit-less counts like "st" only sum on an
///   exact unit-string match.
/// - BUT-1613: each placement's numeric amounts are multiplied by its [factor]
///   before summing. Amount-less lines carry no quantity, so a factor can never
///   scale one to zero or drop it — they always pass through present and
///   un-summed. A positive amount times a positive factor stays positive, so a
///   real ingredient never becomes a zero-quantity line.
/// - Entries without a usable amount (ranges, "efter smak", legacy raw-only)
///   aggregate by name into a single amount-less line — present, un-summed.
/// - Name key: [SwedishCharacterNormalizer] + lowercase/trim, so "Mjöl" and
///   "mjol" merge; display keeps the first-seen casing.
class MenuShoppingAggregator {
  const MenuShoppingAggregator._();

  /// [excludeNames] (BUT-1279): normalized ingredient names to drop from the
  /// result — used to keep pantry staples off the generated list. Each name
  /// must already be passed through [SwedishCharacterNormalizer.normalize].
  /// Retained as public API: since BUT-1613 the generator splits staples from
  /// a single unfiltered pass, so the only current caller is the unit test.
  static List<AggregatedShoppingItem> aggregate(
    List<ScaledRecipe> placements, {
    Set<String> excludeNames = const {},
  }) => aggregateForMerge(placements, excludeNames: excludeNames).items;

  /// P6-U02: the aggregation the merge sheet (#inkopmerge) reads, with the
  /// numbers its summary shows.
  ///
  /// [mergeDuplicates] and [convertUnits] are the sheet's first two switches
  /// (Skarmar v12 del 2 #inkopmergeoppen: "Slå samman dubbletter",
  /// "Konvertera enheter"). With [mergeDuplicates] off every ingredient line
  /// stays its own row, as written. Conversion only ever joins rows of the
  /// same ingredient, so with merging off it has nothing to join and does
  /// nothing (an interpretation: the drawing shows both switches on).
  /// [convertUnits] off keeps "2 dl" and "100 ml" as two rows.
  static MenuShoppingAggregation aggregateForMerge(
    List<ScaledRecipe> placements, {
    Set<String> excludeNames = const {},
    bool mergeDuplicates = true,
    bool convertUnits = true,
  }) {
    // Keyed by "<normalizedName>|<normalizedUnit>"; amount-less entries use
    // the unit-less key so "1-2 vitlöksklyftor" and "vitlök efter smak"
    // don't multiply into near-duplicate lines per recipe.
    final byKey = <String, _Accumulator>{};
    var rawRows = 0;

    for (final placement in placements) {
      final factor = placement.factor;
      // One entry per ingredient line, structured or raw-only — the facade
      // getter guarantees alignment and fallback.
      for (final entry in placement.recipe.structuredIngredients) {
        final displayName = entry.name.trim();
        if (displayName.isEmpty) continue;
        final nameKey = SwedishCharacterNormalizer.normalize(displayName);
        if (excludeNames.contains(nameKey)) continue;
        rawRows++;
        final hasAmount = entry.amount != null;
        final unit = hasAmount ? entry.unit.orEmpty().toLowerCase().trim() : '';
        // Merging off: the row counter keeps every line apart.
        final key = mergeDuplicates ? '$nameKey|$unit' : '$rawRows';

        final acc = byKey.putIfAbsent(
          key,
          () => _Accumulator(
            displayName: displayName,
            nameKey: nameKey,
            unit: unit,
            order: byKey.length,
          ),
        );
        acc.sourceCount++;
        if (hasAmount) {
          // BUT-1613: scale the numeric amount by the placement factor. Never
          // round here — the summed double is displayed downstream; a tiny
          // fraction is honest, a zeroed line is not.
          // BUT-2067: a sum of PRODUCTS, and `acc.sum` reaches
          // `UnifiedShoppingItem.amount` through
          // `menu_shopping_list_generator.dart`. Guarded on the running total
          // rather than on the operands, because both can be finite while the
          // total is not.
          acc.sum = QuantityParser.finiteQuantityOr1(
            acc.sum + entry.amount!.toDouble() * factor,
            'menu_shopping_aggregator week scaling',
          );
          acc.hasAmount = true;
        }
      }
    }

    final converted = _ConversionCount();
    final merged = mergeDuplicates && convertUnits
        ? _mergeCompatibleUnits(byKey.values, converted)
        : byKey.values;

    // BUT-2304: whatever pass 2 could not join (weight vs volume, a unit-less
    // count) still names one ingredient, so it shares one row.
    final folded = mergeDuplicates ? _foldByName(merged) : merged;

    final items =
        folded
            .map(
              (acc) => AggregatedShoppingItem(
                name: acc.displayName,
                amount: acc.hasAmount ? acc.sum : null,
                unit: acc.unit,
                category: IngredientCategorizer.categorize(acc.displayName),
                sourceCount: acc.sourceCount,
                extraAmounts: acc.extraAmounts,
              ),
            )
            .toList()
          // Stable, shopping-friendly order: by category, then name.
          ..sort((a, b) {
            final byCategory = a.category.compareTo(b.category);
            if (byCategory != 0) return byCategory;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
    return MenuShoppingAggregation(
      items: items,
      rawRowCount: rawRows,
      convertedCount: converted.value,
    );
  }

  /// BUT-2304: third pass. Rows left sharing a name key (their units are not
  /// convertible) fold into the first-seen row; the first row with an amount
  /// is primary, later amount-bearing rows become extra amounts. Amount-less
  /// rows add nothing visible beyond their source count.
  static List<_Accumulator> _foldByName(Iterable<_Accumulator> rows) {
    final byName = <String, List<_Accumulator>>{};
    for (final row in rows) {
      byName.putIfAbsent(row.nameKey, () => []).add(row);
    }
    return [
      for (final group in byName.values)
        if (group.length == 1) group.first else _foldGroup(group),
    ];
  }

  static _Accumulator _foldGroup(List<_Accumulator> unordered) {
    // Pass 2 emits unjoinable rows before joined ones; restore first-seen
    // order so the display name and primary amount are deterministic.
    final group = [...unordered]..sort((a, b) => a.order.compareTo(b.order));
    final withAmount = group.where((r) => r.hasAmount).toList();
    final primary = withAmount.isEmpty ? group.first : withAmount.first;
    return _Accumulator(
        displayName: group.first.displayName,
        nameKey: primary.nameKey,
        unit: primary.unit,
        order: group.first.order,
      )
      ..sum = primary.sum
      ..hasAmount = primary.hasAmount
      ..sourceCount = group.fold(0, (n, r) => n + r.sourceCount)
      ..extraAmounts = [
        for (final r in withAmount.skip(1)) (amount: r.sum, unit: r.unit),
      ];
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
    _ConversionCount converted,
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
      // BUT-2067: pass 2 needs its own guard, because `toCanonicalBase`
      // MULTIPLIES on the way to the base unit (x100 for dl, x1000 for l and
      // kg). A total that pass 1 passed as finite can overflow right here, and
      // this route needs ONE row rather than two — `RecipeIngredient` parses
      // its amount with a bare `num.tryParse`, so an imported or OCR-read line
      // carries any magnitude it likes into the conversion.
      group.baseQuantity = QuantityParser.finiteQuantityOr1(
        group.baseQuantity + canonical.quantity,
        'menu_shopping_aggregator unit merge',
      );
      group.sourceCount += acc.sourceCount;
      group.memberUnits.add(acc.unit);
    }

    final result = <_Accumulator>[...passthrough];
    for (final group in byBase.values) {
      final joined = group.toAccumulator();
      // P6-U02: a row counts as converted when it was joined with another
      // row and now reads in a unit other than its own ("2 dl + 100 ml blir
      // 3 dl": the 100 ml row is converted).
      if (group.memberUnits.length > 1) {
        converted.value += group.memberUnits
            .where((unit) => unit != joined.unit)
            .length;
      }
      result.add(joined);
    }
    return result;
  }
}

/// P6-U02: the aggregated rows and the numbers the merge sheet shows.
class MenuShoppingAggregation {
  const MenuShoppingAggregation({
    required this.items,
    required this.rawRowCount,
    required this.convertedCount,
  });

  /// The rows after merging, sorted by category and name.
  final List<AggregatedShoppingItem> items;

  /// Ingredient lines before any merging ("5 rätter ger 24 rader").
  final int rawRowCount;

  /// Rows that were joined into a row written in another unit.
  final int convertedCount;

  /// Rows that merging removed ("6 slås samman").
  int get mergedCount => rawRowCount - items.length;
}

class _ConversionCount {
  int value = 0;
}

class _Accumulator {
  _Accumulator({
    required this.displayName,
    required this.nameKey,
    required this.unit,
    required this.order,
  });
  final String displayName;
  final String nameKey;
  final String unit;

  /// BUT-2304: first-seen position in pass 1.
  final int order;
  double sum = 0;
  bool hasAmount = false;
  int sourceCount = 0;
  List<({double amount, String unit})> extraAmounts = const [];
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

  /// The unit each joined row was written in, one entry per row.
  final List<String> memberUnits = [];

  _Accumulator toAccumulator() {
    // Sum lives in the base unit; convert up to the most readable Swedish
    // unit for display (e.g. 500 ml stays ml, 1300 g → 1.3 kg).
    final display =
        _asSpoons() ??
        SmartUnitConverter.convertToReadableUnit(baseQuantity, baseUnit);
    return _Accumulator(
        displayName: firstSeen.displayName,
        nameKey: firstSeen.nameKey,
        unit: display.unit,
        order: firstSeen.order,
      )
      ..sum = display.quantity
      ..hasAmount = true
      ..sourceCount = sourceCount;
  }

  static const _spoonUnits = {
    'msk',
    'matsked',
    'matskedar',
    'tsk',
    'tesked',
    'teskedar',
    'krm',
    'kryddmått',
  };

  /// BUT-2304: nobody shops for sugar in centiliters, so a total written only
  /// in spoons stays in spoons instead of reading "3 cl socker". The largest
  /// spoon that measures it in half steps wins, except that half a msk reads
  /// as 1.5 tsk.
  ConvertedMeasurement? _asSpoons() {
    if (memberUnits.isEmpty || !memberUnits.every(_spoonUnits.contains)) {
      return null;
    }
    for (final (unit, ml, least) in const [
      ('msk', 15.0, 1.0),
      ('tsk', 5.0, 0.5),
      ('krm', 1.0, 0.5),
    ]) {
      final count = baseQuantity / ml;
      final halves = count * 2;
      if (count >= least && (halves - halves.roundToDouble()).abs() < 1e-9) {
        return ConvertedMeasurement(count, unit);
      }
    }
    return ConvertedMeasurement(baseQuantity / 15, 'msk');
  }
}
