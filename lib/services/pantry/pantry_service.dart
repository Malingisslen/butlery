import 'package:clock/clock.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/pantry/pantry_previous_version.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/repositories/interfaces/pantry_repository.dart';
import 'package:butlery/services/ingredient_match_service.dart';
import 'package:butlery/services/ingredients/ingredient_identity.dart';
import 'package:butlery/services/pantry/cooked_pantry_plan.dart';

/// Business logic layer for the pantry ("skafferi") feature.
class PantryService extends BaseService {
  final PantryRepository _pantryRepository;
  final IngredientRepository _ingredientRepository;
  final IngredientMatchService _matchService;

  PantryService({
    required PantryRepository pantryRepository,
    required IngredientRepository ingredientRepository,
    required IngredientMatchService matchService,
  }) : _pantryRepository = pantryRepository,
       _ingredientRepository = ingredientRepository,
       _matchService = matchService;

  @override
  String get serviceName => 'PantryService';

  Future<PantryItem> addFromIngredient(
    String userId,
    IngredientData ingredient, {
    double? quantity = 1,
    String? unit,
    PantryLocation? location,
    DateTime? expiryDate,
    String? note,
  }) async {
    final result = await executeServiceOperation<PantryItem>(
      () async {
        _validateInput(ingredient.swedish, quantity);
        final item = _buildItem(
          ingredientId: ingredient.id,
          name: ingredient.swedish,
          quantity: quantity,
          unit: unit ?? ingredient.typicalUnit,
          typicalStorage: ingredient.typicalStorage,
          location: location,
          expiryDate: expiryDate,
          note: note,
        );
        final id = await _pantryRepository.add(userId, item);
        return item.copyWith(id: id);
      },
      operationName: 'addFromIngredient',
    );
    if (result == null) {
      throw StateError('addFromIngredient failed');
    }
    return result;
  }

  /// Adds a pantry item from free-text input, fuzzy-matched against the
  /// ingredient database. Orphan items (no match) store the raw text.
  Future<PantryItem> addFromText(
    String userId,
    String rawText, {
    double? quantity = 1,
    String? unit,
    PantryLocation? location,
    DateTime? expiryDate,
    String? note,
  }) async {
    final result = await executeServiceOperation<PantryItem>(
      () async {
        final trimmed = rawText.trim();
        _validateInput(trimmed, quantity);

        final matches = await _ingredientRepository.searchIngredients(
          trimmed,
          limit: 1,
        );
        // The search's first hit can be another product ("mjöl" finds
        // "mjölk"), so it is linked, and its name used, only when it names
        // what was typed (k08).
        final hit = matches.isNotEmpty ? matches.first : null;
        final match = hit != null && _names(hit, trimmed) ? hit : null;

        final item = _buildItem(
          ingredientId: match?.id,
          name: match?.swedish ?? trimmed,
          quantity: quantity,
          unit: unit ?? match?.typicalUnit,
          typicalStorage: match?.typicalStorage,
          location: location,
          expiryDate: expiryDate,
          note: note,
        );
        final id = await _pantryRepository.add(userId, item);
        return item.copyWith(id: id);
      },
      operationName: 'addFromText',
    );
    if (result == null) {
      throw StateError('addFromText failed');
    }
    return result;
  }

  static bool _names(IngredientData ingredient, String typed) => [
    ingredient.swedish,
    ...ingredient.aliasesSv,
    ...ingredient.learnedAliasesSv,
  ].any((name) => IngredientIdentity.same(name, typed));

  /// BUT-991: hook for the shopping-checkoff → pantry flow.
  ///
  /// Delegates to [addFromText] because [UnifiedShoppingItem] doesn't
  /// carry an `ingredientId` link — the fuzzy match against the
  /// ingredient DB picks up canonical matches and falls back to raw
  /// text for orphans (same shape as a user typing the pantry add box
  /// manually).
  ///
  /// Caller is the shopping-checkoff flow OR a settings-gated
  /// "auto-add to pantry" toggle. This service-level helper makes no
  /// policy decisions — it always adds. Settings-gating + dedup live
  /// at the caller, where the user's preference is known.
  Future<PantryItem> addFromShoppingItem(
    String userId,
    UnifiedShoppingItem item, {
    PantryLocation? location,
    String? note,
  }) {
    // A row bought without an amount ("salt") goes in as "har hemma".
    final known = item.amount > 0;
    return addFromText(
      userId,
      item.name,
      quantity: known ? item.amount : null,
      unit: known ? item.unit : null,
      location: location,
      note: note,
    );
  }

