// lib/services/shopping/week_list_reconciler.dart

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart'
    show PersonalMergeWrite;
import 'package:butlery/services/ingredients/ingredient_identity.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

/// The two places the week menu writes a week's list from. Both write into
/// the same list, so each only keeps its own rows in step.
enum ShoppingRowOrigin {
  /// The calendar: the week plan, scaled to who is home.
  plan,

  /// The generated menu in list mode, at its authored amounts.
  menu,
}

/// Keeps one source's rows on a week's list in step with that source, so
/// that syncing twice never doubles a row, and the user's own work survives:
/// a row they changed, a row they ticked and a row they typed are never
/// touched.
///
/// Pure: the caller reads the list and writes the plan.
abstract final class WeekListReconciler {
  /// The values a user can see and change on a row. A row whose fingerprint
  /// no longer equals its `generatedAs` was changed after the sync wrote it.
  static String fingerprint(UnifiedShoppingItem item) => [
    _key(item),
    _amount(item.amount),
    item.category,
    item.note.orEmpty(),
  ].join('|');

  /// [fresh] stamped as rows [origin] wrote, ready to compare and store.
  static List<UnifiedShoppingItem> stamp(
    List<UnifiedShoppingItem> fresh,
    ShoppingRowOrigin origin,
  ) => [
    for (final item in fresh)
      item.copyWith(generatedFrom: origin.name, generatedAs: fingerprint(item)),
  ];

  /// [listRows] are the rows the list's `menuItemIds` names; any other row is
  /// the user's own and is not passed in. [fresh] are [origin]'s rows as
  /// [stamp] returns them.
  static PersonalMergeWrite reconcile({
    required List<UnifiedShoppingItem> listRows,
    required List<UnifiedShoppingItem> fresh,
    required ShoppingRowOrigin origin,
  }) {
    final own = <String, List<UnifiedShoppingItem>>{};
    // Rows written before rows carried their origin, from either source.
    final legacy = <String, List<UnifiedShoppingItem>>{};
    for (final row in listRows) {
      if (row.generatedFrom == origin.name) {
        // Known by what it was written as, so a row the user renamed still
        // answers for its ingredient and is not added again beside it.
        (own[_writtenKey(row)] ??= []).add(row);
      } else if (row.generatedFrom == null) {
        (legacy[_key(row)] ??= []).add(row);
      }
    }

    final add = <UnifiedShoppingItem>[];
    final update = <UnifiedShoppingItem>[];
    for (final next in fresh) {
      final key = _key(next);
      final mine = own[key];
      if (mine != null && mine.isNotEmpty) {
        final row = mine.removeAt(0);
        if (isUntouched(row) && !row.bought && _differs(row, next)) {
          update.add(_overwrite(row, next));
        }
        continue;
      }
      final old = legacy[key];
      if (old != null && old.isNotEmpty) {
        final row = old.removeAt(0);
        // Its amount is what the sync would write, so nobody changed it:
        // from now on it is this source's row. Otherwise it is left alone,
        // and no second row is added beside it.
        if (row.amount == next.amount) {
          update.add(
            row.copyWith(
              generatedFrom: origin.name,
              generatedAs: fingerprint(row),
            ),
          );
        }
        continue;
      }
      add.add(next);
    }

    final remove = [
      for (final rows in own.values)
        for (final row in rows)
          if (isUntouched(row) && !row.bought) row,
    ];
    return PersonalMergeWrite(
      add: List.unmodifiable(add),
      update: List.unmodifiable(update),
      remove: List.unmodifiable(remove),
    );
  }

  /// Whether [list] holds a row an earlier sync of [origin] wrote, or with
  /// [orLegacy] a row written before rows carried their origin.
  static bool holdsRowsFrom(
    UnifiedShoppingList list,
    ShoppingRowOrigin origin, {
    bool orLegacy = false,
  }) {
    final menuIds = (list.menuItemIds ?? const <String>[]).toSet();
    return list.items.any(
      (item) =>
          menuIds.contains(item.id) &&
          (item.generatedFrom == origin.name ||
              (orLegacy && item.generatedFrom == null)),
    );
  }

  static String _key(UnifiedShoppingItem item) =>
      '${IngredientIdentity.nameKey(item.name)}|'
      '${UnitDefinitions.canonical(item.unit)}';

  static String _writtenKey(UnifiedShoppingItem row) {
    final written = row.generatedAs;
    if (written == null) return _key(row);
    return written.split('|').take(2).join('|');
  }

  /// Whole amounts without a decimal, so the fingerprint reads the same on
  /// the web, where `2.0.toString()` is "2".
  static String _amount(double amount) =>
      amount == amount.roundToDouble() && amount.isFinite
      ? amount.toInt().toString()
      : amount.toString();

  /// Whether [row] still holds the values the sync wrote: nobody changed it.
  static bool isUntouched(UnifiedShoppingItem row) =>
      row.generatedAs == fingerprint(row);

  static bool _differs(UnifiedShoppingItem row, UnifiedShoppingItem next) =>
      row.generatedAs != next.generatedAs ||
      row.name != next.name ||
      row.unit != next.unit ||
      row.ingredientId != next.ingredientId;

  /// [row] with [next]'s values, keeping its id, tick and history.
  static UnifiedShoppingItem _overwrite(
    UnifiedShoppingItem row,
    UnifiedShoppingItem next,
  ) => row.copyWith(
    name: next.name,
    amount: next.amount,
    unit: next.unit,
    category: next.category,
    note: next.note,
    clearNote: next.note == null,
    ingredientId: next.ingredientId,
    generatedFrom: next.generatedFrom,
    generatedAs: next.generatedAs,
  );
}
