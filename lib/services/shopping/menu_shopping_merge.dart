// lib/services/shopping/menu_shopping_merge.dart
//
// P6-U02: the week menu to shopping list merge (#inkopmerge), as values and
// one pure computation. MenuShoppingListGenerator writes what this computes.

import 'package:flutter/foundation.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/ingredients/ingredient_identity.dart';
import 'package:butlery/services/shopping/menu_shopping_aggregator.dart';
import 'package:butlery/services/shopping/week_list_reconciler.dart';
import 'package:butlery/utils/text/unit_converter.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

/// The sheet's three rules, all drawn on.
@immutable
class MenuShoppingMergeOptions {
  const MenuShoppingMergeOptions({
    this.mergeDuplicates = true,
    this.convertUnits = true,
    this.subtractPantry = true,
  });

  final bool mergeDuplicates;
  final bool convertUnits;
  final bool subtractPantry;

  MenuShoppingMergeOptions copyWith({
    bool? mergeDuplicates,
    bool? convertUnits,
    bool? subtractPantry,
  }) => MenuShoppingMergeOptions(
    mergeDuplicates: mergeDuplicates ?? this.mergeDuplicates,
    convertUnits: convertUnits ?? this.convertUnits,
    subtractPantry: subtractPantry ?? this.subtractPantry,
  );

  @override
  bool operator ==(Object other) =>
      other is MenuShoppingMergeOptions &&
      other.mergeDuplicates == mergeDuplicates &&
      other.convertUnits == convertUnits &&
      other.subtractPantry == subtractPantry;

  @override
  int get hashCode =>
      Object.hash(mergeDuplicates, convertUnits, subtractPantry);
}

/// P6-U02: what a week gives the merge, one scaled placement per planned
/// meal (BUT-1613), and the week whose list receives the rows.
@immutable
class MenuShoppingSource {
  const MenuShoppingSource({
    required this.week,
    required this.placements,
    required this.recipeCount,
    this.origin = ShoppingRowOrigin.plan,
    this.unresolvedRecipes = 0,
    this.scaledMeals = 0,
  });

  /// A day in the week whose generated list receives the rows.
  final DateTime week;

  /// Which of the week's two sources this is. Each keeps only its own rows
  /// on the list in step.
  final ShoppingRowOrigin origin;
  final List<ScaledRecipe> placements;

  /// Distinct recipes ("5 rätter ger 24 rader").
  final int recipeCount;
  final int unresolvedRecipes;
  final int scaledMeals;

  bool get isEmpty => placements.isEmpty;
}

/// P6-U02: the pantry as read for one merge. [unavailable] means the read
/// failed: the list is then made without pantry deduction, and the sheet
/// says so.
@immutable
class MenuShoppingPantry {
  const MenuShoppingPantry.read(this.items) : unavailable = false;
  const MenuShoppingPantry.unavailable() : items = const [], unavailable = true;

  final List<PantryItem> items;
  final bool unavailable;
}

