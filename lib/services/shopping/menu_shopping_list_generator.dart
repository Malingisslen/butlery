// lib/services/shopping/menu_shopping_list_generator.dart

import 'dart:async';

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/shopping/menu_shopping_aggregator.dart';
import 'package:butlery/services/shopping/menu_shopping_merge.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';

export 'package:butlery/services/shopping/menu_shopping_merge.dart';

/// Outcome of a week→shopping-list generation, for the snackbar/UI.
///
/// A null return from [MenuShoppingListGenerator.generateForWeek] means
/// FAILURE (swallowed by the service error path) — the no-recipes case is
/// the explicit [MenuShoppingGenerationResult.nothingToGenerate], so the
/// view can show the right message for each.
class MenuShoppingGenerationResult {
  final String listId;
  final String listName;
  final int itemCount;
  final int recipeCount;

  /// Recipe ids on the plan whose Recipe could not be resolved (deleted or
  /// not yet cached). Logged; carried for observability.
  final int unresolvedRecipes;

  /// How many rows the pantry touched: left off because enough is at home,
  /// shortened to the difference, or marked "Kanske hemma" / "Kolla datum"
  /// (produktregler.md:224-234, § 4.2; produktbeslut PQ-11 = A). It replaced
  /// the BUT-1279 count of whole staple rows.
  final int excludedStaples;

  /// BUT-1613: how many planned meals had their quantities scaled to who's
  /// home (present count differs from the recipe's serving count). Surfaced so
  /// the UI can explain why amounts changed instead of the shrink reading as a
  /// bug. 0 = nothing was scaled (list matches authored amounts).
  final int scaledMeals;

  const MenuShoppingGenerationResult({
    required this.listId,
    required this.listName,
    required this.itemCount,
    required this.recipeCount,
    required this.unresolvedRecipes,
    this.excludedStaples = 0,
    this.scaledMeals = 0,
  });

  static const nothingToGenerate = MenuShoppingGenerationResult(
    listId: '',
    listName: '',
    itemCount: 0,
    recipeCount: 0,
    unresolvedRecipes: 0,
  );

