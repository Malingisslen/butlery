// lib/services/shopping/recipe_pantry_check.dart
//
// Q4-03 = A (produktbeslut 2026-09-24): the recipe's add-to-shopping-list
// button says "Lägg {n} varor i inköpslistan", counting the ingredients the
// pantry does not already cover (content-style-guide.md:76). The count and
// what the button then adds come from one computation, so they always agree.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/shopping/menu_shopping_merge.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';
import 'package:butlery/utils/text/unit_converter.dart';

/// Q4-03: what a recipe's items come to against the pantry.
@immutable
class RecipePantryResult {
  const RecipePantryResult({
    required this.toBuy,
    required this.coveredAtHome,
    required this.lessened,
  });

  /// The items to add, in recipe order. A row the pantry marked carries
  /// "Kanske hemma" or "Kolla datum" in its note (produktregler.md:230-232),
  /// as a week merge row does.
  final List<UnifiedShoppingItem> toBuy;

  /// Names left off because enough is at home (produktregler.md:228, "raden
  /// visas i 'Har hemma'").
  final List<String> coveredAtHome;

  /// Names added with less than the recipe asks for, because some is at
  /// home (produktregler.md:229, 233).
  final List<String> lessened;
}

/// Q4-03: what of a recipe's shopping items still has to be bought.
class RecipePantryCheck {
  const RecipePantryCheck._();

  /// [items] against [pantry] by the week merge's rule, in its order
  /// (flows-roles-budget.md:51): duplicates are merged first, units are
  /// converted within one family, then the pantry is subtracted
  /// ([MenuShoppingMergePlanner.toBuy], produktregler.md:224-234). Enough at
  /// home leaves an item off, some at home leaves the difference, and an
  /// unknown amount, a unit that cannot be converted or a date passed
  /// subtracts nothing and marks the row. The order of [items] is kept.
  static RecipePantryResult check(
    List<UnifiedShoppingItem> items,
    List<PantryItem> pantry,
  ) {
    final l = AppLocale.current;
    final toBuy = <UnifiedShoppingItem>[];
    final covered = <String>[];
    final lessened = <String>[];
    for (final group in _merge(items)) {
      final item = group.item;
      final MenuShoppingPantryMark mark;
      double? amount = item.amount;
      if (group.unconvertible) {
        // The same ingredient in units that do not convert: nothing can be
        // subtracted without counting the stock twice (produktregler.md:231).
        final atHome = pantry.any(
          (p) =>
              SwedishCharacterNormalizer.normalize(p.ingredientName) ==
              SwedishCharacterNormalizer.normalize(item.name),
        );
        mark = atHome
            ? MenuShoppingPantryMark.maybeAtHome
            : MenuShoppingPantryMark.none;
      } else {
        final left = MenuShoppingMergePlanner.toBuy(
          name: item.name,
          amount: item.amount,
          unit: item.unit,
          pantry: pantry,
        );
        if (left.covered) {
          covered.add(item.name);
          continue;
        }
        mark = left.mark;
        if (left.amount != null && left.amount != item.amount) {
          amount = left.amount;
          lessened.add(item.name);
        }
      }
      final label = switch (mark) {
        MenuShoppingPantryMark.none => null,
        MenuShoppingPantryMark.maybeAtHome => l.shoppingMergeMarkMaybeHome,
        MenuShoppingPantryMark.checkDate => l.shoppingMergeMarkCheckDate,
      };
      final note = [
        if ((item.note ?? '').isNotEmpty) item.note!,
        ?label,
      ].join(' · ');
      toBuy.add(
        amount == item.amount && note == (item.note ?? '')
            ? item
            : item.copyWith(amount: amount, note: note),
      );
    }
    return RecipePantryResult(
      toBuy: List.unmodifiable(toBuy),
      coveredAtHome: List.unmodifiable(covered),
      lessened: List.unmodifiable(lessened),
    );
  }

  /// The items [check] adds.
  static List<UnifiedShoppingItem> toBuy(
    List<UnifiedShoppingItem> items,
    List<PantryItem> pantry,
  ) => check(items, pantry).toBuy;

  /// A recipe that names one ingredient on two lines ("2 dl mjölk" in the
  /// dough, "1 dl mjölk" in the sauce) needs it once, in total, so the
  /// pantry is counted once against the sum. Rows of one name whose units
  /// convert into one family are joined into the first row's unit; rows
  /// that cannot be joined stay apart and are flagged.
  static List<({UnifiedShoppingItem item, bool unconvertible})> _merge(
    List<UnifiedShoppingItem> items,
  ) {
    final byName = <String, List<UnifiedShoppingItem>>{};
    for (final item in items) {
      byName
          .putIfAbsent(
            SwedishCharacterNormalizer.normalize(item.name),
            () => [],
          )
          .add(item);
    }
    final done = <String>{};
    final result = <({UnifiedShoppingItem item, bool unconvertible})>[];
    for (final item in items) {
      final key = SwedishCharacterNormalizer.normalize(item.name);
      if (!done.add(key)) continue;
      final rows = byName[key]!;
      if (rows.length == 1) {
        result.add((item: item, unconvertible: false));
        continue;
      }
      final unit = item.unit.toLowerCase().trim();
      final base = SmartUnitConverter.toCanonicalBase(item.amount, unit);
      var sum = 0.0;
      var joined = true;
      for (final row in rows) {
        final rowUnit = row.unit.toLowerCase().trim();
        if (rowUnit == unit) {
          sum += row.amount;
          continue;
        }
        final rowBase = SmartUnitConverter.toCanonicalBase(row.amount, rowUnit);
        if (base == null ||
            rowBase == null ||
            base.quantity == 0 ||
            rowBase.baseUnit != base.baseUnit) {
          joined = false;
          break;
        }
        sum += rowBase.quantity * item.amount / base.quantity;
      }
      if (joined) {
        result.add((item: item.copyWith(amount: sum), unconvertible: false));
      } else {
        for (final row in rows) {
          result.add((item: row, unconvertible: true));
        }
      }
    }
    return result;
  }
}

/// Q4-03: follows the signed-in user's pantry for a view that counts
/// against it.
///
/// [pantry] is null while the first read is on its way, when no one is
/// signed in, when the pantry is not available (no service) and after a
/// failed read. The button then says "Lägg i inköpslistan" and adds every
/// ingredient, as before: nothing is left off on a guess.
class RecipePantryWatcher {
  RecipePantryWatcher({required this.onChanged}) {
    _start();
  }

  /// Called when [pantry] changes.
  final void Function() onChanged;

  List<PantryItem>? _pantry;
  StreamSubscription<List<PantryItem>>? _sub;
  bool _disposed = false;

  /// The pantry as last read, or null when it is not known.
  List<PantryItem>? get pantry => _pantry;

  void _start() {
    final service = ServiceLocator.tryGet<PantryService>();
    final userId = ServiceLocator.tryGet<AuthRepository>()?.currentUserId;
    if (service == null || userId == null) return;
    try {
      _sub = service
          .watchAll(userId)
          .listen(
            (items) => _set(List.unmodifiable(items)),
            onError: (Object e) {
              AppLogger.warning(
                'RecipePantryWatcher: the pantry could not be read; the '
                'button counts nothing ($e)',
              );
              _set(null);
            },
          );
    } catch (e) {
      AppLogger.warning('RecipePantryWatcher: no pantry stream ($e)');
    }
  }

  void _set(List<PantryItem>? next) {
    if (_disposed) return;
    _pantry = next;
    onChanged();
  }

  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    _sub = null;
  }
}