  /// Saves an edited item, writing only the fields that differ from
  /// [previous]. Without [previous] every
  /// editable field is written, but a missing amount still never wipes a
  /// known one.
  ///
  /// With [previous], the values it replaces are kept for Återställ
  /// (BUT-2140) and returned; without it there is nothing to keep, and the
  /// result is null, as it is when nothing was written.
  Future<PantryPreviousVersion?> updateItem(
    String userId,
    PantryItem item, {
    PantryItem? previous,
  }) async {
    _validateInput(item.ingredientName, item.quantity);
    final changes = previous == null
        ? item.editableFields()
        : item.changesFrom(previous);
    if (changes.isEmpty) return null;
    final written = await executeServiceOperation<bool>(
      () async {
        await _pantryRepository.updateFields(
          userId,
          item.id,
          changes,
          before: previous,
        );
        return true;
      },
      operationName: 'updateItem',
      defaultValue: false,
    );
    // A refused write must not look saved: the row would come back on the
    // next load.
    if (written != true) throw StateError('updateItem failed');
    if (previous == null) return null;
    return PantryPreviousVersion(
      fields: previous.storedValues(changes.keys),
      at: clock.now(),
    );
  }

  /// Återställ (BUT-2140): puts [item]'s previous values back and keeps the
  /// values they replace as the new previous version, in one update, so the
  /// restore can itself be restored. Returns the item as it is now stored.
  Future<PantryItem> restorePrevious(String userId, PantryItem item) async {
    final restored = item.withPreviousRestored(clock.now());
    final kept = item.previous;
    if (restored == null || kept == null || kept.fields.isEmpty) {
      throw StateError('restorePrevious: no previous version');
    }
    final written = await executeServiceOperation<bool>(
      () async {
        await _pantryRepository.updateFields(
          userId,
          item.id,
          kept.restoreChanges,
          before: item,
        );
        return true;
      },
      operationName: 'restorePrevious',
    );
    if (written != true) {
      throw StateError('restorePrevious failed');
    }
    return restored.copyWith(updatedBy: userId);
  }

  /// Changes a known amount by [delta] — a relative change, never a new
  /// total. An item without an amount ("har hemma")
  /// has nothing to count from, so it is left as it is. Returns whether the
  /// change was written; false also for a zero [delta] and a failed write.
  Future<bool> adjustQuantity(
    String userId,
    PantryItem item,
    double delta,
  ) async {
    if (item.quantity == null || delta == 0) return false;
    final written = await executeServiceOperation<bool>(
      () async {
        await _pantryRepository.adjustQuantity(userId, item.id, delta);
        return true;
      },
      operationName: 'adjustQuantity',
      defaultValue: false,
    );
    return written ?? false;
  }

  /// Q5-02 = A (produktbeslut 2026-09-24): a row without an amount ("har
  /// hemma") takes a bought [amount] in [unit]. The amount is sent as a
  /// relative change: the store's increment starts a
  /// missing amount at the delta, so two purchases that land on the same
  /// row at once add up instead of one overwriting the other. The unit is
  /// written first; if the amount then fails, the row is still "har hemma".
  /// Returns whether both were written; false for a zero or negative
  /// [amount], a row that already has an amount, and a failed write.
  Future<bool> fillUnknownQuantity(
    String userId,
    PantryItem item,
    double amount,
    String unit,
  ) async {
    if (item.quantity != null || amount <= 0) return false;
    final written = await executeServiceOperation<bool>(
      () async {
        if (item.unit != unit) {
          await _pantryRepository.updateFields(userId, item.id, {
            'unit': unit,
          });
        }
        await _pantryRepository.adjustQuantity(userId, item.id, amount);
        return true;
      },
      operationName: 'fillUnknownQuantity',
      defaultValue: false,
    );
    return written ?? false;
  }

  /// Kärnflöde steg 9C: takes what a cooked recipe used out of the pantry.
  /// A take that empties its row removes the row. A refused write stops the
  /// pass and throws [CookedPantryTakeFailed], which carries the takes
  /// already written so Ångra can still put them back.
  Future<List<CookedPantryTake>> takeCooked(
    String userId,
    List<CookedPantryTake> takes,
  ) async {
    final written = <CookedPantryTake>[];
    for (final take in takes) {
      try {
        if (take.emptiesRow) {
          await _pantryRepository.remove(userId, take.item.id);
        } else {
          await _pantryRepository.adjustQuantity(
            userId,
            take.item.id,
            -take.amount,
          );
        }
      } catch (e) {
        throw CookedPantryTakeFailed(List.unmodifiable(written), e);
      }
      written.add(take);
    }
    return List.unmodifiable(written);
  }

