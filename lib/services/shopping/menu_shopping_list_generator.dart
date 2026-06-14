// lib/services/shopping/menu_shopping_list_generator.dart

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
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

  const MenuShoppingGenerationResult({
    required this.listId,
    required this.listName,
    required this.itemCount,
    required this.recipeCount,
    required this.unresolvedRecipes,
    this.excludedStaples = 0,
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

        final plan = await menuService.getWeek(date);
        final recipeIds = plan.entries.map((e) => e.recipeId).toSet().toList();
        if (recipeIds.isEmpty) {
          return MenuShoppingGenerationResult.nothingToGenerate;
        }

        final recipes =
            recipeIds.map(recipeService.getRecipeById).nonNulls.toList();
        final unresolved = recipeIds.length - recipes.length;
        if (unresolved > 0) {
          AppLogger.warning(
            '$serviceName: $unresolved of ${recipeIds.length} menu recipes '
            'could not be resolved — list generated from the rest',
          );
        }
        if (recipes.isEmpty) {
          return MenuShoppingGenerationResult.nothingToGenerate;
        }

        // BUT-1279: keep pantry staples (salt, olja, …) off the generated
        // list. Resolve the user's flagged staples and exclude any aggregated
        // line whose normalized name matches one. The count is surfaced so the
        // UI can explain the omission instead of the list silently shrinking.
        final stapleNames = await _stapleNames();
        final aggregated = MenuShoppingAggregator.aggregate(
          recipes,
          excludeNames: stapleNames,
        );
        final excludedStaples = stapleNames.isEmpty
            ? 0
            : MenuShoppingAggregator.aggregate(recipes)
                .where((line) => stapleNames
                    .contains(SwedishCharacterNormalizer.normalize(line.name)))
                .length;
        final weekKey = IsoWeekUtils.weekKeyOf(date);
        final listName = AppLocale.current
            .menuGeneratedShoppingListName(IsoWeekUtils.isoWeekNumber(date));

        // Idempotency: reuse this week's generated list when it exists.
        // Lookup is by the generatedForWeek marker, never by name — a
        // renamed generated list still regenerates in place, and a user
        // list that happens to carry the generated name is left alone.
        final existing = shoppingService.personalLists
            .where((l) => l.generatedForWeek == weekKey)
            .toList();
        String listId;
        if (existing.isNotEmpty) {
          listId = existing.first.id;
        } else {
          final created = await shoppingService.createPersonalList(listName);
          if (created == null) {
            throw StateError('Could not create shopping list "$listName"');
          }
          listId = created;
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
            .map((a) => UnifiedShoppingItem(
                  name: a.name,
                  // Amount-less lines (raw-only/ranges) follow the manual-add
                  // default of 1 rather than rendering a misleading "0".
                  amount: a.amount ?? 1,
                  unit: a.unit,
                  category: a.category,
                  bought: previous[boughtKey(a.name, a.unit)] ?? false,
                ))
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

        return MenuShoppingGenerationResult(
          listId: listId,
          listName: list.name,
          itemCount: items.length,
          recipeCount: recipes.length,
          unresolvedRecipes: unresolved,
          excludedStaples: excludedStaples,
        );
      },
      operationName: 'generateForWeek',
    );
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
