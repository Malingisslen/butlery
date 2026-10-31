// Kärnflöde steg 9C (Malin 2026-10-31): after a recipe is marked as cooked,
// a sheet offers to take what it used out of the pantry. This file works out
// what to offer; nothing here writes.

import 'package:flutter/foundation.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/ingredients/ingredient_identity.dart';
import 'package:butlery/services/pantry/pantry_unit_factor.dart';
import 'package:butlery/services/shopping/menu_shopping_aggregator.dart';
import 'package:butlery/utils/text/unit_definitions.dart';

/// One pantry row and how much of it, in the row's own unit, a cooked
/// recipe used.
@immutable
class CookedPantryTake {
  const CookedPantryTake({required this.item, required this.amount});

  final PantryItem item;
  final double amount;

  /// What the row holds after the take; at or below zero the row is removed.
  double get left => (item.quantity ?? 0) - amount;

  bool get emptiesRow => left <= _epsilon;

  CookedPantryTake withAmount(double next) =>
      CookedPantryTake(item: item, amount: next);

  static const _epsilon = 1e-9;
}

/// [PantryService.takeCooked] stopped at a refused write.
class CookedPantryTakeFailed implements Exception {
  const CookedPantryTakeFailed(this.written, this.cause);

  /// The takes stored before the refusal.
  final List<CookedPantryTake> written;
  final Object cause;

  @override
  String toString() =>
      'CookedPantryTakeFailed(${written.length} written): $cause';
}

class CookedPantryPlan {
  const CookedPantryPlan._();

  /// What [recipe] at [portions] takes from [pantry], matched and counted as
  /// the shopping list's pantry deduction counts it
  /// ([MenuShoppingMergePlanner.againstPantry]). Only stock that can be
  /// counted is offered: a row past its date, a row without an amount and a
  /// row in a unit that does not convert are left alone. Several rows of one
  /// item are taken from the one closest to its date first.
  static List<CookedPantryTake> of(
    Recipe recipe, {
    required int portions,
    required List<PantryItem> pantry,
  }) {
    final base = recipe.portions ?? 1;
    final factor = base > 0 ? portions / base : 1.0;
    final rows = MenuShoppingAggregator.aggregateForMerge([
      (recipe: recipe, factor: factor),
    ]).items;

    final takes = <CookedPantryTake>[];
    final taken = <String>{};
    for (final row in rows) {
      final need = row.amount;
      if (need == null || need <= 0) continue;
      final key = IngredientIdentity.nameKey(row.name);
      final id = row.ingredientId;
      final stock = [
        for (final item in pantry)
          if (!taken.contains(item.id) &&
              (item.quantity ?? 0) > 0 &&
              item.expiryStatus != PantryExpiryStatus.expired &&
              (IngredientIdentity.nameKey(item.ingredientName) == key ||
                  (id != null && item.ingredientId == id)))
            item,
      ]..sort(_soonestFirst);

      var rest = need;
      for (final item in stock) {
        if (rest <= 0) break;
        final perRowUnit = PantryUnitFactor.unitsOfToPerFrom(
          UnitDefinitions.canonical(item.unit),
          row.unit,
        );
        if (perRowUnit == null) continue;
        final have = item.quantity! * perRowUnit;
        final use = have < rest ? have : rest;
        rest -= use;
        taken.add(item.id);
        takes.add(CookedPantryTake(item: item, amount: use / perRowUnit));
      }
    }
    return List.unmodifiable(takes);
  }

  static int _soonestFirst(PantryItem a, PantryItem b) {
    final x = a.expiryDate;
    final y = b.expiryDate;
    if (x == null && y == null) return 0;
    if (x == null) return 1;
    if (y == null) return -1;
    return x.compareTo(y);
  }
}
