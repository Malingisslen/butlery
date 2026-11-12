import 'package:clock/clock.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/menu/meal_slot_mapper.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/shopping/menu_shopping_list_generator.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

class SampleMenuSeeder {
  final AnalyticsService? _analytics;

  SampleMenuSeeder({required AnalyticsService? analytics})
    : _analytics = analytics;

  /// BUT-930: builds a sample weekly-menu plan from the just-seeded recipes
  /// and generates its shopping list, so a brand-new user opens the menu and
  /// shopping tabs to populated content rather than empty states.
  ///
  /// Best-effort and idempotent, mirroring the starter-recipe seeding:
  /// - If the menu/shopping services aren't registered (e.g. unit tests that
  ///   only wire the recipe service) the outer try/catch swallows the lookup
  ///   failure and onboarding still completes.
  /// - The plan is only seeded when the current week is empty — re-running
  ///   onboarding (or a partial retry) never double-stacks entries. The
  ///   shopping-list generator is itself idempotent per ISO week.
  ///
  /// Recipes are routed to the lunch / middag / övrigt slot by their
  /// `mealType`, then placed deterministically into the first free day for
  /// THAT slot. Slots are independent — a lunch and a middag can share Monday —
  /// so placement never silently drops a recipe just because earlier recipes
  /// used up the leading days (the old "one recipe per day across all slots"
  /// walk could discard the breakfast/övrigt recipe). Single-recipe slots
  /// (lunch/middag) hold one per day across the seven days; övrigt is a
  /// multi-recipe bucket that stacks, so it always has room.
  ///
  /// BUT-2299: the recipes go through the same allergen filter as a generated
  /// menu, fed by the allergens chosen in this onboarding (the diet is asked
  /// after the first menu, B-39).
  Future<bool> seed(
    List<String> seededRecipeIds,
    UserAllergenPreferences? prefs,
  ) async {
    if (seededRecipeIds.isEmpty) return false;
    try {
      final recipeService = ServiceLocator.get<UnifiedRecipeService>();
      final menuService = ServiceLocator.get<WeeklyMenuPlanService>();
      final shoppingGenerator = ServiceLocator.get<MenuShoppingListGenerator>();
      final now = clock.now();

      final read = await menuService.readWeek(now);
      if (read.readFailed) {
        // BUT-1939. `getWeek` returned an empty plan for a week it could not
        // read, so `isNotEmpty` was false and the idempotency guard below did
        // not fire. Refusing is safe — it gates no navigation.
        AppLogger.warning(
          'Sample menu: skipped, the week could not be read',
        );
        return false;
      }
      var plan = read.plan;
      // Idempotency: never overwrite or stack onto a plan the user already
      // has for this week (covers onboarding re-entry / partial retries).
      if (plan.isNotEmpty) return true;

      // Track the next free day per single-recipe slot so each gets its own
      // Monday→Sunday fill independent of the other slots. Multi slots (övrigt)
      // stack on Monday — they're unbounded so there's no day to run out of.
      var recipes = [
        for (final id in seededRecipeIds) ?recipeService.getRecipeById(id),
      ];
      if (prefs != null) {
        recipes = MenuGenerator.filterByPrefs(recipes, prefs, allergens: true);
      }

      final nextDayForSlot = <MealSlot, int>{};
      var placed = 0;
      var dropped = 0;
      for (final recipe in recipes) {
        final slot = mapMealTypeToSlot(recipe.mealType);

        final int dayIndex;
        if (slot.isMulti) {
          // Multi slot: stack everything on Monday — capacity is unbounded.
          dayIndex = DayOfWeek.mon.index;
        } else {
          // Single slot: take the next free day for this slot specifically.
          dayIndex = nextDayForSlot[slot] ?? DayOfWeek.mon.index;
          if (dayIndex > DayOfWeek.sun.index) {
            // This slot is full across the whole week — skip rather than
            // double-book. With the current seed set this never triggers.
            dropped++;
            continue;
          }
          nextDayForSlot[slot] = dayIndex + 1;
        }

        plan = menuService.addEntry(
          plan: plan,
          day: DayOfWeek.values[dayIndex],
          slot: slot,
          recipe: recipe,
        );
        placed++;
      }

      if (dropped > 0) {
        AppLogger.warning(
          'Sample menu: $dropped seeded recipe(s) had no free single-slot day',
        );
      }
      if (placed == 0) return false;
      await menuService.save(plan);

      // BUT-1983: `generateForWeek` is wrapped in `executeServiceOperation`, so
      // anything that goes wrong inside it arrives as null rather than a throw.
      // `?? 0` turned every such failure into the number zero under the SUCCESS
      // event, where it was indistinguishable from a list that was simply
      // empty. The flag separates them.
      //
      // Still the success event, not the failure one: the menu itself was saved
      // a few lines up, so the seed genuinely half-succeeded and reporting it
      // as a clean failure would under-count the part that worked.
      final shoppingResult = await shoppingGenerator.generateForWeek(now);
      final shoppingFailed = shoppingResult == null;
      final shoppingItems = shoppingResult?.itemCount ?? 0;

      _analytics?.logEvent(
        name: AnalyticsEvents.onboardingMenuSeeded,
        parameters: {
          'menuEntries': placed,
          'shoppingItems': shoppingItems,
          'shoppingFailed': shoppingFailed,
        },
      );
      AppLogger.info(
        shoppingFailed
            ? 'Seeded sample menu: $placed entries, shopping list FAILED'
            : 'Seeded sample menu: $placed entries, $shoppingItems shopping items',
      );
      return true;
    } catch (e) {
      AppLogger.warning('Failed to seed sample menu: $e');
      // Measured, not narrated. The seed stays silent to the user but must not
      // stay silent to us — this catch has
      // always swallowed, and since BUT-1962 made a refused save throw, a
      // permission failure lands here too rather than being lost a layer down.
      _analytics?.logEvent(name: AnalyticsEvents.onboardingMenuSeedFailed);
      return false;
    }
  }
}
