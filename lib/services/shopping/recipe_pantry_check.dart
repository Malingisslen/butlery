// lib/services/shopping/recipe_pantry_check.dart
//
// Q4-03 = A (produktbeslut 2026-09-24): the recipe's add-to-shopping-list
// button says "Lägg {n} varor i inköpslistan", counting the ingredients the
// pantry does not already cover (content-style-guide.md:76). The count and
// what the button then adds come from one computation, so they always agree.

import 'dart:async';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/shopping/menu_shopping_merge.dart';

/// Q4-03: what of a recipe's shopping items still has to be bought.
class RecipePantryCheck {
  const RecipePantryCheck._();

  /// [items] less what [pantry] covers, by the week merge's rule
  /// ([MenuShoppingMergePlanner.toBuy], produktregler.md:224-234): enough at
  /// home leaves an item off, some at home leaves the difference, and an
  /// unknown amount, another unit family or a date passed subtracts
  /// nothing. The order of [items] is kept.
  static List<UnifiedShoppingItem> toBuy(
    List<UnifiedShoppingItem> items,
    List<PantryItem> pantry,
  ) {
    if (pantry.isEmpty) return items;
    final result = <UnifiedShoppingItem>[];
    for (final item in items) {
      final left = MenuShoppingMergePlanner.toBuy(
        name: item.name,
        amount: item.amount,
        unit: item.unit,
        pantry: pantry,
      );
      if (left.covered) continue;
      final amount = left.amount;
      result.add(
        amount == null || amount == item.amount
            ? item
            : item.copyWith(amount: amount),
      );
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
