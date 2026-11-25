// lib/viewmodels/menu/stock_lunch_fill.dart

import 'dart:async';

import 'package:butlery/core/di/meal_box_feature_from_locator.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/lunchbox_plan.dart';
import 'package:butlery/models/menu/meal_box.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/menu/meal_box_service.dart';
import 'package:butlery/services/menu/meal_dislikes.dart';
import 'package:butlery/services/menu/stock_lunch_planner.dart';
import 'package:butlery/viewmodels/menu/manual_add_check.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

/// What a suggested week takes from the fridge and freezer: the lunchboxes
/// to place, and whether the boxes could not be read.
typedef StockLunches = ({Map<DayOfWeek, Lunchbox> boxes, bool readFailed});

/// Reads the boxes once and plans them as lunches for a suggested week
/// (BUT-2486 part 6). The app chooses here without asking, so the check is
/// stricter than a hand pick.
class StockLunchFill {
  const StockLunchFill({
    bool Function()? enabled,
    Future<List<MealBox>> Function()? readBoxes,
    Future<UserAllergenPreferences> Function()? householdPrefs,
    this.readTimeout = const Duration(seconds: 3),
  }) : _enabled = enabled,
       _readBoxes = readBoxes,
       _householdPrefs = householdPrefs;

  final bool Function()? _enabled;
  final Future<List<MealBox>> Function()? _readBoxes;
  final Future<UserAllergenPreferences> Function()? _householdPrefs;

  /// A slow read must not hold the suggested week back; past this the week
  /// is placed without boxes.
  final Duration readTimeout;

  static const StockLunches none = (boxes: {}, readFailed: false);

  /// Reads nothing when the switch is off or no chosen day is open.
  Future<StockLunches> plan({
    required WeeklyMenuPlan week,
    required Set<DayOfWeek> days,
    required DateTime now,
    required Recipe? Function(String recipeId) recipeFor,
    MealDislikes? dislikes,
  }) async {
    if (days.isEmpty || !(_enabled ?? mealBoxesEnabled)()) return none;
    if (StockLunchPlanner.openDays(
      week: week,
      days: days,
      today: now,
    ).isEmpty) {
      return none;
    }
    final List<MealBox> boxes;
    final UserAllergenPreferences prefs;
    try {
      boxes = await (_readBoxes ?? _liveBoxes)().timeout(readTimeout);
      // A box carries no takers, so it is judged against the household.
      prefs = await (_householdPrefs ?? _liveHouseholdPrefs)().timeout(
        readTimeout,
      );
    } catch (e) {
      AppLogger.warning('Stock lunches skipped: ${e.runtimeType}');
      return (boxes: const <DayOfWeek, Lunchbox>{}, readFailed: true);
    }
    final noDislikes = MealDislikes(dislikesByMember: const {}, plan: null);
    return (
      boxes: StockLunchPlanner.plan(
        week: week,
        boxes: boxes,
        days: days,
        today: now,
        isSafe: (box, day) => isSafe(
          box,
          day,
          prefs: prefs,
          dislikes: dislikes ?? noDislikes,
          recipeFor: recipeFor,
        ),
      ),
      readFailed: false,
    );
  }

  /// A box is placed only when its recipe is known, passes the household's
  /// allergens and diets as the generator filters them, and has no allergen
  /// that is in it, unchecked or disliked by someone eating that lunch.
  static bool isSafe(
    MealBox box,
    DayOfWeek day, {
    required UserAllergenPreferences prefs,
    required MealDislikes dislikes,
    required Recipe? Function(String recipeId) recipeFor,
  }) {
    final id = box.recipeId;
    final recipe = id == null || id.isEmpty ? null : recipeFor(id);
    if (recipe == null) return false;
    if (MenuGenerator.filterByPrefs([recipe], prefs, allergens: true).isEmpty) {
      return false;
    }
    if (MenuGenerator.filterByPrefs(
      [recipe],
      prefs,
      allergens: false,
    ).isEmpty) {
      return false;
    }
    return ManualAddCheck.findingAt(
      recipe,
      prefs: prefs,
      dislikes: dislikes,
      day: day,
      slot: MealSlot.lunch,
    ).isEmpty;
  }

  /// The generator's own household resolution, which can throw: the
  /// calendar's helper falls back to the user's own allergens, and a box
  /// placed without asking must not be judged on less than the household.
  static Future<UserAllergenPreferences> _liveHouseholdPrefs() async {
    final (prefs, _) = await MenuGenerator.resolveHouseholdPrefs(
      ServiceLocator.get<OwnProfileReader>(),
    );
    return prefs;
  }

  static Future<List<MealBox>> _liveBoxes() =>
      ServiceLocator.get<MealBoxService>().list();
}
