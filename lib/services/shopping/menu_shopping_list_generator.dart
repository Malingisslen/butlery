// lib/services/shopping/menu_shopping_list_generator.dart

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/shopping/menu_shopping_aggregator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/utils/text/swedish_character_normalizer.dart';

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

  /// BUT-1279: how many aggregated lines were dropped because they matched a
  /// pantry staple. Surfaced so the UI can reassure the user ("3 skafferivaror
  /// utelämnade") rather than silently shrinking the list.
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

  /// Re-entrancy sentinel: a generation is already in flight. Distinct from
  /// `null` (= FAILED) so a double-tap is rendered as silence, not an error
  /// snackbar. Compare with [identical] — field-wise it looks like
  /// [nothingToGenerate].
  static const alreadyRunning = MenuShoppingGenerationResult(
    listId: '',
    listName: '',
    itemCount: 0,
    recipeCount: 0,
    unresolvedRecipes: 0,
  );

  bool get isEmptyPlan => listId.isEmpty;
}

/// BUT-956: generates ("Generera inköpslista") a shopping list from the
/// weekly menu plan. Deterministic, zero LLM.
///
/// Contract (BUT-956 + BUT-1234):
/// - One generated list per ISO week, identified by the `generatedForWeek`
///   marker (e.g. "2026-W24") — NOT by name. Regenerating the same week
///   UPDATES the marked list in place (idempotent), even if the user renamed
///   it. A user list that merely shares the generated name but lacks the
///   marker is never touched — a new marked list is created alongside it
///   (the name collision is acceptable).
/// - On regeneration the list's content is replaced by the fresh aggregation,
///   but bought-status survives for lines whose name+unit key still matches.
///   The generated list is OWNED by the generator: manual additions to it do
///   not survive regeneration (use any other list for manual items).
class MenuShoppingListGenerator extends BaseService {
  @override
  String get serviceName => 'MenuShoppingListGenerator';

