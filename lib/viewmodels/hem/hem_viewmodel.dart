// lib/viewmodels/hem/hem_viewmodel.dart
//
// HEM-HERO (package 6): what Hem shows above the recipe library.
//
// Interpretations:
// * "Dagens plats" and IKVÄLL are the dinner slot (MealSlot.middag):
//   "ikväll" is the evening meal.
// * Row 3 (a suggestion from the library) follows the allergy rules of § 1
//   it is drawn only from recipes that pass the menu's
//   allergen and dietary filter with unknown treated as unsafe, and not at
//   all when the household's preferences cannot be resolved or its roster is
//   incomplete. Absence of data is never a safe answer.
// * Row 4 is decided by the library, which the recipe view owns.
library;

import 'package:clock/clock.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

/// Where the week's plan is.
enum HemPlanStatus {
  /// The first read has not answered yet.
  loading,

  /// The plan was read (or is empty).
  ready,

  /// The read did not answer (#hemfel). The library stays.
  failed,
}

/// The dish the hero card shows (rows 1 to 3).
class HemHero {
  const HemHero({
    required this.entry,
    required this.isTonight,
    this.recipe,
    this.allInPantry = false,
  });

  /// A row 3 suggestion out of the library; nothing is planned.
  const HemHero.suggestion({
    required Recipe this.recipe,
    this.allInPantry = false,
  }) : entry = null,
       isTonight = false;

  /// The planned slot. Its identity is [WeeklyMenuPlanEntry.id]. Null for a
  /// suggestion.
  final WeeklyMenuPlanEntry? entry;

  /// Row 1: today's dinner. False for row 2, the next planned day, and for a
  /// suggestion.
  final bool isTonight;

  /// Row 3: a library recipe suggested because the week has no dinner left.
  bool get isSuggestion => entry == null;

  /// The recipe, when the library can answer for it. Null for a recipe that
  /// is gone or not loaded; the card then shows the planned title only.
  final Recipe? recipe;

  /// Every ingredient of the dish is in the pantry. False when that is not
  /// known: absence of data is never a claim.
  final bool allInPantry;
}

/// Rows 1 and 2 for [plan] on the day of [now]:
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

/// Dinners quicker than this are what a suggestion prefers ("snabblaga").
const int hemQuickMinutes = 45;

/// The recipes row 3 may suggest, in a stable order: those that pass the
/// menu's allergen and dietary filter for [prefs] with an unknown status
/// counted as unsafe whatever the household's own "include unknown" choice
/// is. Quick dishes ([hemQuickMinutes] or less) come alone when there are
/// any, so the suggestion is something that can be cooked tonight.
List<Recipe> hemSuggestionPool(
  List<Recipe> library,
  UserAllergenPreferences prefs,
) {
  final strict = UserAllergenPreferences(
    trackedAllergens: prefs.trackedAllergens,
    trackedDietary: prefs.trackedDietary,
    includeUnknownInMenu: false,
  );
  final allergenSafe = MenuGenerator.filterByPrefs(
    library,
    strict,
    allergens: true,
  );
  final safe =
      MenuGenerator.filterByPrefs(
          allergenSafe,
          strict,
          allergens: false,
        ).where((r) => r.title.trim().isNotEmpty).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  final quick = safe.where((r) {
    final minutes = r.timeMinutes;
    return minutes != null && minutes <= hemQuickMinutes;
  }).toList();
  return quick.isNotEmpty ? quick : safe;
}

/// The household's [prefs] when everyone's allergies are known, else null:
/// with someone unknown no suggestion is safe.
UserAllergenPreferences? hemPrefsOrNull(
  UserAllergenPreferences prefs,
  MenuPrefSource source,
) => source.isRosterIncomplete ? null : prefs;

/// The preferences a suggestion is made for: the household's, or null when
/// the profile is not loaded, the roster is incomplete or the read fails.
Future<UserAllergenPreferences?> hemHouseholdPrefs(
  UserService userService, {
  Future<(UserAllergenPreferences, MenuPrefSource)> Function(UserService)
      resolve =
      MenuGenerator.resolveHouseholdPrefs,
}) async {
  try {
    if (userService.currentUserProfile == null) return null;
    final (prefs, source) = await resolve(userService);
    return hemPrefsOrNull(prefs, source);
  } catch (_) {
    return null;
  }
}

