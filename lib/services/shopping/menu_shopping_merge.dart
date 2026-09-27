// lib/services/shopping/menu_shopping_merge.dart
//
// P6-U02: the week menu to shopping list merge (#inkopmerge), as values and
// one pure computation. MenuShoppingListGenerator writes what this computes.

import 'package:flutter/foundation.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/shopping/menu_shopping_aggregator.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';
import 'package:butlery/utils/text/unit_converter.dart';

/// P6-U02: the merge sheet's four switches (Skarmar v12 del 2
/// #inkopmergeoppen). "Ersätt listan" is always off by default ("Ersätt
/// listan är alltid av som standard"); the other three are drawn on.
@immutable
class MenuShoppingMergeOptions {
  const MenuShoppingMergeOptions({
    this.mergeDuplicates = true,
    this.convertUnits = true,
    this.subtractPantry = true,
    this.replaceList = false,
  });

  final bool mergeDuplicates;
  final bool convertUnits;
  final bool subtractPantry;
  final bool replaceList;

  MenuShoppingMergeOptions copyWith({
    bool? mergeDuplicates,
    bool? convertUnits,
    bool? subtractPantry,
    bool? replaceList,
  }) => MenuShoppingMergeOptions(
    mergeDuplicates: mergeDuplicates ?? this.mergeDuplicates,
    convertUnits: convertUnits ?? this.convertUnits,
    subtractPantry: subtractPantry ?? this.subtractPantry,
    replaceList: replaceList ?? this.replaceList,
  );
}

/// P6-U02: what a week gives the merge, one scaled placement per planned
/// meal (BUT-1613), and the week whose list receives the rows.
@immutable
class MenuShoppingSource {
  const MenuShoppingSource({
    required this.week,
    required this.placements,
    required this.recipeCount,
    this.unresolvedRecipes = 0,
    this.scaledMeals = 0,
  });

  /// A day in the week whose generated list receives the rows.
  final DateTime week;
  final List<ScaledRecipe> placements;

  /// Distinct recipes ("5 rätter ger 24 rader").
  final int recipeCount;
  final int unresolvedRecipes;
  final int scaledMeals;

  bool get isEmpty => placements.isEmpty;
}

/// P6-U02: the pantry as read for one merge. [unavailable] means the read
/// failed: the list is then made without pantry deduction, and the sheet
/// says so (produktregler.md:697).
@immutable
class MenuShoppingPantry {
  const MenuShoppingPantry.read(this.items) : unavailable = false;
  const MenuShoppingPantry.unavailable() : items = const [], unavailable = true;

  final List<PantryItem> items;
  final bool unavailable;
}

/// How the pantry marked a row (produktregler.md:228-232).
enum MenuShoppingPantryMark {
  none,

  /// "Kanske hemma": at home in an unknown amount, or in a unit that cannot
  /// be converted. No deduction.
  maybeAtHome,

  /// "Kolla datum": at home, but past its date. No deduction.
  checkDate,
}

/// P6-U02: one row the merge will put on the list.
@immutable
class MenuShoppingMergeLine {
  const MenuShoppingMergeLine({
    required this.name,
    required this.amount,
    required this.unit,
    required this.category,
    required this.sourceCount,
    this.mark = MenuShoppingPantryMark.none,
  });

  final String name;

  /// Null for a row without a usable amount.
  final double? amount;
  final String unit;
  final String category;

  /// How many recipe lines went into the row.
  final int sourceCount;
  final MenuShoppingPantryMark mark;
}

/// P6-U02: what "Lägg till N varor" will do, computed before anything is
/// written, so the sheet's summary and its button always agree.
@immutable
class MenuShoppingMergePreview {
  const MenuShoppingMergePreview({
    required this.source,
    required this.options,
    required this.lines,
    required this.rawRowCount,
    required this.mergedCount,
    required this.convertedCount,
    required this.atHomeCount,
    required this.coveredAtHome,
    required this.pantryUnavailable,
  });

  final MenuShoppingSource source;
  final MenuShoppingMergeOptions options;
  final List<MenuShoppingMergeLine> lines;

  /// Ingredient lines before merging ("24 rader").
  final int rawRowCount;

  /// "6 slås samman".
  final int mergedCount;

  /// "3 konverteras".
  final int convertedCount;

  /// "6 finns hemma": the rows the pantry touched in any way.
  final int atHomeCount;

  /// Rows left off because enough is at home, by name, so the deduction can
  /// be seen (produktregler.md:234).
  final List<String> coveredAtHome;

  /// The pantry could not be read, so nothing was subtracted.
  final bool pantryUnavailable;

  int get recipeCount => source.recipeCount;

  /// "Efter sammanslagning blir det 18 varor" and "Lägg till 18 varor".
  int get itemCount => lines.length;
}

/// P6-U02: what a merge wrote, so Ångra can take back exactly that
/// (produktregler.md:131, § 2.4: `add` is class 1 with a 7 s Ångra).
@immutable
class MenuShoppingMergeReceipt {
  const MenuShoppingMergeReceipt({
    required this.listId,
    required this.listName,
    required this.addedItemIds,
    required this.removedItems,
    required this.previousMenuItemIds,
    required this.replaced,
    required this.createdList,
  });

  final String listId;
  final String listName;
  final List<String> addedItemIds;

  /// The recipe rows "Ersätt listan" took off, put back by Ångra.
  final List<UnifiedShoppingItem> removedItems;
  final List<String>? previousMenuItemIds;
  final bool replaced;
  final bool createdList;

  int get itemCount => addedItemIds.length;
}

/// P6-U02: computes a merge. Pure: nothing is read or written.
class MenuShoppingMergePlanner {
  const MenuShoppingMergePlanner._();

