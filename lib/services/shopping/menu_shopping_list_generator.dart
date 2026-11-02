// lib/services/shopping/menu_shopping_list_generator.dart

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/shopping_repository.dart'
    show PersonalMergeRequest;
import 'package:butlery/services/shopping/menu_shopping_aggregator.dart';
import 'package:butlery/services/shopping/menu_shopping_generation_result.dart';
import 'package:butlery/services/shopping/menu_shopping_links.dart';
import 'package:butlery/services/shopping/menu_shopping_merge.dart';
import 'package:butlery/services/shopping/week_list_follow_notice.dart';
import 'package:butlery/services/shopping/week_list_follower.dart';
import 'package:butlery/services/shopping/week_list_reconciler.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';

export 'package:butlery/services/shopping/menu_shopping_generation_result.dart';
export 'package:butlery/services/shopping/menu_shopping_merge.dart';
export 'package:butlery/services/shopping/week_list_follow_notice.dart'
    show WeekListFollowNotice;
export 'package:butlery/services/shopping/week_list_reconciler.dart'
    show ShoppingRowOrigin;

/// BUT-956: generates a shopping list from the weekly menu. Deterministic,
/// zero LLM.
///
/// Contract (BUT-956 + BUT-1234):
/// - One generated list per ISO week, identified by the `generatedForWeek`
///   marker (e.g. "2026-W24") — NOT by name. A renamed generated list still
///   receives the week's rows, and a user list that merely shares the
///   generated name but lacks the marker is never touched.
///
/// P6-U02 changed what happens inside that list. Flow 02
/// and the merge sheet
/// are the only way from the week menu to a list, and "Dina
/// egna, manuellt tillagda varor behålls alltid". produktbeslut PQ-10 = A
/// (2026-09-23) settled it: your own rows are always kept, and the rows land
/// in the week's generated list, created when missing.
/// Recipe
/// rows are known by their ids ([UnifiedShoppingList.menuItemIds]), never by
/// name.
///
/// Kärnflöde 8B: every write is one sync ([WeekListReconciler]), so pressing
/// the button twice never doubles a row, a row the user changed or ticked is
/// left as it is, and the week's list follows later saves of the week
/// ([followMenuSaves]).
class MenuShoppingListGenerator extends BaseService {
  MenuShoppingListGenerator({
    required MenuShoppingLinks links,
    SharedPreferences? preferences,
  }) : _links = links,
       _optionsMemory = MenuShoppingOptionsMemory(preferences),
       _notices = WeekListFollowNoticeStore(preferences);

  final MenuShoppingLinks _links;

  final MenuShoppingOptionsMemory _optionsMemory;
  final WeekListFollowNoticeStore _notices;

  @override
  String get serviceName => 'MenuShoppingListGenerator';

  /// How long a pantry read may take before the merge goes on without it.
  static const Duration pantryReadTimeout = Duration(seconds: 10);

  /// Kept for the onboarding sample week: the week's rows replace the week's
  /// recipe rows, with every other switch at its drawn default.
  Future<MenuShoppingGenerationResult?> generateForWeek(DateTime date) async {
    final source = await sourceForWeek(date);
    if (source == null) return null;
    if (source.isEmpty) return MenuShoppingGenerationResult.nothingToGenerate;
    final pantry = await readPantry();
    final merge = preview(source, pantry, const MenuShoppingMergeOptions());
    final receipt = await apply(merge);
    if (receipt == null) return null;
    return MenuShoppingGenerationResult(
      listId: receipt.listId,
      listName: receipt.listName,
      itemCount: receipt.itemCount,
      recipeCount: source.recipeCount,
      unresolvedRecipes: source.unresolvedRecipes,
      scaledMeals: source.scaledMeals,
    );
  }