/// Whether every normalised ingredient of [recipe] is among
/// [pantryIngredientIds]. False when the recipe has no normalised
/// ingredients: "Frånvaro av data är aldrig ett säkert svar"
/// holds for the pantry claim too.
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
    List<Recipe> Function()? library,
    Future<UserAllergenPreferences?> Function()? householdPrefs,
  }) : _readWeek = readWeek,
       _recipeById = recipeById,
       _pantryIngredientIds = pantryIngredientIds,
       _isOnline = isOnline,
       _library = library,
       _householdPrefs = householdPrefs;

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
      library: () =>
          ServiceLocator.tryGet<UnifiedRecipeService>()?.recipes ?? const [],
      householdPrefs: () =>
          hemHouseholdPrefs(ServiceLocator.get<UserService>()),
    );
  }

  final Future<WeeklyMenuPlanRead> Function(DateTime date) _readWeek;
  final Recipe? Function(String recipeId) _recipeById;
  final Future<Set<String>> Function() _pantryIngredientIds;
  final bool Function() _isOnline;
  final List<Recipe> Function()? _library;
  final Future<UserAllergenPreferences?> Function()? _householdPrefs;

  List<Recipe> _suggestionPool = const [];
  int _suggestionSkip = 0;
  int _suggestionLibrarySize = -1;
  bool _suggesting = false;

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
    _suggestionPool = const [];
    _suggestionSkip = 0;
    _suggestionLibrarySize = -1;
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
    await _suggest();
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
    if (hero == null) {
      await _suggest();
      return;
    }
    final entry = hero.entry;
    if (_resolving || entry == null || hero.recipe != null) return;
    final recipe = _recipeById(entry.recipeId);
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

  /// Whether "Byt förslag" has another suggestion to show.
  bool get canSwapSuggestion => _suggestionPool.length > 1;

  /// Row 3: when the week has no dinner to show, suggests a library recipe
  /// that is safe for the household. The library often lands after the week
  /// is read, so [resolveRecipe] calls this on every change of the library;
  /// it only works again when the library's size has changed.
  Future<void> _suggest() async {
    final library = _library;
    final prefsOf = _householdPrefs;
    if (_status != HemPlanStatus.ready ||
        _hero != null ||
        library == null ||
        prefsOf == null ||
        _suggesting) {
      return;
    }
    final recipes = library();
    if (recipes.isEmpty || recipes.length == _suggestionLibrarySize) return;
    final generation = _generation;
    _suggesting = true;
    final UserAllergenPreferences? prefs;
    try {
      prefs = await prefsOf();
    } finally {
      _suggesting = false;
    }
    if (isDisposed || generation != _generation || _hero != null) return;
    _suggestionLibrarySize = recipes.length;
    // No answer about the household is not a safe answer: no suggestion.
    if (prefs == null) return;
    _suggestionPool = hemSuggestionPool(recipes, prefs);
    await _showSuggestion();
  }

  /// "Byt förslag": the next safe recipe in the pool.
  Future<void> nextSuggestion() async {
    if (_hero?.isSuggestion != true) return;
    _suggestionSkip++;
    await _showSuggestion();
  }

  Future<void> _showSuggestion() async {
    if (_suggestionPool.isEmpty) return;
    final generation = _generation;
    // The same dish all day, a new one tomorrow.
    final today = clock.now();
    final dayNumber = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(2026)).inDays;
    final recipe =
        _suggestionPool[(dayNumber + _suggestionSkip) % _suggestionPool.length];
    final allInPantry = await _allInPantry(recipe);
    if (isDisposed || generation != _generation) return;
    final current = _hero;
    if (current != null && !current.isSuggestion) return;
    _hero = HemHero.suggestion(recipe: recipe, allInPantry: allInPantry);
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
