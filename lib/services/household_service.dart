/// Household service for aggregating allergen preferences across household members.

// lib/services/household_service.dart

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';

/// The household's aggregated allergen preferences PLUS how complete the
/// roster was when they were built (BUT-1663).
///
/// A degraded aggregate is value-identical to a healthy one, so any caller
/// that tells the user something about "the household" — the opt-out safety
/// dialog, the menu-pool telemetry — has to be able to tell them apart.
class HouseholdAllergenAggregate {
  /// Every member resolved; [preferences] describes the household exactly.
  const HouseholdAllergenAggregate.complete(this.preferences)
    : unresolvedMemberIds = const [],
      missingMemberIds = const [],
      isRosterComplete = true;

  /// Every member accounted for, but some ids point at profiles that are not
  /// there (deleted account, stale roster entry). The union is exact for the
  /// members who exist, so the roster counts as COMPLETE — an absent person
  /// cannot be protected, and treating them as unknown-forever would hold the
  /// household in a safety crouch it can never leave (BUT-1663).
  const HouseholdAllergenAggregate.completeWithMissing({
    required this.preferences,
    required this.missingMemberIds,
  }) : unresolvedMemberIds = const [],
       isRosterComplete = true;

  /// At least one member could not be read. [preferences] is the union of the
  /// members that DID resolve, widened with the common-allergen safety floor,
  /// so it is a superset of what is known — never a substitute for it.
  const HouseholdAllergenAggregate.degraded({
    required this.preferences,
    this.unresolvedMemberIds = const [],
    this.missingMemberIds = const [],
  }) : isRosterComplete = false;

  final UserAllergenPreferences preferences;

  /// Member ids whose profile read FAILED on this pass — transient, so the
  /// aggregate fails safe. Empty on the whole-aggregation-failed path, where
  /// no individual member is to blame.
  final List<String> unresolvedMemberIds;

  /// BUT-1663: member ids whose profile document does not exist. Distinct from
  /// [unresolvedMemberIds]: this is a roster-hygiene problem, not an unknown
  /// allergen, so it does NOT degrade filtering.
  final List<String> missingMemberIds;

  final bool isRosterComplete;
}

/// Aggregates allergen preferences across household members for menu planning.
class HouseholdService extends BaseService {
  @override
  String get serviceName => 'HouseholdService';

  /// Common-allergen floor added on top of the resolved union when the roster
  /// is incomplete.
  ///
  /// Allergens ONLY, deliberately: `UserAllergenPreferences.defaults` also
  /// carries `trackedDietary: {vegetarisk, vegansk}`, and the menu's dietary
  /// filter treats a tracked diet as a hard requirement. Folding those in
  /// would silently restrict an omnivore household to vegan dishes — that is
  /// not a safety property, it just empties the menu. Widening the allergen
  /// set only ever removes dishes that might hurt someone.
  static final Set<String> _allergenSafetyFloor =
      UserAllergenPreferences.defaults.trackedAllergens;

  UnifiedFriendsService get _friendsService =>
      ServiceLocator.get<UnifiedFriendsService>();
  UserService get _userService => ServiceLocator.get<UserService>();

  /// Find the household group (first category marked as household).
  FriendCategory? getHousehold() {
    try {
      return _friendsService.categories.categoriesList.firstWhere(
        (c) => c.isHousehold,
      );
    } on StateError {
      return null;
    }
  }

  /// Whether the current user has a household group.
  bool get hasHousehold => getHousehold() != null;

  /// All member IDs in the household (including owner).
  List<String> getHouseholdMemberIds() {
    final household = getHousehold();
    if (household == null) {
      final userId = ServiceLocator.get<UserService>().currentUserProfile?.uid;
      return userId != null ? [userId] : [];
    }
    return household.allMemberIds;
  }