  /// The week's placements, or null when the week could not be read. An
  /// empty source means there is nothing to generate; the two outcomes stay
  /// apart.
  Future<MenuShoppingSource?> sourceForWeek(DateTime date) async {
    return executeServiceOperation<MenuShoppingSource?>(() async {
      final menuService = _links.menuPlans();
      final recipeService = _links.recipes();

      // BUT-1962: `getWeek` answers a failed read with an empty plan, which
      // would read as "your week has no meals" for a week we never read.
      final read = await menuService.readWeek(date);
      if (read.readFailed) {
        throw StateError(
          'Refusing to generate a shopping list: the week could not be read',
        );
      }
      final plan = read.plan;
      if (plan.entries.isEmpty) {
        return MenuShoppingSource(
          week: date,
          placements: const [],
          recipeCount: 0,
        );
      }

      // BUT-1613: resolve each DISTINCT recipe once (no repeat lookups), but
      // scale + aggregate PER PLACEMENT. The same recipe planned at two
      // (day, slot) cells contributes its ingredients twice — each scaled to
      // that meal's present count.
      final distinctIds = plan.entries.map((e) => e.recipeId).toSet();
      final recipeById = <String, Recipe>{};
      for (final id in distinctIds) {
        final resolved = recipeService.getRecipeById(id);
        if (resolved != null) recipeById[id] = resolved;
      }
      final unresolved = distinctIds.length - recipeById.length;
      if (unresolved > 0) {
        AppLogger.warning(
          '$serviceName: $unresolved of ${distinctIds.length} menu recipes '
          'could not be resolved — list generated from the rest',
        );
      }

      var scaledMeals = 0;
      final placements = <ScaledRecipe>[];
      for (final entry in plan.entries) {
        final recipe = recipeById[entry.recipeId];
        if (recipe == null) continue; // unresolved — already counted above
        final factor = _presenceFactor(plan, entry, recipe);
        if (factor != 1.0) scaledMeals++;
        placements.add((recipe: recipe, factor: factor));
      }
      return MenuShoppingSource(
        week: date,
        placements: List.unmodifiable(placements),
        recipeCount: recipeById.length,
        unresolvedRecipes: unresolved,
        scaledMeals: scaledMeals,
      );
    }, operationName: 'sourceForWeek');
  }

  /// The generated menu in list mode (not yet placed in a week): each dish
  /// once, at its authored amounts. Its rows land in the list of the week
  /// [week] falls in.
  static MenuShoppingSource sourceForMenu(
    Map<String, List<Recipe>> menu,
    DateTime week,
  ) {
    final placements = <ScaledRecipe>[
      for (final recipes in menu.values)
        for (final recipe in recipes) (recipe: recipe, factor: 1.0),
    ];
    return MenuShoppingSource(
      week: week,
      placements: List.unmodifiable(placements),
      recipeCount: placements.map((p) => p.recipe.id).toSet().length,
      origin: ShoppingRowOrigin.menu,
    );
  }

  /// Reads the signed-in user's pantry. A failed or slow read gives
  /// [MenuShoppingPantry.unavailable]: the list is then made without pantry
  /// deduction, and the sheet says so with a way to try again
  Future<MenuShoppingPantry> readPantry() async {
    try {
      final userId = _links.auth().currentUserId;
      if (userId == null) return const MenuShoppingPantry.read([]);
      final items = await _links
          .pantry()
          .watchAll(userId)
          .first
          .timeout(pantryReadTimeout);
      return MenuShoppingPantry.read(List.unmodifiable(items));
    } catch (e) {
      AppLogger.warning(
        '$serviceName: the pantry could not be read — the list is made '
        'without pantry deduction ($e)',
      );
      return const MenuShoppingPantry.unavailable();
    }
  }

  /// What the sheet will write, computed before anything is written. See
  /// [MenuShoppingMergePlanner.preview].
  static MenuShoppingMergePreview preview(
    MenuShoppingSource source,
    MenuShoppingPantry pantry,
    MenuShoppingMergeOptions options,
  ) => MenuShoppingMergePlanner.preview(source, pantry, options);

  /// Whether the week's list already holds rows from [origin], so the sheet
  /// says it updates them rather than adds. A row written before rows carried
  /// their origin counts, since the sync takes it over.
  bool weekListHasRowsFrom(DateTime week, ShoppingRowOrigin origin) {
    final list = _weekList(week);
    return list != null &&
        WeekListReconciler.holdsRowsFrom(list, origin, orLegacy: true);
  }

  UnifiedShoppingList? _weekList(DateTime week) {
    final weekKey = IsoWeekUtils.weekKeyOf(week);
    return _links
        .shopping()
        .personalLists
        .where((l) => l.generatedForWeek == weekKey)
        .firstOrNull;
  }

