// lib/viewmodels/menu/meal_allergen_scope.dart

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/menu/present_diner_prefs_resolver.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

/// Which allergens a dish has to avoid at each meal of one week (BUT-2362).
///
/// Every meal follows the whole household unless the per-meal choice is on
/// and the week says who is away at that lunch or middag; then that meal
/// follows everyone else. Övrigt always follows the whole household. Built
/// fresh for each placement and each calendar read, never persisted.
class MealAllergenScope {
  MealAllergenScope({
    required this.household,
    Map<(DayOfWeek, MealSlot), UserAllergenPreferences> byMeal = const {},
  }) : _byMeal = byMeal;

  /// What the whole household avoids: the same set menu generation filters by.
  final UserAllergenPreferences household;

  final Map<(DayOfWeek, MealSlot), UserAllergenPreferences> _byMeal;

  /// Whether any meal follows fewer people than the whole household.
  bool get isScoped => _byMeal.isNotEmpty;

  UserAllergenPreferences prefsAt(DayOfWeek day, MealSlot slot) =>
      slot.isMulti ? household : (_byMeal[(day, slot)] ?? household);

  /// Whether everyone eating [slot] on [day] can eat [recipe], judged by the
  /// filter menu generation uses, so an unknown allergen is handled the same.
  bool safeAt(Recipe recipe, DayOfWeek day, MealSlot slot) =>
      _passes(recipe, prefsAt(day, slot));

  bool safeForHousehold(Recipe recipe) => _passes(recipe, household);

  /// Whether some [slot]-kind meal from [fromDay] on can take [recipe].
  bool safeAtSomeMeal(
    Recipe recipe,
    MealSlot slot, {
    DayOfWeek fromDay = DayOfWeek.mon,
  }) {
    if (safeForHousehold(recipe)) return true;
    if (slot.isMulti) return false;
    for (var i = fromDay.index; i < DayOfWeek.values.length; i++) {
      if (safeAt(recipe, DayOfWeek.values[i], slot)) return true;
    }
    return false;
  }

  /// Ids of the entries in [plan] that someone eating that meal cannot eat.
  /// An entry whose recipe [recipeFor] cannot find is not judged.
  Set<String> unsafeEntryIds(
    WeeklyMenuPlan plan,
    Recipe? Function(String recipeId) recipeFor,
  ) => {
    for (final entry in plan.entries)
      if (recipeFor(entry.recipeId) case final recipe?)
        if (!safeAt(recipe, entry.day, entry.slot)) entry.id,
  };

  static bool _passes(Recipe recipe, UserAllergenPreferences prefs) =>
      MenuGenerator.filterByPrefs([recipe], prefs, allergens: true).isNotEmpty;

  /// Whether the user's per-meal choice applies: it is on, the household
  /// filter it narrows is on, and there is a household. A stored `true`
  /// without the other two is ignored.
  static bool isOn(UserService userService) {
    final profile = userService.currentUserProfile;
    if (!(profile?.useMealAllergenScope ?? false)) return false;
    if (!(profile?.useHouseholdAllergens ?? true)) return false;
    return ServiceLocator.tryGet<HouseholdService>()?.hasHousehold ?? false;
  }

  /// The scope for [plan]. A meal whose people cannot be resolved with
  /// certainty follows the whole household; if the household itself cannot
  /// be read, every meal follows the user's own allergens plus the
  /// common-allergen floor.
  static Future<MealAllergenScope> resolve({
    required UserService userService,
    required WeeklyMenuPlan? plan,
  }) async {
    final household = await _householdPrefs(userService);
    if (plan == null || !isOn(userService)) {
      return MealAllergenScope(household: household);
    }

    final accounts =
        ServiceLocator.tryGet<HouseholdService>()?.getHouseholdMemberIds() ??
        const <String>[];
    final byMeal = <(DayOfWeek, MealSlot), UserAllergenPreferences>{};
    final byAwaySet = <String, UserAllergenPreferences?>{};
    for (final day in DayOfWeek.values) {
      for (final slot in kPresenceSlots) {
        final away = plan.allergenAwayIdsFor(day, slot);
        if (away.isEmpty) continue;
        final key = (away.toList()..sort()).join('\u0000');
        final UserAllergenPreferences? prefs;
        if (byAwaySet.containsKey(key)) {
          prefs = byAwaySet[key];
        } else {
          prefs = await _homePrefsOrNull(away, accounts);
          byAwaySet[key] = prefs;
        }
        if (prefs != null) byMeal[(day, slot)] = prefs;
      }
    }
    return MealAllergenScope(household: household, byMeal: byMeal);
  }

  static Future<UserAllergenPreferences> _householdPrefs(
    UserService userService,
  ) async {
    try {
      return (await MenuGenerator.resolveHouseholdPrefs(userService)).$1;
    } catch (e) {
      AppLogger.warning(
        'Meal allergen household read failed (${e.runtimeType})',
      );
      return HouseholdService.widenWithSafetyFloor(
        HouseholdService.ownMenuPreferences(userService.currentUserProfile),
      );
    }
  }

  static final _floorOnly = HouseholdService.widenWithSafetyFloor(
    UserAllergenPreferences.none,
  );

  /// [resolve] with the registered [UserService], for wiring a viewmodel.
  /// With none registered every meal follows the user's own allergens and
  /// the common-allergen floor.
  static Future<MealAllergenScope> resolveFromLocator(WeeklyMenuPlan plan) {
    final users = ServiceLocator.tryGet<UserService>();
    if (users == null) {
      return Future.value(MealAllergenScope(household: _floorOnly));
    }
    return resolve(userService: users, plan: plan);
  }

  /// What the whole household avoids, with the registered [UserService].
  static Future<UserAllergenPreferences> householdFromLocator() {
    final users = ServiceLocator.tryGet<UserService>();
    if (users == null) return Future.value(_floorOnly);
    return _householdPrefs(users);
  }

  /// [isOn] with the registered [UserService]; off when there is none.
  static bool isOnFromLocator() {
    final users = ServiceLocator.tryGet<UserService>();
    return users != null && isOn(users);
  }

  static Future<UserAllergenPreferences?> _homePrefsOrNull(
    Set<String> away,
    List<String> accounts,
  ) async {
    try {
      return await const PresentDinerPrefsResolver().resolveAllExcept(
        away,
        householdAccountIds: accounts,
      );
    } catch (e) {
      AppLogger.warning('Meal allergen read failed (${e.runtimeType})');
      return null;
    }
  }
}
