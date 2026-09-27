// lib/viewmodels/hem/hem_viewmodel.dart
//
// HEM-HERO (package 6): what Hem shows above the recipe library.
//
//   produktregler.md:263   "Hem … svarar på en fråga — vad äter vi ikväll".
//   produktregler.md:265-274 (§ 6.1) the hero card's priority order, first
//                          hit wins: (1) today's slot is filled → the planned
//                          dish, marked IKVÄLL; (2) today is empty but the
//                          week has dishes later → the next planned day,
//                          marked with its weekday, never IKVÄLL; (3) the
//                          week is empty and the library has recipes → a
//                          suggestion; (4) the library is empty → the empty
//                          state.
//   produktregler.md:291-294 (§ 6.5) an error in the plan never empties the
//                          view; cached content carries its fetch time.
//
// Interpretations:
// * "Dagens plats" and IKVÄLL are the dinner slot (MealSlot.middag):
//   "ikväll" is the evening meal.
// * Row 3 (a suggestion from the library) is not built: it must follow the
//   allergy rules of § 1 (produktregler.md:24, only `säker` in a household
//   with an allergy requirement) and the app has no per-recipe safety
//   verdict to draw it from. Without it the card is not shown; the library
//   still is. Left for Linear.
// * Row 4 is decided by the library, which the recipe view owns.
library;

import 'package:clock/clock.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// Where the week's plan is.
enum HemPlanStatus {
  /// The first read has not answered yet (Skarmar v12 del 4 #hemladdar).
  loading,

  /// The plan was read (or is empty).
  ready,

  /// The read did not answer (#hemfel). The library stays.
  failed,
}

/// The dish the hero card shows (produktregler.md:268-269, rows 1 and 2).
class HemHero {
  const HemHero({
    required this.entry,
    required this.isTonight,
    this.recipe,
    this.allInPantry = false,
  });

  /// The planned slot. Its identity is [WeeklyMenuPlanEntry.id].
  final WeeklyMenuPlanEntry entry;

  /// Row 1: today's dinner. False for row 2, the next planned day.
  final bool isTonight;

  /// The recipe, when the library can answer for it. Null for a recipe that
  /// is gone or not loaded; the card then shows the planned title only.
  final Recipe? recipe;

  /// Every ingredient of the dish is in the pantry. False when that is not
  /// known: absence of data is never a claim.
  final bool allInPantry;
}

/// Rows 1 and 2 of produktregler.md:268-269 for [plan] on the day of [now]:
/// today's dinner, else the first dinner planned later in the week, else
/// null. Never an earlier day, and never a day outside [plan]'s week.
({WeeklyMenuPlanEntry entry, bool isTonight})? hemHeroEntry(
  WeeklyMenuPlan plan,
  DateTime now,
) {
  final today = DayOfWeek.values[now.weekday - 1];
  final weekStart = DateTime(
    plan.weekStartDate.year,
    plan.weekStartDate.month,
    plan.weekStartDate.day,
  );
  final day = DateTime(now.year, now.month, now.day);
  final offset = day.difference(weekStart).inDays;
  if (offset < 0 || offset > 6) return null;

  WeeklyMenuPlanEntry? dinnerOn(DayOfWeek d) {
    for (final e in plan.entries) {
      if (e.day == d && e.slot == MealSlot.middag) return e;
    }
    return null;
  }

  final tonight = dinnerOn(today);
  if (tonight != null) return (entry: tonight, isTonight: true);
  for (var i = today.index + 1; i < DayOfWeek.values.length; i++) {
    final later = dinnerOn(DayOfWeek.values[i]);
    if (later != null) return (entry: later, isTonight: false);
  }
  return null;
}

/// Whether every normalised ingredient of [recipe] is among
/// [pantryIngredientIds]. False when the recipe has no normalised
/// ingredients: "Frånvaro av data är aldrig ett säkert svar"
/// (produktregler.md:20) holds for the pantry claim too.
bool hemAllInPantry(Recipe recipe, Set<String> pantryIngredientIds) {
  final needed = recipe.core.ingredientsNormalized;
  if (needed == null || needed.isEmpty) return false;
  return needed.every(pantryIngredientIds.contains);
}

