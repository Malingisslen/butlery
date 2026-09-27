import 'package:collection/collection.dart';

import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/user_service.dart';

/// BUT-1050: the policy seam between shopping-list checkoff and the pantry.
///
/// When a shopping item is checked off (marked bought), this service decides
/// whether it should flow into the pantry. It fires
/// [PantryService.addFromShoppingItem] ONLY on a genuine false→true checkoff
/// AND only when the user has enabled the `autoAddBoughtToPantry` preference. It
/// also owns the dedup decision — an existing pantry item with a matching
/// ingredient name (case-insensitive) and unit has its quantity aggregated
/// instead of a duplicate entry being created.
///
/// Keeping this policy here (rather than in [PantryService.addFromShoppingItem],
/// which stays a pure always-add helper) means the low-level list-state mutation
/// in `ShoppingItemManagementModule.toggleItemBought` doesn't have to grow
/// userId / service / preference dependencies.
class ShoppingCheckoffPantryService {
  ShoppingCheckoffPantryService({
    required PantryService pantryService,
    required UserService userService,
  }) : _pantryService = pantryService,
       _userService = userService;

  final PantryService _pantryService;
  final UserService _userService;

  /// Called when a shopping item's bought-state has just changed.
  ///
  /// [wasBought] is the item's PREVIOUS bought-state. Only a false→true
  /// transition (a fresh check-off) is acted on; re-toggling an already-bought
  /// item, or un-checking, is a no-op. The add is further gated on the user's
  /// auto-add preference being ON.
  Future<void> onItemCheckedOff(
    String userId,
    UnifiedShoppingItem item, {
    required bool wasBought,
  }) async {
    // Only a genuine false→true check-off triggers the pantry flow.
    if (wasBought || !item.bought) return;

    // Gate on the user's opt-in preference (lives on the complete user profile).
    final profile = _userService.currentUserProfile;
    if (profile == null || !profile.autoAddBoughtToPantry) return;

    // Dedup: aggregate into an existing pantry item with the same ingredient
    // name (case-insensitive) + unit, instead of creating a duplicate entry.
    final existing = await _pantryService.getAll(userId);
    final name = item.name.toLowerCase();
    final sameName = existing
        .where((p) => p.ingredientName.toLowerCase() == name)
        .toList();
    final match = sameName.firstWhereOrNull((p) => p.unit == item.unit);

    if (match != null && match.quantity != null) {
      // What was bought is added as a relative change, never as a new total
      // computed here (produktregler.md:146): a tick on another device in
      // the meantime is kept.
      await _pantryService.adjustQuantity(userId, match, item.amount);
      return;
    }

    // A row without an amount ("har hemma", produktregler.md:148) has
    // nothing to add to. Q5-02 = A (produktbeslut 2026-09-24): it takes the
    // bought amount, in the bought unit, since "har hemma" named no unit to
    // keep. Interpretation: that holds for a same-name row in any unit; a
    // row with a known amount in another unit is still a row of its own.
    final unknown =
        match ?? sameName.firstWhereOrNull((p) => p.quantity == null);
    if (unknown != null) {
      // Nothing known was bought: "har hemma" stays as it is.
      if (item.amount <= 0) return;
      await _pantryService.updateItem(
        userId,
        unknown.copyWith(quantity: item.amount, unit: item.unit),
        previous: unknown,
      );
      return;
    }

    await _pantryService.addFromShoppingItem(userId, item);
  }
}