/// How the pantry marked a row.
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
    this.recipeCount = 1,
    this.mark = MenuShoppingPantryMark.none,
    this.extraAmounts = const [],
    this.ingredientId,
  });

  final String name;

  /// Null for a row without a usable amount.
  final double? amount;
  final String unit;
  final String category;

  /// How many recipe lines went into the row.
  final int sourceCount;

  /// [AggregatedShoppingItem.recipeCount].
  final int recipeCount;
  final MenuShoppingPantryMark mark;

  /// BUT-2304: amounts in units that could not join [unit].
  final List<({double amount, String unit})> extraAmounts;

  /// [AggregatedShoppingItem.ingredientId].
  final String? ingredientId;

  /// The list row both the week and the recipe button write for this line.
  UnifiedShoppingItem toItem() => UnifiedShoppingItem(
    name: name,
    // The line states no amount, and 0 shows the name alone
    // ([UnifiedShoppingItem.quantityText]).
    amount: amount ?? 0,
    unit: unit,
    category: category,
    note: _note,
    ingredientId: ingredientId,
  );

  /// The amounts that could not join [unit], how many recipes the row came
  /// from ("Raden visar '3 recept'", #inkopmergeoppen) and the pantry's mark
  /// (§ 4.2).
  String? get _note {
    final l = AppLocale.current;
    final parts = [
      // BUT-2304: amounts that could not join the row's own unit.
      for (final extra in extraAmounts) '+ ${_formatExtra(extra)}',
      if (recipeCount > 1) l.shoppingMergeRowRecipes(recipeCount),
      if (mark == MenuShoppingPantryMark.maybeAtHome)
        l.shoppingMergeMarkMaybeHome,
      if (mark == MenuShoppingPantryMark.checkDate)
        l.shoppingMergeMarkCheckDate,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static String _formatExtra(({double amount, String unit}) extra) {
    final item = UnifiedShoppingItem(
      name: '',
      amount: extra.amount,
      unit: extra.unit,
    );
    return [
      item.formattedAmount,
      item.formattedUnit,
    ].where((p) => p.isNotEmpty).join(' ');
  }
}

/// What the pantry leaves of a set of rows ([MenuShoppingMergePlanner.againstPantry]).
class MenuShoppingPantryPass {
  const MenuShoppingPantryPass({
    required this.lines,
    required this.coveredAtHome,
    required this.lessened,
    required this.atHomeCount,
  });

  /// The rows still to buy, in the order they came in.
  final List<MenuShoppingMergeLine> lines;

  /// Rows left off because enough is at home, by name.
  final List<String> coveredAtHome;

  /// Rows kept with less than asked for, because some is at home, by name.
  final List<String> lessened;

  /// The rows the pantry touched in any way.
  final int atHomeCount;
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
  /// be seen.
  final List<String> coveredAtHome;

  /// The pantry could not be read, so nothing was subtracted.
  final bool pantryUnavailable;

  int get recipeCount => source.recipeCount;

  int get unresolvedRecipes => source.unresolvedRecipes;

  /// "Efter sammanslagning blir det 18 varor" and "Lägg till 18 varor".
  int get itemCount => lines.length;
}

@immutable
class MenuShoppingMergeReceipt {
  const MenuShoppingMergeReceipt({
    required this.listId,
    required this.listName,
    required this.addedItemIds,
    required this.removedItems,
    required this.previousMenuItemIds,
    required this.createdList,
    this.changedItems = const [],
    this.concurrentChange = false,
  });

  final String listId;
  final String listName;
  final List<String> addedItemIds;

  /// The rows the sync took off, put back by Ångra.
  final List<UnifiedShoppingItem> removedItems;

  /// The rows the sync overwrote, as they were before, put back by Ångra.
  final List<UnifiedShoppingItem> changedItems;
  final List<String>? previousMenuItemIds;
  final bool createdList;

  /// BUT-2140: the list had been changed on another device before the write.
  /// Nothing the user did there was overwritten, and the receipt says so.
  final bool concurrentChange;

  /// Whether the sync changed or took off rows that were already on the
  /// list, rather than only adding.
  bool get updatedList => removedItems.isNotEmpty || changedItems.isNotEmpty;

  int get itemCount => addedItemIds.length;
}

/// P6-U02: computes a merge. Pure: nothing is read or written.
class MenuShoppingMergePlanner {
  const MenuShoppingMergePlanner._();

  /// Merge order: duplicates are merged, units
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
    final pass = againstPantry(
      aggregation.items,
      subtract ? pantry.items : const [],
    );

    return MenuShoppingMergePreview(
      source: source,
      options: options,
      lines: pass.lines,
      rawRowCount: aggregation.rawRowCount,
      mergedCount: aggregation.mergedCount,
      convertedCount: aggregation.convertedCount,
      atHomeCount: pass.atHomeCount,
      coveredAtHome: pass.coveredAtHome,
      pantryUnavailable: options.subtractPantry && pantry.unavailable,
    );
  }

  /// [rows] against [pantry], matched by [IngredientIdentity.sameItem].
  /// Enough at home leaves a row off, some at home leaves the difference,
  /// and a unit that cannot be converted or a date passed subtracts nothing
  /// and marks the row. The week and the recipe button both count this way.
  static MenuShoppingPantryPass againstPantry(
    List<AggregatedShoppingItem> rows,
    List<PantryItem> pantry,
  ) {
    final pantryKeys = [
      for (final item in pantry)
        (item: item, key: IngredientIdentity.nameKey(item.ingredientName)),
    ];

    final lines = <MenuShoppingMergeLine>[];
    final covered = <String>[];
    final lessened = <String>[];
    var atHome = 0;
    for (final row in rows) {
      // [IngredientIdentity.sameItem], with the pantry's keys computed once.
      final key = IngredientIdentity.nameKey(row.name);
      final id = row.ingredientId;
      final matches = [
        for (final p in pantryKeys)
          if (p.key == key || (id != null && p.item.ingredientId == id)) p.item,
      ];
      if (matches.isEmpty) {
        lines.add(_line(row, row.amount));
        continue;
      }
      atHome++;
      switch (_deduct(row, matches)) {
        case _Covered():
          covered.add(row.name);
        case _Remaining(:final amount):
          lessened.add(row.name);
          lines.add(_line(row, amount));
        case _Marked(:final mark):
          lines.add(_line(row, row.amount, mark: mark));
      }
    }
    return MenuShoppingPantryPass(
      lines: List.unmodifiable(lines),
      coveredAtHome: List.unmodifiable(covered),
      lessened: List.unmodifiable(lessened),
      atHomeCount: atHome,
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
    recipeCount: row.recipeCount,
    mark: mark,
    extraAmounts: row.extraAmounts,
    ingredientId: row.ingredientId,
  );

  static _Deduction _deduct(AggregatedShoppingItem row, List<PantryItem> at) {
    if (at.any((p) => p.expiryStatus == PantryExpiryStatus.expired)) {
      return const _Marked(MenuShoppingPantryMark.checkDate);
    }
    // BUT-2304: several amounts in unconvertible units cannot be deducted in
    // one unit.
    if (row.extraAmounts.isNotEmpty) {
      return const _Marked(MenuShoppingPantryMark.maybeAtHome);
    }
    final need = row.amount;
    // A row without an amount ("salt") is covered by any stock in date
    // (Malin 2026-10-31).
    if (need == null || need <= 0) return const _Covered();
    final needBase = SmartUnitConverter.toCanonicalBase(need, row.unit);
    var have = 0.0;
    for (final item in at) {
      final quantity = item.quantity;
      if (quantity == null) {
        return const _Marked(MenuShoppingPantryMark.maybeAtHome);
      }
      final unit = UnitDefinitions.canonical(item.unit);
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
