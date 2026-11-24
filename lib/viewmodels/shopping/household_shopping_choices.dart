import 'package:clock/clock.dart';

import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/family/active_household.dart';
import 'package:butlery/services/family/household_links.dart';

/// The allergen choices the shopping-list reminder counts for the person
/// looking at the list (BUT-2494), read on their device and kept in memory.
///
/// Deliberately NOT the menu's household resolution (`resolveHousehold`):
/// that one widens an unreadable member with the common-allergen floor, which
/// is right for a menu that must stay safe and wrong for a reminder, where a
/// guessed allergen would put boxes on half the list. Here a source that
/// cannot be read simply contributes nothing.
class HouseholdShoppingChoices {
  HouseholdShoppingChoices({
    required HouseholdLinks links,
    required UserProfile? Function() ownProfile,
    this.includeDinerProfiles = true,
  }) : _links = links,
       _ownProfile = ownProfile;

  final HouseholdLinks _links;
  final UserProfile? Function() _ownProfile;

  /// Children's and guests' profiles count only under the v2 guardian consent
  /// that names the shopping list (ADR-0044); off in tests that isolate the
  /// share path.
  final bool includeDinerProfiles;

  static const Duration cacheFor = Duration(minutes: 10);
  static const String _logTag = 'HouseholdShoppingChoices';

  /// Only what was read from Firestore. The viewer's own settings are in
  /// memory already and are added fresh on every [load], so a profile that
  /// merges or changes shows on the next open.
  static ({String uid, DateTime at, Set<String> choices})? _cache;

  /// Drops the cached answer, so the next [load] reads again.
  static void forget() => _cache = null;

  Future<Set<String>> load() async {
    final uid = _links.currentUserId();
    if (uid == null) return const {};
    final cached = _cache;
    if (cached != null &&
        cached.uid == uid &&
        clock.now().difference(cached.at) < cacheFor) {
      return {..._ownChoices(uid), ...cached.choices};
    }

    final shared = await _sharedChoices(uid);
    final diners = includeDinerProfiles
        ? await _dinerChoices(uid)
        : const <String>{};
    final household = <String>{...?shared, ...?diners};

    // A failed read is not cached, so the next open tries again; an answer
    // for an account that signed out meanwhile is not kept either.
    if (shared != null && diners != null && _links.currentUserId() == uid) {
      _cache = (
        uid: uid,
        at: clock.now(),
        choices: Set.unmodifiable(household),
      );
    }
    return {..._ownChoices(uid), ...household};
  }

  /// The signed-in user's own settings, only when they were actually read:
  /// an unread profile is not "no allergies" and not the defaults either.
  Set<String> _ownChoices(String uid) {
    final profile = _ownProfile();
    if (profile == null || profile.uid != uid || !profile.settingsMerged) {
      return const {};
    }
    return profile.allergenPreferences?.trackedAllergens ?? const {};
  }

  /// Other members' shared lists, counted only under a consent that named the
  /// shopping list. Null when the read failed.
  Future<Set<String>?> _sharedChoices(String uid) async {
    final active = await ActiveHousehold.resolve(_logTag, _links);
    if (active.readFailed) return null;
    final household = active.household;
    final repository = _links.allergenShares();
    if (!active.sharingOn || household == null || repository == null) {
      return const {};
    }
    try {
      final shares = await repository.getByHousehold(household.id);
      return {
        for (final share in shares)
          if (share.userId != uid && share.coversShoppingList)
            ...share.trackedAllergens,
      };
    } catch (e) {
      // HouseholdTooLargeForSharesException lands here too: no shares counted.
      AppLogger.warning('Could not read shared allergen lists: $e', _logTag);
      return null;
    }
  }

  Future<Set<String>?> _dinerChoices(String uid) async {
    final households = _links.households();
    final diners = _links.dinerProfiles();
    if (households == null || diners == null) return const {};
    try {
      return {
        for (final household in await households.eatingHouseholdsFor(uid))
          for (final diner in await diners.getByHousehold(household.id))
            if (diner.allergensCoverShoppingList)
              ...?diner.allergenPreferences?.trackedAllergens,
      };
    } catch (e) {
      AppLogger.warning('Could not read diner profiles: $e', _logTag);
      return null;
    }
  }
}
