// lib/services/shopping/recipe_pantry_check.dart
//
// Q4-03 = A (produktbeslut 2026-09-24): the recipe's add-to-shopping-list
// button says "Lägg {n} varor i inköpslistan", counting the ingredients the
// pantry does not already cover (content-style-guide.md:76). The count and
// what the button then adds come from one computation, so they always agree.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/shopping/menu_shopping_aggregator.dart';
import 'package:butlery/services/shopping/menu_shopping_merge.dart';

/// Q4-03: what a recipe's items come to against the pantry.
@immutable
class RecipePantryResult {
  const RecipePantryResult({
    required this.toBuy,
    required this.coveredAtHome,
    required this.lessened,
  });

  /// The items to add. A row the pantry marked carries "Kanske hemma" or
  /// "Kolla datum" in its note, as a week merge row does.
  final List<UnifiedShoppingItem> toBuy;

  /// Names left off because enough is at home ("raden
  /// visas i 'Har hemma'").
  final List<String> coveredAtHome;

  /// Names added with less than the recipe asks for, because some is at
  /// home.
  final List<String> lessened;
}

/// Q4-03: what of a recipe has to be bought.
class RecipePantryCheck {
  const RecipePantryCheck._();

  /// [recipe] at [portions] against [pantry], counted exactly as the week
  /// menu counts its shopping list (kärnflöde steg 8C): the recipe is one
  /// placement for [MenuShoppingAggregator], and its rows go through
  /// [MenuShoppingMergePlanner.againstPantry]. An empty [pantry] subtracts
  /// nothing.
  static RecipePantryResult check(
    Recipe recipe, {
    required int portions,
    List<PantryItem> pantry = const [],
  }) {
    final aggregation = MenuShoppingAggregator.aggregateForMerge([
      (recipe: recipe, factor: _factor(recipe, portions)),
    ]);
    final pass = MenuShoppingMergePlanner.againstPantry(
      aggregation.items,
      pantry,
    );
    return RecipePantryResult(
      toBuy: List.unmodifiable([for (final line in pass.lines) line.toItem()]),
      coveredAtHome: pass.coveredAtHome,
      lessened: pass.lessened,
    );
  }

  /// The amounts follow the portions the recipe shows. A recipe without a
  /// portion count is scaled from 1, as its screen scales it
  /// (`RecipeDetailActions.initializeScaling`), and one stating 0 portions
  /// is not scaled.
  static double _factor(Recipe recipe, int portions) {
    final base = recipe.portions ?? 1;
    return base > 0 ? portions / base : 1.0;
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