  /// Writes [merge] into the week's generated list, creating it when it is
  /// missing (produktbeslut PQ-10 = A), and makes that list the active one
  /// so the shopping view opens on it. Returns what was written, or null
  /// when nothing could be written.
  ///
  /// The write is a sync of [MenuShoppingSource.origin]'s rows
  /// ([WeekListReconciler]): only rows an earlier sync put there
  /// ([UnifiedShoppingList.menuItemIds]) are changed or taken off, and only
  /// while nobody changed or ticked them. [activate] false leaves the active
  /// list as it is, for a sync nobody pressed a button for.
  ///
  /// The generated list is personal (firestore.rules,
  /// `unified_shopping_lists` is owner-only), so no other person can change
  /// it, but the same account on a second device can. The write therefore
  /// goes per operation against the server's copy
  /// ([UnifiedShoppingService.applyPersonalMerge], BUT-2140), and the receipt
  /// says when that copy had changed.
  Future<MenuShoppingMergeReceipt?> apply(
    MenuShoppingMergePreview merge, {
    bool activate = true,
  }) async {
    return executeServiceOperation<MenuShoppingMergeReceipt?>(() async {
      final shoppingService = _links.shopping();
      final date = merge.source.week;
      final weekKey = IsoWeekUtils.weekKeyOf(date);
      final listName = AppLocale.current.menuGeneratedShoppingListName(
        IsoWeekUtils.isoWeekNumber(date),
      );

      // Lookup is by the generatedForWeek marker, never by name.
      final existing = shoppingService.personalLists
          .where((l) => l.generatedForWeek == weekKey)
          .toList();
      String listId;
      var createdList = false;
      if (existing.isNotEmpty) {
        listId = existing.first.id;
      } else {
        final created = await shoppingService.createPersonalList(listName);
        if (created == null) {
          throw StateError('Could not create shopping list "$listName"');
        }
        listId = created;
        createdList = true;
      }

      final list = shoppingService.lists.firstWhere((l) => l.id == listId);
      final previousMenuIds = list.menuItemIds;
      if (activate) unawaited(_optionsMemory.write(merge.options));

      final origin = merge.source.origin;
      final fresh = WeekListReconciler.stamp([
        for (final line in merge.lines)
          shoppingService.categoryPreferences.withUserCategory(line.toItem()),
      ], origin);
      final result = await shoppingService.applyPersonalMerge(
        listId,
        PersonalMergeRequest(
          sync: (listRows) => WeekListReconciler.reconcile(
            listRows: listRows,
            fresh: fresh,
            origin: origin,
          ),
          generatedForWeek: weekKey,
        ),
      );
      if (activate) await shoppingService.setActiveList(listId);
      final addedIds = [for (final item in result.added) item.id];

      // BUT-1681: EXACTLY ONE analytics event per merge, and only for a
      // genuine creation. `initial_item_count` carries the volume.
      if (createdList) {
        _links.analytics()?.shopping.logShoppingListCreated(
          listId: listId,
          listType: 'personal',
          initialItemCount: addedIds.length,
          source: 'menu_generated',
        );
      }

      return MenuShoppingMergeReceipt(
        listId: listId,
        // The server's name: a reused list may have been renamed, here or on
        // another device.
        listName: result.list.name,
        addedItemIds: List.unmodifiable(addedIds),
        removedItems: List.unmodifiable(result.removed),
        changedItems: List.unmodifiable(result.changedFrom),
        previousMenuItemIds: previousMenuIds,
        createdList: createdList,
        concurrentChange: result.concurrentChange,
      );
    }, operationName: 'applyMerge');
  }

  /// Ångra for a merge: takes off exactly the rows it added and puts back the
  /// rows it changed or took off, as they were. Rows changed or added since, here or on
  /// another device, are left alone. A list the merge created that is empty
  /// again is deleted. Returns whether the list is back.
  Future<bool> undo(MenuShoppingMergeReceipt receipt) =>
      _undoOn(receipt.listId, (_) => receipt);

  Future<bool> _undoOn(
    String listId,
    MenuShoppingMergeReceipt Function(UnifiedShoppingList list) receiptFor,
  ) async {
    final result = await executeServiceOperation<bool>(() async {
      final shoppingService = _links.shopping();
      final list = shoppingService.lists
          .where((l) => l.id == listId)
          .firstOrNull;
      if (list == null) return false;
      final receipt = receiptFor(list);
      // Everything the follows wrote was changed or ticked since.
      if (receipt.addedItemIds.isEmpty &&
          receipt.removedItems.isEmpty &&
          receipt.changedItems.isEmpty) {
        return true;
      }
      final added = receipt.addedItemIds.toSet();
      final left =
          list.items.where((item) => !added.contains(item.id)).length +
          receipt.removedItems.length;
      if (receipt.createdList && left == 0) {
        return shoppingService.deleteList(receipt.listId);
      }
      await shoppingService.undoPersonalMerge(
        receipt.listId,
        receipt.addedItemIds,
        [...receipt.removedItems, ...receipt.changedItems],
      );
      return true;
    }, operationName: 'undoMerge');
    return result ?? false;
  }