  /// Aggregate allergen preferences across all household members.
  /// - trackedAllergens: UNION (any member's allergy is respected)
  /// - trackedDietary: UNION (any member's restriction is respected)
  /// - includeUnknownInMenu: most conservative (false if ANY member has false)
  ///
  /// Also reports whether every member could be read — a caller that tells the
  /// user something about "the household" must be able to tell a degraded
  /// aggregate from a healthy one.
  Future<HouseholdAllergenAggregate> aggregateAllergenPreferences() async {
    final result = await executeServiceOperation(
      () => _aggregatePreferences(),
      operationName: 'aggregateAllergenPreferences',
    );
    if (result != null) return result;

    // The aggregation itself failed (auth, service wiring). Nothing at all is
    // known about this household, so fall back to the safety floor with the
    // UNKNOWN escape hatch closed — and report the roster as incomplete rather
    // than passing this off as the household's real preferences.
    AppLogger.warning(
      'Household allergen aggregation failed; falling back to the '
      'common-allergen floor with UNKNOWN recipes excluded',
      serviceName,
    );
    return HouseholdAllergenAggregate.degraded(preferences: _floorOnly);
  }

  /// The fallback used whenever nothing reliable is known about the household:
  /// the common-allergen floor, no dietary restrictions, and the UNKNOWN escape
  /// hatch shut so only recipes proven free get through. Kept in one place —
  /// it is the most safety-critical value in this file and two copies would
  /// drift.
  UserAllergenPreferences get _floorOnly => _buildPreferences(
    allergens: _allergenSafetyFloor,
    dietary: const {},
    includeUnknown: false,
  );