/// Reads the week and tells Hem what to show above the library.
class HemViewModel extends BaseViewModel {
  HemViewModel({
    required Future<WeeklyMenuPlanRead> Function(DateTime date) readWeek,
    required Recipe? Function(String recipeId) recipeById,
    required Future<Set<String>> Function() pantryIngredientIds,
    required bool Function() isOnline,
  }) : _readWeek = readWeek,
       _recipeById = recipeById,
       _pantryIngredientIds = pantryIngredientIds,
       _isOnline = isOnline;

  /// The existing sources: the week's plan (the Meny tab's service), the
  /// library's recipes, and the pantry of the signed-in user (as the pantry
  /// view reads it, PantryViewModel).
  factory HemViewModel.fromServices() {
    final offline = ServiceLocator.tryGet<OfflineService>();
    return HemViewModel(
      readWeek: ServiceLocator.get<WeeklyMenuPlanService>().readWeek,
      recipeById: ServiceLocator.get<UnifiedRecipeService>().getRecipeById,
      pantryIngredientIds: () async {
        final userId = ServiceLocator.get<PermissionService>().currentUserId;
        if (userId == null) return const <String>{};
        final items = await ServiceLocator.get<PantryService>().getAll(userId);
        return items.map((i) => i.ingredientId).whereType<String>().toSet();
      },
      isOnline: () => offline?.isOnline ?? true,
    );
  }

  final Future<WeeklyMenuPlanRead> Function(DateTime date) _readWeek;
  final Recipe? Function(String recipeId) _recipeById;
  final Future<Set<String>> Function() _pantryIngredientIds;
  final bool Function() _isOnline;

  HemPlanStatus _status = HemPlanStatus.loading;
  HemHero? _hero;
  DateTime? _fetchedAt;
  int _generation = 0;
  bool _resolving = false;

  HemPlanStatus get status => _status;

  /// The dish for the hero card, or null when rows 1 and 2 have none.
  HemHero? get hero => _hero;

  /// When the shown plan was last read while online. Null until then: a
  /// plan read offline comes from the device and its age is not known.
  DateTime? get fetchedAt => _fetchedAt;

  /// Reads the week of today. A second call while one runs wins.
  Future<void> load() async {
    final generation = ++_generation;
    final now = clock.now();
    final online = _isOnline();
    if (_status == HemPlanStatus.failed) {
      _status = HemPlanStatus.loading;
      notifyListeners();
    }
    final read = await _readWeek(now);
    if (isDisposed || generation != _generation) return;
    if (read.readFailed) {
      _status = HemPlanStatus.failed;
      _hero = null;
      notifyListeners();
      return;
    }
    final picked = hemHeroEntry(read.plan, now);
    final recipe = picked == null ? null : _recipeById(picked.entry.recipeId);
    final allInPantry = recipe == null ? false : await _allInPantry(recipe);
    if (isDisposed || generation != _generation) return;
    _hero = picked == null
        ? null
        : HemHero(
            entry: picked.entry,
            isTonight: picked.isTonight,
            recipe: recipe,
            allInPantry: allInPantry,
          );
    if (online) _fetchedAt = now;
    _status = HemPlanStatus.ready;
    notifyListeners();
  }

  /// Fills in the hero's recipe once the library has it.
  ///
  /// The week is often read before the library has loaded (both start on the
  /// first frame), and the recipe lookup is a plain read of what is loaded.
  /// Without this the card would keep the planned title only, with no
  /// "Börja laga" and no pantry line, until the next pull-to-refresh. Cheap
  /// when there is nothing to fill in, so the view calls it on every change
  /// of the library.
  Future<void> resolveRecipe() async {
    final hero = _hero;
    if (_resolving || hero == null || hero.recipe != null) return;
    final recipe = _recipeById(hero.entry.recipeId);
    if (recipe == null) return;
    final generation = _generation;
    _resolving = true;
    final bool allInPantry;
    try {
      allInPantry = await _allInPantry(recipe);
    } finally {
      _resolving = false;
    }
    if (isDisposed || generation != _generation || !identical(_hero, hero)) {
      return;
    }
    _hero = HemHero(
      entry: hero.entry,
      isTonight: hero.isTonight,
      recipe: recipe,
      allInPantry: allInPantry,
    );
    notifyListeners();
  }

  Future<bool> _allInPantry(Recipe recipe) async {
    try {
      return hemAllInPantry(recipe, await _pantryIngredientIds());
    } catch (_) {
      // The pantry line is extra information; without it the card stands.
      return false;
    }
  }
}
