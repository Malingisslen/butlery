// lib/viewmodels/menu/manual_add_check.dart

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/menu/meal_dislikes.dart';
import 'package:butlery/services/menu/meal_slot_mapper.dart';
import 'package:butlery/services/tagging/allergen_verdict.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/menu/menu_generator.dart';

/// What a recipe placed in the menu by hand conflicts with.
class ManualAddFinding {
  final Recipe recipe;

  /// Tracked allergens the recipe contains.
  final List<String> containsAllergens;

  /// Tracked allergens nobody has settled for this recipe.
  final List<String> uncheckedAllergens;

  /// Someone in the household dislikes an ingredient in the recipe.
  final bool disliked;

  const ManualAddFinding({
    required this.recipe,
    required this.containsAllergens,
    required this.uncheckedAllergens,
    required this.disliked,
  });

  /// An unchecked allergen alone does not stop the add: the card and the
  /// detail already say "Ej kontrollerat", and asking about every untagged
  /// recipe would teach people to tap through the question.
  bool get needsConfirmation => containsAllergens.isNotEmpty || disliked;

  bool get isEmpty =>
      containsAllergens.isEmpty && uncheckedAllergens.isEmpty && !disliked;
}

/// Checks recipes a person places in the menu by hand against the household's
/// allergies and dislikes, with the same verdict the generator uses. The
/// generator filters on its own; a manual add used to skip every check.
class ManualAddCheck {
  /// The seams default to the live household reads; tests replace them.
  const ManualAddCheck({
    Future<UserAllergenPreferences> Function()? householdPrefs,
    UserAllergenPreferences Function()? ownPrefs,
    Future<Map<String, Set<String>>> Function()? readDislikes,
  }) : _householdPrefs = householdPrefs,
       _ownPrefs = ownPrefs,
       _readDislikes = readDislikes;

  final Future<UserAllergenPreferences> Function()? _householdPrefs;
  final UserAllergenPreferences Function()? _ownPrefs;
  final Future<Map<String, Set<String>>> Function()? _readDislikes;

  /// Findings for the recipes that conflict. Allergen preferences come from the
  /// same household resolution as generation; when that read fails the check
  /// falls back to the common-allergen safety floor, never to no check. A failed
  /// dislikes read leaves dislikes out, since a dislike is not a safety control.
  Future<List<ManualAddFinding>> check(List<Recipe> recipes) async {
    if (recipes.isEmpty) return const [];
    UserAllergenPreferences prefs;
    try {
      prefs = await (_householdPrefs ?? _liveHouseholdPrefs)();
    } catch (e) {
      AppLogger.error('Manual add: household allergens unreadable', e);
      prefs = HouseholdService.widenWithSafetyFloor(
        (_ownPrefs ?? _liveOwnPrefs)(),
      );
    }
    Map<String, Set<String>> dislikesByMember;
    try {
      dislikesByMember =
          await (_readDislikes ?? const MealDislikesResolver().readDislikes)();
    } catch (e) {
      AppLogger.warning('Manual add: dislikes unreadable ($e)');
      dislikesByMember = const {};
    }
    return findingsFor(
      recipes,
      prefs: prefs,
      dislikes: MealDislikes(dislikesByMember: dislikesByMember, plan: null),
    );
  }

  static Future<UserAllergenPreferences> _liveHouseholdPrefs() async {
    final (prefs, _) = await MenuGenerator.resolveHouseholdPrefs(
      ServiceLocator.get<UserService>(),
    );
    return prefs;
  }

  static UserAllergenPreferences _liveOwnPrefs() =>
      HouseholdService.ownMenuPreferences(
        ServiceLocator.tryGet<UserService>()?.currentUserProfile,
      );

  static List<ManualAddFinding> findingsFor(
    List<Recipe> recipes, {
    required UserAllergenPreferences prefs,
    required MealDislikes dislikes,
  }) {
    final findings = <ManualAddFinding>[];
    for (final recipe in recipes) {
      final contains = <String>[];
      final unchecked = <String>[];
      for (final allergen in prefs.trackedAllergens) {
        final status = AllergenVerdict.forAllergen(recipe, allergen).effective;
        if (status == TriState.contains) contains.add(allergen);
        if (status == TriState.unknown) unchecked.add(allergen);
      }
      final finding = ManualAddFinding(
        recipe: recipe,
        containsAllergens: contains..sort(),
        uncheckedAllergens: unchecked..sort(),
        disliked: dislikes.avoids(
          recipe,
          DayOfWeek.mon,
          mapMealTypeToSlot(recipe.mealType),
        ),
      );
      if (!finding.isEmpty) findings.add(finding);
    }
    return findings;
  }
}