  WeekListFollower? _follower;

  /// Kärnflöde 8B (i05): once the week menu has been written into a week's
  /// list, the list follows later saves of that week. A burst of edits
  /// becomes one sync ([WeekListFollower.defaultPause]). Called once, where
  /// the menu service is made.
  void followMenuSaves(Stream<DateTime> savedWeeks) {
    _follower ??= WeekListFollower(
      savedWeeks: savedWeeks,
      sync: syncFollowedWeek,
    );
  }

  /// The follow for one saved week. Only a list that already holds rows the
  /// week plan wrote follows it. An emptied week still syncs, so the rows of
  /// the dishes taken off come off too. Null when nothing was written.
  ///
  /// What it wrote is kept for the notice the list shows the next time it is
  /// opened ([takeFollowNotice]).
  Future<MenuShoppingMergeReceipt?> syncFollowedWeek(DateTime week) async {
    final list = _weekList(week);
    if (list == null ||
        !WeekListReconciler.holdsRowsFrom(list, ShoppingRowOrigin.plan)) {
      return null;
    }

    final source = await sourceForWeek(week);
    // A recipe that could not be read (not loaded yet, or deleted) would read
    // as a dish taken off the week, and its rows would come off unasked.
    if (source == null || source.unresolvedRecipes > 0) return null;
    final options = _optionsMemory.read();
    // Read even with the pantry switch off: staples stay off the list.
    final pantry = await readPantry();
    // Without the pantry every covered row, staples included, would come
    // back at full amount, so nothing is written.
    if (pantry.unavailable) return null;
    final receipt = await apply(
      preview(source, pantry, options),
      activate: false,
    );
    // A follow still running at sign-out must not write the user's rows back
    // after the sign-out cleared them.
    if (receipt != null && !_disposed) await _notices.record(receipt);
    return receipt;
  }

  /// What the follows did to [listId] since it was last opened, taken off
  /// the device: a notice is shown once.
  Future<WeekListFollowNotice?> takeFollowNotice(String listId) =>
      _notices.take(listId);

  /// Puts back a notice taken by [takeFollowNotice] that was never shown.
  Future<void> putBackFollowNotice(WeekListFollowNotice notice) async {
    if (!_disposed) await _notices.putBack(notice);
  }

  /// Ångra for [notice]: the rows the follows wrote go back to how they were,
  /// except rows changed or ticked since. Returns whether the list is back.
  Future<bool> undoFollow(WeekListFollowNotice notice) =>
      _undoOn(notice.listId, notice.undoAgainst);

  var _disposed = false;

  @override
  Future<void> onDispose() async {
    _disposed = true;
    await _follower?.dispose();
    _follower = null;
  }

  /// BUT-1613: the presence-derived scale factor for one plan entry. Returns
  /// 1.0 (no scaling — buy/cook the authored amount) when:
  /// - the slot is övrigt (snacks/baking have no presence concept and are eaten
  ///   by the whole household regardless of who's home — the BUT-1611→BUT-1625
  ///   exemption, applied to quantities here rather than candidate scoping);
  /// - the recipe has no usable authored serving count (can't form a ratio —
  ///   the same guard cooking mode uses, BUT-1322); or
  /// - presence is unset/empty, so [WeeklyMenuPlan.servingsFor] falls back to
  ///   the recipe's own portions (→ factor 1.0).
  /// Otherwise factor = present count / authored portions.
  double _presenceFactor(
    WeeklyMenuPlan plan,
    WeeklyMenuPlanEntry entry,
    Recipe recipe,
  ) {
    if (entry.slot.isMulti) return 1.0; // övrigt
    final portions = recipe.portions;
    if (portions == null || portions <= 0) return 1.0;
    final servings = plan.servingsFor(
      entry.day,
      entry.slot,
      fallback: portions,
    );
    return servings / portions;
  }
}
