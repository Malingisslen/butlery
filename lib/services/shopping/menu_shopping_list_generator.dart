// lib/services/shopping/menu_shopping_list_generator.dart

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
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

  const MenuShoppingGenerationResult({
    required this.listId,
    required this.listName,
    required this.itemCount,
    required this.recipeCount,
    required this.unresolvedRecipes,
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

/// BUT-956: generates ("Generera inköpslista") a shopping list from the
/// weekly menu plan. Deterministic, zero LLM.
///
/// V1 contract:
/// - One generated list per ISO week, named "Inköpslista v.NN" — regenerating
///   the same week UPDATES that list instead of duplicating it (idempotent).
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

        final aggregated = MenuShoppingAggregator.aggregate(recipes);
        final listName = 'Inköpslista v.${IsoWeekUtils.isoWeekNumber(date)}';

        // Idempotency: reuse this week's generated list when it exists.
        final existing = shoppingService.personalLists
            .where((l) => l.name == listName)
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
        final updated = await shoppingService.updateList(
          list.copyWith(items: items),
        );
        if (!updated) {
          throw StateError('Could not write items to "$listName"');
        }

        return MenuShoppingGenerationResult(
          listId: listId,
          listName: listName,
          itemCount: items.length,
          recipeCount: recipes.length,
          unresolvedRecipes: unresolved,
        );
      },
      operationName: 'generateForWeek',
    );
  }
}