  /// Ångra for [takeCooked]: a removed row is written back whole, under its
  /// own id, and a lessened row gets its amount back as a relative change,
  /// so a purchase checked off meanwhile is kept.
  Future<void> undoTakeCooked(
    String userId,
    List<CookedPantryTake> written,
  ) async {
    for (final take in written) {
      if (take.emptiesRow) {
        await _pantryRepository.add(userId, take.item);
      } else {
        await _pantryRepository.adjustQuantity(
          userId,
          take.item.id,
          take.amount,
        );
      }
    }
  }

  /// Throws when the delete is refused, so the row is not dropped from the
  /// screen while it stays stored. A delete left queued offline returns.
  Future<void> removeItem(String userId, String itemId) =>
      _pantryRepository.remove(userId, itemId);

  /// BUT-954: re-persists a just-removed item for the snackbar-undo flow.
  /// Returns the restored item.
  Future<PantryItem> restoreItem(String userId, PantryItem item) async {
    _validateInput(item.ingredientName, item.quantity);
    final id = await executeServiceOperation<String>(
      () => _pantryRepository.add(userId, item),
      operationName: 'restoreItem',
    );
    if (id == null) {
      throw StateError('restoreItem failed');
    }
    return item.copyWith(id: id);
  }

  /// Throws when the pantry cannot be read: an empty list would show as an
  /// empty pantry, and a check-off would add a row that is already there.
  Future<List<PantryItem>> getAll(String userId) =>
      _pantryRepository.getAll(userId);

  Stream<List<PantryItem>> watchAll(String userId) {
    return _pantryRepository.watchAll(userId);
  }

  /// Scores [recipes] by pantry ingredient coverage. Recipes without
  /// `ingredientsNormalized` are skipped (pre-MODUL1 legacy). Callers
  /// holding a fresh pantry snapshot can pass it via [pantryItems] to
  /// avoid a duplicate Firestore read.
  ///
  /// Delegates matching to [IngredientMatchService] for reuse by
  /// ingredient search and other features.
  Future<List<({Recipe recipe, double matchPercent})>> getMatchingRecipes(
    String userId,
    List<Recipe> recipes, {
    List<PantryItem>? pantryItems,
  }) async {
    final result =
        await executeServiceOperation<
          List<({Recipe recipe, double matchPercent})>
        >(
          () async {
            final items = pantryItems ?? await _pantryRepository.getAll(userId);
            if (items.isEmpty) return const [];

            final pantryIngredientIds = {
              ...items.map((item) => item.ingredientId).whereType<String>(),
              ...await _matchService.keysForNames([
                for (final item in items)
                  if (item.ingredientId == null) item.ingredientName,
              ]),
            };
            if (pantryIngredientIds.isEmpty) return const [];

            final matchResults = await _matchService.matchRecipes(
              selectedIngredientIds: pantryIngredientIds,
              recipes: recipes,
            );

            return matchResults
                .map((r) => (recipe: r.recipe, matchPercent: r.matchPercent))
                .toList();
          },
          operationName: 'getMatchingRecipes',
          defaultValue: const [],
        );
    return result ?? const [];
  }

  /// A null [quantity] is "har hemma" without an amount and is valid.
  void _validateInput(String name, double? quantity) {
    if (name.trim().isEmpty) {
      throw ValidationException(
        'Ingredient name cannot be empty',
        field: 'ingredientName',
      );
    }
    if (quantity != null && quantity <= 0) {
      throw ValidationException(
        'Quantity must be positive',
        field: 'quantity',
        value: quantity,
      );
    }
  }

  PantryItem _buildItem({
    String? ingredientId,
    required String name,
    required double? quantity,
    String? unit,
    String? typicalStorage,
    PantryLocation? location,
    DateTime? expiryDate,
    String? note,
  }) {
    return PantryItem(
      id: '',
      ingredientId: ingredientId,
      ingredientName: name,
      quantity: quantity,
      unit: unit ?? 'st',
      location: location ?? PantryLocation.fromTypicalStorage(typicalStorage),
      addedAt: clock.now().toUtc(),
      expiryDate: expiryDate,
      note: note,
    );
  }
}
