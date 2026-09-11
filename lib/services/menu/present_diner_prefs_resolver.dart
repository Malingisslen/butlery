// lib/services/menu/present_diner_prefs_resolver.dart

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/household_repository.dart';
import 'package:butlery/services/family/household_roster_service.dart';
import 'package:butlery/services/household_service.dart';
import 'package:butlery/services/permission_service.dart';

/// The allergen preferences of the diners eating a given meal, plus whether
/// every one of them was actually known.
class PresentDinerPrefs {
  const PresentDinerPrefs(this.preferences, {required this.isComplete});

  final UserAllergenPreferences preferences;

  /// False when [preferences] is a widened, safety-floored stand-in for
  /// diners this device could not read (BUT-2076).
  final bool isComplete;
}

/// Resolves the who's-eating-today allergen union for the menu generator.
///
/// Present ACCOUNT holders go through [HouseholdService]'s per-member
/// resolution, so the BUT-1663 floor and BUT-1693 shared lists apply here
/// exactly as on the whole-household path. Present diner profiles contribute
/// their own preferences from the roster: a roster read that returns at all
/// has read every diner document, so a diner without preferences is one that
/// recorded none, not one we failed to read.
class PresentDinerPrefsResolver {
  const PresentDinerPrefsResolver();

  /// Null only when the present path cannot run at all (services not wired,
  /// signed out, or this user has no household) — the caller then falls back
  /// to its whole-household filtering. A failure to READ never returns null.
  Future<PresentDinerPrefs?> resolve(List<String> presentIds) async {
    final rosterService = ServiceLocator.tryGet<HouseholdRosterService>();
    final householdRepo = ServiceLocator.tryGet<HouseholdRepository>();
    final permission = ServiceLocator.tryGet<PermissionService>();
    if (rosterService == null || householdRepo == null || permission == null) {
      return null;
    }
    final uid = permission.currentUserId;
    if (uid == null) return null;

    final List<HouseholdRosterMember>? roster;
    try {
      // Read-only: `getForUser`, never `ensureForUser`.
      final households = await householdRepo.getForUser(uid);
      if (households.isEmpty) return null;
      roster = await rosterService.tryGetRoster(households.first.id);
    } catch (e) {
      AppLogger.warning('Present-diner roster read failed: $e');
      return _unreadable(uid);
    }
    if (roster == null) return _unreadable(uid);

    final present = presentIds.toSet();
    final presentAccounts = <String>{};
    final presentDiners = <HouseholdRosterMember>[];
    for (final member in roster) {
      if (!present.contains(member.memberId)) continue;
      if (member.isUser) {
        presentAccounts.add(member.memberId);
      } else {
        presentDiners.add(member);
      }
    }
    // Nobody we were asked about is on the roster we read, so the union would
    // be empty — an unfiltered menu for people we know are eating.
    if (presentAccounts.isEmpty && presentDiners.isEmpty) {
      return _unreadable(uid);
    }

    HouseholdAllergenAggregate? accounts;
    if (presentAccounts.isNotEmpty) {
      final householdService = ServiceLocator.tryGet<HouseholdService>();
      accounts = householdService == null
          ? HouseholdAllergenAggregate.degraded(
              preferences: HouseholdService.widenWithSafetyFloor(_noAllergens),
            )
          : await householdService.aggregateAllergenPreferencesFor(
              presentAccounts,
            );
    }

    final allergens = <String>{...?accounts?.preferences.trackedAllergens};
    final dietary = <String>{...?accounts?.preferences.trackedDietary};
    // One cautious diner makes the whole meal cautious.
    var includeUnknown = accounts?.preferences.includeUnknownInMenu ?? true;
    for (final diner in presentDiners) {
      final prefs = diner.allergenPreferences;
      if (prefs == null) continue;
      allergens.addAll(prefs.trackedAllergens);
      dietary.addAll(prefs.trackedDietary);
      if (!prefs.includeUnknownInMenu) includeUnknown = false;
    }
    return PresentDinerPrefs(
      UserAllergenPreferences(
        trackedAllergens: allergens,
        trackedDietary: dietary,
        includeUnknownInMenu: includeUnknown,
      ),
      isComplete: accounts?.isRosterComplete ?? true,
    );
  }

  /// We know people are eating but not who they are. The household union
  /// alone would drop a present child's diner profile.
  ///
  /// Never `UserService.allergenPreferences`: it falls back to
  /// `UserAllergenPreferences.defaults`, whose diets would make an unset
  /// profile a vegan-only menu — the thing BUT-1663 keeps out of the floor.
  Future<PresentDinerPrefs> _unreadable(String uid) async {
    final householdService = ServiceLocator.tryGet<HouseholdService>();
    final UserAllergenPreferences base;
    if (householdService == null) {
      base = _noAllergens;
    } else if (householdService.hasHousehold) {
      base =
          (await householdService.aggregateAllergenPreferences()).preferences;
    } else {
      base = (await householdService.aggregateAllergenPreferencesFor({
        uid,
      })).preferences;
    }
    return PresentDinerPrefs(
      HouseholdService.widenWithSafetyFloor(base),
      isComplete: false,
    );
  }

  static const _noAllergens = UserAllergenPreferences(
    trackedAllergens: {},
    trackedDietary: {},
  );
}