  /// Merge order (flows-roles-budget.md:51): duplicates are merged, units
  /// are converted within one kind, then the pantry is subtracted. Pure:
  /// nothing is written.
  static MenuShoppingMergePreview preview(
    MenuShoppingSource source,
    MenuShoppingPantry pantry,
    MenuShoppingMergeOptions options,
  ) {
    final aggregation = MenuShoppingAggregator.aggregateForMerge(
      source.placements,
      mergeDuplicates: options.mergeDuplicates,
      convertUnits: options.convertUnits,
    );
    final subtract = options.subtractPantry && !pantry.unavailable;
    final byName = <String, List<PantryItem>>{};
    if (subtract) {
      for (final item in pantry.items) {
        byName
            .putIfAbsent(
              SwedishCharacterNormalizer.normalize(item.ingredientName),
              () => [],
            )
            .add(item);
      }
    }

    final lines = <MenuShoppingMergeLine>[];
    final covered = <String>[];
    var atHome = 0;
    for (final row in aggregation.items) {
      final matches =
          byName[SwedishCharacterNormalizer.normalize(row.name)] ?? const [];
      if (matches.isEmpty) {
        lines.add(_line(row, row.amount));
        continue;
      }
      atHome++;
      switch (_deduct(row, matches)) {
        case _Covered():
          covered.add(row.name);
        case _Remaining(:final amount):
          lines.add(_line(row, amount));
        case _Marked(:final mark):
          lines.add(_line(row, row.amount, mark: mark));
      }
    }

    return MenuShoppingMergePreview(
      source: source,
      options: options,
      lines: List.unmodifiable(lines),
      rawRowCount: aggregation.rawRowCount,
      mergedCount: aggregation.mergedCount,
      convertedCount: aggregation.convertedCount,
      atHomeCount: atHome,
      coveredAtHome: List.unmodifiable(covered),
      pantryUnavailable: options.subtractPantry && pantry.unavailable,
    );
  }

  static MenuShoppingMergeLine _line(
    AggregatedShoppingItem row,
    double? amount, {
    MenuShoppingPantryMark mark = MenuShoppingPantryMark.none,
  }) => MenuShoppingMergeLine(
    name: row.name,
    amount: amount,
    unit: row.unit,
    category: row.category,
    sourceCount: row.sourceCount,
    mark: mark,
  );

  /// Q4-03: the same deduction for one row outside a merge (the recipe's
  /// "Lägg {n} varor i inköpslistan"), so a recipe and a week count against
  /// the pantry by one rule. [pantry] is the whole pantry; the rows are
  /// matched by normalised name as in [preview]. Returns the amount still
  /// to buy: null when enough is at home, [amount] unchanged when nothing
  /// can be subtracted (no match, an unknown amount, another unit family,
  /// past its date), else the difference.
  static ({bool covered, double? amount}) toBuy({
    required String name,
    required double? amount,
    required String unit,
    required List<PantryItem> pantry,
  }) {
    final key = SwedishCharacterNormalizer.normalize(name);
    final matches = [
      for (final item in pantry)
        if (SwedishCharacterNormalizer.normalize(item.ingredientName) == key)
          item,
    ];
    if (matches.isEmpty) return (covered: false, amount: amount);
    final row = AggregatedShoppingItem(
      name: name,
      amount: amount,
      unit: unit.toLowerCase().trim(),
      category: '',
      sourceCount: 1,
    );
    return switch (_deduct(row, matches)) {
      _Covered() => (covered: true, amount: null),
      _Remaining(:final amount) => (covered: false, amount: amount),
      _Marked() => (covered: false, amount: amount),
    };
  }

  /// produktregler.md:224-234 (§ 4.2): a known amount at home is subtracted
  /// and only the difference goes on the list; enough at home leaves the row
  /// off; an unknown amount, a unit that cannot be converted, or a row
  /// without an amount gives no deduction and "Kanske hemma"; a row past its
  /// date gives no deduction and "Kolla datum".
  static _Deduction _deduct(AggregatedShoppingItem row, List<PantryItem> at) {
    if (at.any((p) => p.expiryStatus == PantryExpiryStatus.expired)) {
      return const _Marked(MenuShoppingPantryMark.checkDate);
    }
    final need = row.amount;
    if (need == null || need <= 0) {
      return const _Marked(MenuShoppingPantryMark.maybeAtHome);
    }
    final needBase = SmartUnitConverter.toCanonicalBase(need, row.unit);
    var have = 0.0;
    for (final item in at) {
      final quantity = item.quantity;
      if (quantity == null) {
        return const _Marked(MenuShoppingPantryMark.maybeAtHome);
      }
      final unit = item.unit.toLowerCase().trim();
      if (unit == row.unit) {
        have += quantity;
        continue;
      }
      final haveBase = SmartUnitConverter.toCanonicalBase(quantity, unit);
      if (needBase == null ||
          haveBase == null ||
          haveBase.baseUnit != needBase.baseUnit) {
        return const _Marked(MenuShoppingPantryMark.maybeAtHome);
      }
      // Into the row's own unit through the family's base unit.
      have += haveBase.quantity * need / needBase.quantity;
    }
    if (have >= need) return const _Covered();
    return _Remaining(need - have);
  }
}

sealed class _Deduction {
  const _Deduction();
}

/// Enough is at home: the row stays off the list.
final class _Covered extends _Deduction {
  const _Covered();
}

/// Some is at home: the difference goes on the list.
final class _Remaining extends _Deduction {
  const _Remaining(this.amount);
  final double amount;
}

/// At home, but nothing can be subtracted.
final class _Marked extends _Deduction {
  const _Marked(this.mark);
  final MenuShoppingPantryMark mark;
}
