// lib/services/menu/present_diner_prefs_resolver.dart

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/repositories/interfaces/diner_profile_repository.dart';
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
              preferences: HouseholdService.widenWithSafetyFloor(
                UserAllergenPreferences.none,
              ),
            )
          : await householdService.aggregateAllergenPreferencesFor(
              presentAccounts,
            );
    }

    final folded = _foldDiners(
      accounts?.preferences ?? UserAllergenPreferences.none,
      presentDiners.map((d) => d.allergenPreferences),
    );
    return PresentDinerPrefs(
      folded.prefs,
      isComplete: accounts?.isRosterComplete ?? true,
    );
  }

  /// [base] with every diner's preferences folded in: allergens and diets
  /// unioned, and one cautious diner makes the whole meal cautious. Null =
  /// a diner who recorded none, so it contributes nothing.
  static ({UserAllergenPreferences prefs, bool contributed}) _foldDiners(
    UserAllergenPreferences base,
    Iterable<UserAllergenPreferences?> diners,
  ) {
    final allergens = {...base.trackedAllergens};
    final dietary = {...base.trackedDietary};
    var includeUnknown = base.includeUnknownInMenu;
    var contributed = false;
    for (final prefs in diners) {
      if (prefs == null) continue;
      contributed = true;
      allergens.addAll(prefs.trackedAllergens);
      dietary.addAll(prefs.trackedDietary);
      if (!prefs.includeUnknownInMenu) includeUnknown = false;
    }
    return (
      prefs: UserAllergenPreferences(
        trackedAllergens: allergens,
        trackedDietary: dietary,
        includeUnknownInMenu: includeUnknown,
      ),
      contributed: contributed,
    );
  }

  /// [base] plus every diner profile in the signed-in user's household — the
  /// whole-household path's counterpart to [resolve]. A child exists only as a
  /// diner profile, so a union of ACCOUNTS alone leaves their allergens out of
  /// every menu.
  ///
  /// Only ever adds: diners widen the union, never narrow it, so this cannot
  /// shrink filtering below [base]. Null when the path cannot run at all
  /// (services not wired, signed out) — the caller then keeps [base]. A read
  /// that FAILS returns [base] widened with the safety floor, never [base]
  /// alone (BUT-1663).
  Future<({PresentDinerPrefs prefs, bool changed})?> addHouseholdDiners(
    UserAllergenPreferences base,
  ) async {
    final householdRepo = ServiceLocator.tryGet<HouseholdRepository>();
    final dinerRepo = ServiceLocator.tryGet<DinerProfileRepository>();
    final permission = ServiceLocator.tryGet<PermissionService>();
    if (householdRepo == null || dinerRepo == null || permission == null) {
      return null;
    }
    final uid = permission.currentUserId;
    if (uid == null) return null;

    final List<DinerProfile> diners;
    try {
      final households = await householdRepo.getForUser(uid);
      diners = households.isEmpty
          ? const []
          : await dinerRepo.getByHousehold(households.first.id);
    } catch (e) {
      AppLogger.warning('Household diner profile read failed: $e');
      return (
        prefs: PresentDinerPrefs(
          HouseholdService.widenWithSafetyFloor(base),
          isComplete: false,
        ),
        changed: true,
      );
    }

    // The read returned, so a diner with no preferences recorded none — a
    // declaration, not an unreadable member.
    final folded = _foldDiners(base, diners.map((d) => d.allergenPreferences));
    if (!folded.contributed) {
      return (prefs: PresentDinerPrefs(base, isComplete: true), changed: false);
    }
    return (
      prefs: PresentDinerPrefs(folded.prefs, isComplete: true),
      changed: true,
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
      base = UserAllergenPreferences.none;
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
}