  Future<MenuShoppingGenerationResult?> generateForWeek(DateTime date) async {
    return executeServiceOperation<MenuShoppingGenerationResult?>(
      () async {
        final menuService = ServiceLocator.get<WeeklyMenuPlanService>();
        final recipeService = ServiceLocator.get<UnifiedRecipeService>();
        final shoppingService = ServiceLocator.get<UnifiedShoppingService>();

        // BUT-1962: `getWeek` answers a failed read with an empty plan, which
        // the branch below reported as `nothingToGenerate` — "your week has no
        // meals" for a week we simply never read.
        final read = await menuService.readWeek(date);
        if (read.readFailed) {
          throw StateError(
            'Refusing to generate a shopping list: the week could not be read',
          );
        }
        final plan = read.plan;
        if (plan.entries.isEmpty) {
          return MenuShoppingGenerationResult.nothingToGenerate;
        }

        // BUT-1613: resolve each DISTINCT recipe once (no repeat lookups), but
        // scale + aggregate PER PLACEMENT. The same recipe planned at two
        // (day, slot) cells contributes its ingredients twice — each scaled to
        // that meal's present count — instead of the old week-level dedup that
        // collapsed repeats into one line and under-bought.
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
        if (recipeById.isEmpty) {
          return MenuShoppingGenerationResult.nothingToGenerate;
        }

        // One scaled placement per plan entry, in plan order.
        var scaledMeals = 0;
        final placements = <ScaledRecipe>[];
        for (final entry in plan.entries) {
          final recipe = recipeById[entry.recipeId];
          if (recipe == null) continue; // unresolved — already counted above
          final factor = _presenceFactor(plan, entry, recipe);
          if (factor != 1.0) scaledMeals++;
          placements.add((recipe: recipe, factor: factor));
        }

        // BUT-1279: keep pantry staples (salt, olja, …) off the generated
        // list. Now that aggregation scales per placement, run it ONCE (no
        // exclusion) and split the result into kept vs staple-matched lines —
        // the excludedStaples count comes from the same pass rather than a
        // second full aggregation.
        final stapleNames = await _stapleNames();
        final fullAggregation = MenuShoppingAggregator.aggregate(placements);
        bool isStaple(AggregatedShoppingItem line) => stapleNames.contains(
          SwedishCharacterNormalizer.normalize(line.name),
        );
        final excludedStaples = stapleNames.isEmpty
            ? 0
            : fullAggregation.where(isStaple).length;
        final aggregated = stapleNames.isEmpty
            ? fullAggregation
            : fullAggregation.where((line) => !isStaple(line)).toList();
        final weekKey = IsoWeekUtils.weekKeyOf(date);
        final listName = AppLocale.current.menuGeneratedShoppingListName(
          IsoWeekUtils.isoWeekNumber(date),
        );

        // Idempotency: reuse this week's generated list when it exists.
        // Lookup is by the generatedForWeek marker, never by name — a
        // renamed generated list still regenerates in place, and a user
        // list that happens to carry the generated name is left alone.
        final existing = shoppingService.personalLists
            .where((l) => l.generatedForWeek == weekKey)
            .toList();
        String listId;
        var wasCreated = false;
        if (existing.isNotEmpty) {
          listId = existing.first.id;
        } else {
          final created = await shoppingService.createPersonalList(listName);
          if (created == null) {
            throw StateError('Could not create shopping list "$listName"');
          }
          listId = created;
          wasCreated = true;
        }

        // Preserve bought-status across regeneration. The key uses the SAME
        // normalization as the aggregation key — display casing can flip
        // between runs (first-seen wins), so a plain toLowerCase key would
        // silently reset bought-status exactly in the regeneration scenario
        // it exists for.
        String boughtKey(String name, String unit) =>
            '${SwedishCharacterNormalizer.normalize(name)}|'
            '${unit.toLowerCase().trim()}';
        final previous = existing.isNotEmpty
            ? {
                for (final item in existing.first.items)
                  boughtKey(item.name, item.unit): item.bought,
              }
            : const <String, bool>{};

        final items = aggregated
            .map(
              (a) => UnifiedShoppingItem(
                name: a.name,
                // Amount-less lines (raw-only/ranges) follow the manual-add
                // default of 1 rather than rendering a misleading "0".
                amount: a.amount ?? 1,
                unit: a.unit,
                category: a.category,
                bought: previous[boughtKey(a.name, a.unit)] ?? false,
              ),
            )
            .toList();

        final list = shoppingService.lists.firstWhere((l) => l.id == listId);
        // Stamp the marker on every write: it tags freshly created lists and
        // is a no-op re-stamp on reused ones (already carrying this weekKey).
        final updated = await shoppingService.updateList(
          list.copyWith(items: items, generatedForWeek: weekKey),
        );
        // `list` was fetched by id above, so its name is the one the user
        // actually sees (a reused list may have been renamed) — error and
        // snackbar must echo it.
        if (!updated) {
          throw StateError('Could not write items to "${list.name}"');
        }

        // BUT-1681: EXACTLY ONE analytics event per generation, and only for a
        // genuine creation.
        //
        // The reverted first attempt fired `shopping_list_item_added` per
        // generated line and re-fired the whole set on every regeneration —
        // ~250 events for one 50-item week, inflating the very funnel the
        // event exists to build. `initial_item_count` carries the volume, so
        // the per-line events bought nothing the summary doesn't. Weekly
        // regeneration of the same list is not a new list and stays silent.
        if (wasCreated) {
          ServiceLocator.tryGet<AnalyticsService>()?.shopping
              .logShoppingListCreated(
                listId: listId,
                listType: 'personal',
                initialItemCount: items.length,
                source: 'menu_generated',
              );
        }

        return MenuShoppingGenerationResult(
          listId: listId,
          listName: list.name,
          itemCount: items.length,
          recipeCount: recipeById.length,
          unresolvedRecipes: unresolved,
          excludedStaples: excludedStaples,
          scaledMeals: scaledMeals,
        );
      },
      operationName: 'generateForWeek',
    );
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

  /// BUT-1279: normalized names of the current user's pantry staples, for
  /// shopping-list exclusion. Returns an empty set (exclude nothing) when the
  /// user is unauthenticated, has no staples, or the pantry read fails — the
  /// list generation must never break just because staples can't be read.
  Future<Set<String>> _stapleNames() async {
    try {
      final userId = ServiceLocator.get<AuthRepository>().currentUserId;
      if (userId == null) return const {};
      final items = await ServiceLocator.get<PantryService>().getAll(userId);
      return {
        for (final item in items)
          if (item.isStaple)
            SwedishCharacterNormalizer.normalize(item.ingredientName),
      };
    } catch (e) {
      // Staple exclusion is a best-effort enhancement — a missing/failing
      // pantry must never block the user's shopping list. Degrade to "exclude
      // nothing" and log for observability.
      AppLogger.warning(
        '$serviceName: could not resolve pantry staples — generating without '
        'staple exclusion ($e)',
      );
      return const {};
    }
  }
}
