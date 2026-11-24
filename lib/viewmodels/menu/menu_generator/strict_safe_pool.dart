import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

/// The household-safe recipe pool without the dishes that only got in because
/// an allergen status is unknown (BUT-2497): a suggestion is never a guess.
///
/// One place for the pool a suggestion may draw from, so a later change to
/// who the allergen scope covers is made in the generator and reaches this
/// too.
abstract final class StrictSafePool {
  static Future<List<Recipe>> read({
    required MenuService menuService,
    required UnifiedRecipeService recipeService,
    required OwnProfileReader userService,
  }) async {
    final generator = MenuGenerator(
      menuService: menuService,
      recipeService: recipeService,
      userService: userService,
      filterByAllergens: true,
      filterByDietary: true,
    );
    await generator.ensureRecipeServiceInitialized();
    final pool = await generator.getAvailableRecipesAsync();
    final unknownSoft = generator.lastPoolStats?.unknownSoftRecipeIds ?? {};
    return pool.where((r) => !unknownSoft.contains(r.id)).toList();
  }
}