  bool get isEmptyPlan => listId.isEmpty;
}

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
/// (flows-roles-budget.md:44-51) and the merge sheet (Skarmar v12 del 2
/// #inkopmerge) are the only way from the week menu to a list, and "Dina
/// egna, manuellt tillagda varor behålls alltid". produktbeslut PQ-10 = A
/// (2026-09-23) settled it: your own rows are always kept, and the rows land
/// in the week's generated list, created when missing. That SUPERSEDES
/// produktregler.md:704 (§ 8.7, "manuella tillägg gör det inte"). Recipe
/// rows are known by their ids ([UnifiedShoppingList.menuItemIds]), never by
/// name. Bought status still survives a replace by name and unit (§ 8.7).
///
/// produktbeslut PQ-11 = A: the pantry subtracts amounts (produktregler.md
/// § 4.2, :224-234), which SUPERSEDES § 8.7's exclusion of whole staple rows
/// (:695).
class MenuShoppingListGenerator extends BaseService {
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
    final merge = preview(
      source,
      pantry,
      const MenuShoppingMergeOptions(replaceList: true),
    );
    final receipt = await apply(merge);
    if (receipt == null) return null;
    return MenuShoppingGenerationResult(
      listId: receipt.listId,
      listName: receipt.listName,
      itemCount: receipt.itemCount,
      recipeCount: source.recipeCount,
      unresolvedRecipes: source.unresolvedRecipes,
      excludedStaples: merge.atHomeCount,
      scaledMeals: source.scaledMeals,
    );
  }

  /// The week's placements, or null when the week could not be read. An
  /// empty source means there is nothing to generate; the two outcomes stay
  /// apart (produktregler.md:705).
  Future<MenuShoppingSource?> sourceForWeek(DateTime date) async {
    return executeServiceOperation<MenuShoppingSource?>(() async {
      final menuService = ServiceLocator.get<WeeklyMenuPlanService>();
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();

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
    );
  }

  /// Reads the signed-in user's pantry. A failed or slow read gives
  /// [MenuShoppingPantry.unavailable]: the list is then made without pantry
  /// deduction, and the sheet says so with a way to try again
  /// (produktregler.md:697). [PantryService.getAll] turns a failure into an
  /// empty pantry, which would hide exactly that, so this reads the stream.
  Future<MenuShoppingPantry> readPantry() async {
    try {
      final userId = ServiceLocator.get<AuthRepository>().currentUserId;
      if (userId == null) return const MenuShoppingPantry.read([]);
      final items = await ServiceLocator.get<PantryService>()
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

  /// Whether "Ersätt listan" can take anything off the week's list. False for
  /// a list written before [UnifiedShoppingList.menuItemIds] existed: its
  /// recipe rows cannot be told from the user's own, so a replace there would
  /// only add. The sheet then switches "Ersätt listan" off and says why.
  bool canReplaceWeekList(DateTime week) {
    final weekKey = IsoWeekUtils.weekKeyOf(week);
    final list = ServiceLocator.get<UnifiedShoppingService>().personalLists
        .where((l) => l.generatedForWeek == weekKey)
        .firstOrNull;
    return list == null || list.menuItemIds != null;
  }

  /// Writes [merge] into the week's generated list, creating it when it is
  /// missing (produktbeslut PQ-10 = A), and makes that list the active one
  /// so the shopping view opens on it. Returns what was written, or null
  /// when nothing could be written.
  ///
  /// Adding never touches a row already on the list. "Ersätt listan" takes
  /// off only the rows an earlier merge put there
  /// ([UnifiedShoppingList.menuItemIds]) and keeps every other row.
  ///
  /// The write replaces the list document in one go. The generated list is
  /// personal (firestore.rules, `unified_shopping_lists` is owner-only), so
  /// no other person can change it at the same time. The same account on a
  /// second device can; merging such writes per operation is BUT-2140.
  Future<MenuShoppingMergeReceipt?> apply(
    MenuShoppingMergePreview merge,
  ) async {
    return executeServiceOperation<MenuShoppingMergeReceipt?>(() async {
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
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

      // The freshest copy the service holds, read right before the write.
      final list = shoppingService.lists.firstWhere((l) => l.id == listId);
      final previousMenuIds = list.menuItemIds;
      final menuIds = (previousMenuIds ?? const <String>[]).toSet();
      // A list written before menuItemIds existed has no known recipe rows,
      // so a replace there adds, and the receipt says it added
      // ([canReplaceWeekList]).
      final replace =
          merge.options.replaceList && (createdList || previousMenuIds != null);
      final removed = replace
          ? list.items.where((item) => menuIds.contains(item.id)).toList()
          : const <UnifiedShoppingItem>[];
      final kept = replace
          ? list.items.where((item) => !menuIds.contains(item.id)).toList()
          : list.items;

      // § 8.7: bought status survives a replace by name and unit, keyed by
      // the same normalization as the aggregation.
      String boughtKey(String name, String unit) =>
          '${SwedishCharacterNormalizer.normalize(name)}|'
          '${unit.toLowerCase().trim()}';
      final wasBought = {
        for (final item in removed)
          boughtKey(item.name, item.unit): item.bought,
      };

      final added = [
        for (final line in merge.lines)
          UnifiedShoppingItem(
            name: line.name,
            // Amount-less lines follow the manual-add default of 1 rather
            // than rendering a misleading "0".
            amount: line.amount ?? 1,
            unit: line.unit,
            category: line.category,
            bought: wasBought[boughtKey(line.name, line.unit)] ?? false,
            note: _noteFor(line),
          ),
      ];
      final addedIds = [for (final item in added) item.id];
      final nextMenuIds = [if (!replace) ...menuIds, ...addedIds];

      final updated = await shoppingService.updateList(
        list.copyWith(
          items: [...kept, ...added],
          generatedForWeek: weekKey,
          menuItemIds: nextMenuIds,
        ),
      );
      // `list` was fetched by id, so its name is the one the user sees (a
      // reused list may have been renamed).
      if (!updated) {
        throw StateError('Could not write items to "${list.name}"');
      }
      await shoppingService.setActiveList(listId);

      // BUT-1681: EXACTLY ONE analytics event per merge, and only for a
      // genuine creation. `initial_item_count` carries the volume.
      if (createdList) {
        ServiceLocator.tryGet<AnalyticsService>()?.shopping
            .logShoppingListCreated(
              listId: listId,
              listType: 'personal',
              initialItemCount: added.length,
              source: 'menu_generated',
            );
      }

      return MenuShoppingMergeReceipt(
        listId: listId,
        listName: list.name,
        addedItemIds: List.unmodifiable(addedIds),
        removedItems: List.unmodifiable(removed),
        previousMenuItemIds: previousMenuIds,
        replaced: replace,
        createdList: createdList,
      );
    }, operationName: 'applyMerge');
  }

  /// Ångra for a merge: takes off exactly the rows it added and puts back the
  /// recipe rows a replace took off. Rows changed or added since are left
  /// alone. A list the merge created that is empty again is deleted. Returns
  /// whether the list is back.
  Future<bool> undo(MenuShoppingMergeReceipt receipt) async {
    final result = await executeServiceOperation<bool>(() async {
      final shoppingService = ServiceLocator.get<UnifiedShoppingService>();
      final list = shoppingService.lists
          .where((l) => l.id == receipt.listId)
          .firstOrNull;
      if (list == null) return false;
      final added = receipt.addedItemIds.toSet();
      final items = [
        ...list.items.where((item) => !added.contains(item.id)),
        ...receipt.removedItems,
      ];
      if (receipt.createdList && items.isEmpty) {
        return shoppingService.deleteList(receipt.listId);
      }
      final restoredIds = receipt.replaced
          ? (receipt.previousMenuItemIds ?? const <String>[])
          : (list.menuItemIds ?? const <String>[])
                .where((id) => !added.contains(id))
                .toList();
      return shoppingService.updateList(
        list.copyWith(items: items, menuItemIds: restoredIds),
      );
    }, operationName: 'undoMerge');
    return result ?? false;
  }

  /// The row's note: how many recipes it came from ("Raden visar '3
  /// recept'", #inkopmergeoppen) and the pantry's mark (§ 4.2).
  static String? _noteFor(MenuShoppingMergeLine line) {
    final l = AppLocale.current;
    final parts = [
      if (line.sourceCount > 1) l.shoppingMergeRowRecipes(line.sourceCount),
      if (line.mark == MenuShoppingPantryMark.maybeAtHome)
        l.shoppingMergeMarkMaybeHome,
      if (line.mark == MenuShoppingPantryMark.checkDate)
        l.shoppingMergeMarkCheckDate,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
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