  Future<HouseholdAllergenAggregate> _aggregatePreferences() async {
    // BUT-1663: `allMemberIds` is `[ownerId, ...friendUserIds]` and
    // `migrateOwnersAsMembers()` appends the owner INTO `friendUserIds` on
    // every login, so the owner arrives twice for any migrated household.
    // Dedupe before counting: the duplicate inflates the single-member check
    // below and would list the same id twice in the unresolved report.
    final memberIds = getHouseholdMemberIds().toSet().toList();

    // DEFENSIVE, not a live path: both callers gate on `hasHousehold`, and a
    // household's `allMemberIds` always leads with a non-nullable `ownerId`,
    // so this cannot currently be reached. It exists because removing the old
    // single-member early return made "no members" fall through to an empty
    // union with UNKNOWN allowed — every allergen filter silently off, dressed
    // up as a healthy roster. An empty roster is UNKNOWN, never safe.
    if (memberIds.isEmpty) {
      AppLogger.warning(
        'Household roster resolved to no members at all; falling back to the '
        'common-allergen floor with UNKNOWN recipes excluded',
        serviceName,
      );
      return HouseholdAllergenAggregate.degraded(preferences: _floorOnly);
    }

    // Union allergens: if ANY member tracks an allergen, include it
    final unionAllergens = <String>{};
    // Union dietary: if ANY member has a restriction, include it
    final unionDietary = <String>{};
    // Most conservative: false if ANY member has false
    var includeUnknown = true;
    final unresolved = <String>[];
    final missing = <String>[];

    // Resolve every member concurrently. Awaiting one at a time cost N serial
    // round-trips in front of two user-visible waits — menu generation and the
    // allergen opt-out dialog, which shows nothing until this returns. Safe to
    // parallelise: `lookupUserProfile` catches its own errors (so no future
    // rejects), the ids are deduped above, and the accumulators below are two
    // set unions plus an AND-fold, none of which depend on completion order.
    // `Future.wait` preserves input order, so the diagnostic lists still come
    // out in roster order.
    final lookups = await Future.wait(
      memberIds.map(_userService.lookupUserProfile),
    );

    for (var i = 0; i < memberIds.length; i++) {
      final memberId = memberIds[i];
      final lookup = lookups[i];

      // A failed read tells us nothing and may clear on its own — fail safe.
      // A profile that simply is not there is a roster-hygiene problem, not an
      // unknown allergen: nobody is at that seat to protect, and degrading
      // forever would shrink every menu with no way to recover.
      switch (lookup.status) {
        // Either the read failed outright, or the profile loaded while its
        // private settings did not — both leave this member's allergens absent
        // because of a failure, so both fail safe.
        case ProfileLookupStatus.unavailable ||
            ProfileLookupStatus.foundSettingsUnavailable:
          unresolved.add(memberId);
          continue;
        case ProfileLookupStatus.missing:
          missing.add(memberId);
          continue;
        case ProfileLookupStatus.found:
          break;
      }

      final profile = lookup.profile!;
      final prefs = profile.allergenPreferences;
      if (prefs == null) {
        // Two very different situations land here, and only one is a
        // declaration:
        //
        //  - Another account holder. `allergenPreferences` lives in a private
        //    settings sub-doc that only its owner may read (firestore.rules
        //    `allow read: if isOwner(userId)`), and `fetchProfile` merges it
        //    back only for the signed-in user. So it is ALWAYS null here, no
        //    matter what they declared. Keep the common-allergen floor — it is
        //    the only protection this household has until BUT-1663 Part 2
        //    lets members share their list.
        //
        //  - The signed-in user themselves, who really did leave the screen
        //    untouched. That IS a declaration of "no allergies": the app asks
        //    plainly and shows allergen badges on recipes, so guessing four
        //    allergens for them narrows every menu on no evidence.
        //
        // Neither case degrades the roster: both are the normal steady state,
        // not an anomaly, and reporting them as incomplete would permanently
        // exclude unverified recipes and permanently change the opt-out dialog.
        // Read the provenance, not the identity. `settingsMerged` is true only
        // when a settings read actually happened, which the rules permit only
        // for the signed-in user — so it answers "is this null a declaration?"
        // directly. Comparing uids here instead would make the safety property
        // depend on two identity handles agreeing (this one and the lookup's),
        // which is the `currentUserProfile` vs `permissionService` footgun.
        if (!profile.settingsMerged) {
          unionAllergens.addAll(_allergenSafetyFloor);
        }
        continue;
      }
      unionAllergens.addAll(prefs.trackedAllergens);
      unionDietary.addAll(prefs.trackedDietary);
      if (!prefs.includeUnknownInMenu) includeUnknown = false;
    }

    if (unresolved.isEmpty) {
      final preferences = _buildPreferences(
        allergens: unionAllergens,
        dietary: unionDietary,
        includeUnknown: includeUnknown,
      );
      if (missing.isEmpty) {
        return HouseholdAllergenAggregate.complete(preferences);
      }
      AppLogger.warning(
        'Household roster names ${missing.length} member(s) whose profile does '
        'not exist; aggregating the members who do',
        serviceName,
      );
      return HouseholdAllergenAggregate.completeWithMissing(
        preferences: preferences,
        missingMemberIds: missing,
      );
    }

    // Widen, never replace: keep every allergen we DID resolve and add the
    // floor on top, and close the UNKNOWN escape hatch so only recipes proven
    // FREE reach a household we cannot fully see.
    AppLogger.warning(
      'Household roster incomplete (${unresolved.length} member(s) unread); '
      'widening the allergen union with the common-allergen floor',
      serviceName,
    );
    return HouseholdAllergenAggregate.degraded(
      preferences: _buildPreferences(
        allergens: {...unionAllergens, ..._allergenSafetyFloor},
        dietary: unionDietary,
        includeUnknown: false,
      ),
      unresolvedMemberIds: unresolved,
      missingMemberIds: missing,
    );
  }

  UserAllergenPreferences _buildPreferences({
    required Set<String> allergens,
    required Set<String> dietary,
    required bool includeUnknown,
  }) => UserAllergenPreferences(
    trackedAllergens: allergens,
    trackedDietary: dietary,
    includeUnknownInMenu: includeUnknown,
    showOnCards: true,
    showOnDetail: true,
    showCoverage: true,
  );
}
