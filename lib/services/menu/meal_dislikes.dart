// lib/services/menu/meal_dislikes.dart

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/dislike_vocabulary.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/active_household.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/menu/meal_slot_mapper.dart';
import 'package:butlery/services/permission_service.dart';

/// Who dislikes what, read against one week's who's-home (BUT-1625).
///
/// A dislike is a soft taste preference. It moves a dish to a meal where
/// nobody at home dislikes it, and down-weights a dish no meal can take. It
/// never removes a dish from the allergen-safe pool and never adds one, so
/// it cannot change what the menu considers safe.
///
/// Never persisted and never cached across calls: every placement and every
/// generation builds a fresh one from the roster and the week as they are.
class MealDislikes {
  MealDislikes({
    required Map<String, Set<String>> dislikesByMember,
    required this.plan,
  }) : _byMember = {
         for (final e in dislikesByMember.entries)
           if (e.value.isNotEmpty) e.key: e.value,
       };

  /// Nobody dislikes anything: placement and scoring behave as before.
  static final MealDislikes none = MealDislikes(
    dislikesByMember: const {},
    plan: null,
  );

  final Map<String, Set<String>> _byMember;

  /// The week whose presence decides who is home. Null = everyone, always.
  final WeeklyMenuPlan? plan;

  bool get isEmpty => _byMember.isEmpty;

  /// Whether someone eating [slot] on [day] dislikes something in [recipe].
  ///
  /// Övrigt is eaten by the whole household whoever is home for lunch or
  /// middag, so it always counts everyone. For lunch and middag an unset
  /// presence means everyone, and an explicit empty one means nobody.
  bool avoids(Recipe recipe, DayOfWeek day, MealSlot slot) {
    if (_byMember.isEmpty) return false;
    final present = slot.isMulti ? null : plan?.presentMemberIdsFor(day, slot);
    final keys = <String>{
      for (final e in _byMember.entries)
        if (present == null || present.contains(e.key)) ...e.value,
    };
    return DislikeVocabulary.recipeContainsAny(recipe, keys);
  }

  /// Whether every meal of [recipe]'s own kind from [fromDay] on is one
  /// where someone at home dislikes it: no placement could avoid it.
  bool unplaceable(Recipe recipe, {DayOfWeek fromDay = DayOfWeek.mon}) {
    if (_byMember.isEmpty) return false;
    final slot = mapMealTypeToSlot(recipe.mealType);
    for (var i = fromDay.index; i < DayOfWeek.values.length; i++) {
      if (!avoids(recipe, DayOfWeek.values[i], slot)) return false;
    }
    return true;
  }

  /// The ids in [pool] no placement this week could serve without a dislike.
  Set<String> unplaceableIds(
    Iterable<Recipe> pool, {
    DayOfWeek fromDay = DayOfWeek.mon,
  }) => {
    for (final r in pool)
      if (unplaceable(r, fromDay: fromDay)) r.id,
  };
}

/// Reads every household member's disliked ingredients from the roster, the
/// same read-only way `PresentDinerPrefsResolver` reads allergens. Kept
/// apart from it on purpose: a failure here must never touch the allergen
/// path.
class MealDislikesResolver {
  const MealDislikesResolver();

  /// memberId → dislike keys. Empty when there is no household, nothing is
  /// wired, or the read fails: a dislike is not a safety control, so the
  /// menu then simply places dishes as it did before dislikes counted.
  Future<Map<String, Set<String>>> readDislikes() async {
    try {
      final rosterService = ServiceLocator.tryGet<HouseholdRosterService>();
      final householdRepo = ServiceLocator.tryGet<HouseholdRepository>();
      final uid = ServiceLocator.tryGet<PermissionService>()?.currentUserId;
      if (rosterService == null || householdRepo == null || uid == null) {
        return const {};
      }
      // Read-only: never `ensureForUser`.
      final households = await householdRepo.eatingHouseholdsFor(uid);
      if (households.isEmpty) return const {};
      final roster = await rosterService.tryGetRosters(
        households.map((h) => h.id),
      );
      if (roster == null) return const {};
      return {
        for (final m in roster)
          if (m.dislikedIngredients.isNotEmpty)
            m.memberId: m.dislikedIngredients,
      };
    } catch (e) {
      // Nothing about the household in the log: the roster holds children.
      AppLogger.warning('Meal dislikes unreadable (${e.runtimeType})');
      return const {};
    }
  }
}
