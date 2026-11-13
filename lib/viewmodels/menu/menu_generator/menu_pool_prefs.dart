import 'package:butlery/core/di/household_links_from_locator.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/menu/menu_allergen_trust.dart';
import 'package:butlery/services/menu/present_diner_prefs_resolver.dart';
import 'package:butlery/services/user_service/user_service_roles.dart';
import 'package:butlery/viewmodels/menu/menu_generator/menu_pool_models.dart';

/// The allergen/dietary preferences the menu pool is filtered by, and the one
/// filter itself.
abstract final class MenuPoolPrefs {
  /// Resolves which allergen/dietary preferences the async pool filters by.
  ///
  /// Priority: present-diner union (opt-in, NON-EMPTY set required — an empty
  /// "no one selected" list must NOT disable filtering) → whole-household
  /// union → the single user's own preferences. Every fall-through lands on a
  /// FILTERED pool, never an unfiltered one.
  static Future<(UserAllergenPreferences, MenuPrefSource)> resolveActive(
    OwnProfileReader userService,
    List<String>? presentMemberIds,
  ) async {
    final present = presentMemberIds;
    if (present != null && present.isNotEmpty) {
      final resolved = await PresentDinerPrefsResolver(
        householdLinksFromLocator(),
      ).resolve(present);
      if (resolved != null) {
        return (
          resolved.preferences,
          resolved.isComplete
              ? MenuPrefSource.present
              : MenuPrefSource.presentIncomplete,
        );
      }
    }
    return resolveHousehold(userService);
  }

  /// The whole-household half of [resolveActive]: household union, or
  /// the single user's own preferences, plus every diner profile. Every
  /// fall-through lands on a FILTERED set, never an unfiltered one. Static so
  /// the per-meal allergen scope (BUT-2362) judges against exactly what
  /// generation filters by.
  static Future<(UserAllergenPreferences, MenuPrefSource)> resolveHousehold(
    OwnProfileReader userService,
  ) async {
    final useHouseholdAllergens =
        userService.currentUserProfile?.useHouseholdAllergens ?? true;
    final ownPrefs = HouseholdService.ownMenuPreferences(
      userService.currentUserProfile,
    );
    final householdService = ServiceLocator.tryGet<HouseholdService>();
    final hasFriendHousehold = householdService?.hasHousehold ?? false;
    var (prefs, source) = (ownPrefs, MenuPrefSource.singleUser);
    if (useHouseholdAllergens && hasFriendHousehold) {
      final aggregate = await householdService!.aggregateAllergenPreferences();
      (prefs, source) = (
        aggregate.preferences,
        aggregate.isRosterComplete
            ? MenuPrefSource.household
            : MenuPrefSource.householdIncomplete,
      );
    }
    // Family diner profiles (children) join the union. The household toggle
    // is only shown with a friend-based household, so without one a stale
    // `false` must not silently drop a child's allergens.
    if (useHouseholdAllergens || !hasFriendHousehold) {
      final withDiners = await PresentDinerPrefsResolver(
        householdLinksFromLocator(),
      ).addHouseholdDiners(prefs);
      if (withDiners != null && withDiners.changed) {
        final complete =
            withDiners.prefs.isComplete && !source.isRosterIncomplete;
        return (
          withDiners.prefs.preferences,
          complete
              ? MenuPrefSource.household
              : MenuPrefSource.householdIncomplete,
        );
      }
    }
    return (prefs, source);
  }

  /// Filter recipes using explicit prefs — the ONE allergen/dietary filter
  /// for menu pools (household, present-diner, and single-user paths all
  /// land here so the trust guards can't diverge between them).
  ///
  /// Statuses go through [MenuAllergenTrust] (BUT-1464): manual overrides
  /// honoured, stale FREE downgraded to UNKNOWN, stale CONTAINS kept.
  /// A recipe with NO tagResult is functionally UNKNOWN (BUT-1394) and
  /// follows the same `includeUnknownInMenu` opt-out as tagged-but-unknown.
  ///
  /// [unknownSoftCollector], when supplied on the allergen pass, receives the
  /// ids of recipes that were INCLUDED despite an UNKNOWN effective status
  /// for a tracked allergen — the UI marks these (PM condition 2).
  ///
  /// Static so the onboarding sample menu (BUT-2299) filters through the same
  /// guards as a generated menu.
  static List<Recipe> filterByPrefs(
    List<Recipe> recipes,
    UserAllergenPreferences prefs, {
    required bool allergens,
    Set<String>? unknownSoftCollector,
  }) {
    if (allergens) {
      if (!prefs.hasTrackedAllergens) return recipes;
      final tracked = prefs.trackedAllergens;
      final includeUnknown = prefs.includeUnknownInMenu;
      return recipes.where((recipe) {
        var sawUnknown = false;
        for (final allergen in tracked) {
          final status = MenuAllergenTrust.effectiveAllergenStatus(
            recipe,
            allergen,
          );
          if (status == TriState.contains) return false;
          if (status == TriState.unknown) {
            if (!includeUnknown) return false;
            sawUnknown = true;
          }
        }
        if (sawUnknown) unknownSoftCollector?.add(recipe.id);
        return true;
      }).toList();
    } else {
      if (!prefs.hasTrackedDietary) return recipes;
      final tracked = prefs.trackedDietary;
      final includeUnknown = prefs.includeUnknownInMenu;
      return recipes.where((recipe) {
        for (final dietary in tracked) {
          final status = MenuAllergenTrust.effectiveDietaryStatus(
            recipe,
            dietary,
          );
          if (status == TriState.contains) return false;
          if (!includeUnknown && status == TriState.unknown) return false;
        }
        return true;
      }).toList();
    }
  }
}
