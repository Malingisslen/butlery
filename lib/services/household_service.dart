/// Household service for aggregating allergen preferences across household members.

import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_allergen_aggregate.dart';
import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/models/profile_lookup.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/household_allergen_share_repository.dart';
import 'package:butlery/services/family/active_household.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';

export 'package:butlery/models/household_allergen_aggregate.dart';

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
  List<String> getHouseholdMemberIds() => _memberIdsOf(getHousehold());

  List<String> _memberIdsOf(FriendCategory? group) {
    if (group == null) {
      final userId = ServiceLocator.get<UserService>().currentUserProfile?.uid;
      return userId != null ? [userId] : [];
    }
    return group.allMemberIds;
  }

  /// The group the active household belongs to (BUT-2267), when this device
  /// has it loaded. It is the roster whose shares that household holds, so
  /// aggregating over any other household-marked group would pair one group's
  /// members with another household's shares.
  FriendCategory? _linkedGroup(Household? household) {
    if (household == null || !household.isLinkedToGroup) return null;
    for (final c in _friendsService.categories.categoriesList) {
      if (c.id == household.sourceGroupId &&
          c.ownerId == household.sourceGroupOwnerId &&
          c.isHousehold) {
        return c;
      }
    }
    return null;
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

  /// The same per-member resolution as [aggregateAllergenPreferences], over
  /// [memberIds] — ACCOUNT holders only — instead of the whole household.
  ///
  /// This is how the who's-eating-today path resolves the present adults: one
  /// implementation of BUT-1663's floor and BUT-1693's shared lists for both
  /// paths, because two copies of a safety rule drift.
  Future<HouseholdAllergenAggregate> aggregateAllergenPreferencesFor(
    Set<String> memberIds,
  ) async {
    final result = await executeServiceOperation(
      () => _resolveMembers(
        memberIds.toList(),
        ActiveHousehold.resolve(serviceName),
      ),
      operationName: 'aggregateAllergenPreferencesFor',
    );
    if (result != null) return result;
    AppLogger.warning(
      'Allergen aggregation for the present members failed; falling back to '
      'the common-allergen floor with UNKNOWN recipes excluded',
      serviceName,
    );
    return HouseholdAllergenAggregate.degraded(preferences: _floorOnly);
  }

  /// What the MENU filters by for the signed-in user alone (BUT-2085,
  /// BUT-1694) — read by the generator AND the opt-out dialog that names what
  /// it stops protecting, so the two cannot drift. Not
  /// [UserService.allergenPreferences], which substitutes `defaults`, diets
  /// included, for an untouched screen; untouched means "no allergies"
  /// (BUT-1663) only when the settings were read, else the floor applies.
  static UserAllergenPreferences ownMenuPreferences(UserProfile? profile) {
    final declared = profile?.allergenPreferences;
    if (declared != null) return declared;
    if (profile?.settingsMerged ?? false) return UserAllergenPreferences.none;
    return _floorOnly;
  }

  /// [base] widened with the common-allergen floor and the UNKNOWN escape
  /// hatch shut — the answer for a set of diners this device could not read.
  /// Dietary choices pass through untouched, for the reason given on
  /// [_allergenSafetyFloor].
  static UserAllergenPreferences widenWithSafetyFloor(
    UserAllergenPreferences base,
  ) => _buildPreferences(
    allergens: {...base.trackedAllergens, ..._allergenSafetyFloor},
    dietary: base.trackedDietary,
    includeUnknown: false,
  );

  /// The fallback used whenever nothing reliable is known about the household:
  /// the common-allergen floor, no dietary restrictions, and the UNKNOWN escape
  /// hatch shut so only recipes proven free get through. Kept in one place —
  /// it is the most safety-critical value in this file and two copies would
  /// drift.
  static UserAllergenPreferences get _floorOnly => _buildPreferences(
    allergens: _allergenSafetyFloor,
    dietary: const {},
    includeUnknown: false,
  );

  /// Every household member who has SHARED their own allergen list, keyed by
  /// uid (BUT-1693). These replace the safety floor for exactly those members —
  /// they never override a member whose real preferences this device can
  /// already read, and they never add the floor on top of themselves.
  ///
  /// Returns null when the shares could not be determined at all. That is NOT
  /// the same as "nobody shared": treating a failed read as an empty result
  /// would drop every real declaration and quietly hand those members the floor
  /// while reporting the roster as healthy — the exact
  /// unreadable-looks-like-a-declaration bug BUT-1663 exists to prevent. A
  /// household too large for the share read to answer is one of these
  /// (`HouseholdTooLargeForSharesException`): its members get the floor.
  Future<Map<String, HouseholdAllergenShare>?> _sharedListsByMember(
    Future<ActiveHousehold> activeHousehold,
  ) async {
    final active = await activeHousehold;
    if (!active.known) return null;
    if (!active.sharingOn) return const {};
    // Shares are scoped to the SYMMETRIC `households/{id}` roster, not to the
    // owner-scoped FriendCategory household this service aggregates over —
    // the two are different concepts and a category id passed here would
    // match nothing and silently return no shares (ADR-0005 D1).
    final household = active.household;
    if (household == null) return const {};
    final shareRepository =
        ServiceLocator.tryGet<HouseholdAllergenShareRepository>();
    if (shareRepository == null) return null;

    try {
      final shares = await shareRepository.getByHousehold(household.id);
      // `isValidConsent` is the model's contract for "may this count as a
      // declaration at all". getByHousehold already filters on it; re-checked
      // here because this service holds the INTERFACE, whose other reads do not
      // all filter, and the precondition belongs beside the code that acts on
      // it (GDPR Art. 9(2)(a)).
      return {
        for (final share in shares)
          if (share.isValidConsent) share.userId: share,
      };
    } catch (e) {
      AppLogger.warning(
        'Could not read the shared allergen lists for this household: $e',
        serviceName,
      );
      return null;
    }
  }

  Future<HouseholdAllergenAggregate> _aggregatePreferences() async {
    final active = ActiveHousehold.resolve(serviceName);
    final household = (await active).household;
    // The group linked to the household whose shares are read. When that
    // group is not in this device's category list, the household's own roster
    // stands in; with no link, the first household-marked group.
    final linked = _linkedGroup(household);
    final memberIds =
        linked == null && household != null && household.isLinkedToGroup
        ? household.memberUserIds
        : _memberIdsOf(linked ?? getHousehold());
    // BUT-1663: `allMemberIds` is `[ownerId, ...friendUserIds]` and
    // `migrateOwnersAsMembers()` appends the owner INTO `friendUserIds` on
    // every login, so the owner arrives twice for any migrated household.
    // Dedupe before counting: the duplicate would list the same id twice in
    // the unresolved report.
    return _resolveMembers(memberIds.toSet().toList(), active);
  }

  Future<HouseholdAllergenAggregate> _resolveMembers(
    List<String> memberIds,
    Future<ActiveHousehold> activeHousehold,
  ) async {
    // This check exists because removing the old
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
    // rejects), and the accumulators below are two
    // set unions plus an AND-fold, none of which depend on completion order.
    // `Future.wait` preserves input order, so the diagnostic lists still come
    // out in roster order.
    // Started before the lookups rather than after them: it depends on none of
    // them, and awaiting it afterwards would put its round trips in front of a
    // user-visible wait for no reason.
    final sharesFuture = _sharedListsByMember(activeHousehold);
    final lookups = await Future.wait(
      memberIds.map(_userService.lookupUserProfile),
    );

    // BUT-1693: the members who chose to be read instead of guessed at. NULL
    // means the shares could not be determined, which is NOT the same as
    // "nobody shared" — see [sharesUnavailable] at the end of this method.
    final sharedLists = await sharesFuture;
    final sharesUnavailable = sharedLists == null;

    // The same handle the share read used, read again here. NOT
    // `currentUserProfile`: a profile that is already null would leave `selfId`
    // null and let the signed-in user's own share stand in for the real
    // settings their device can read — the one substitution this feature must
    // never make. A sign-out BETWEEN the two reads still nulls it; the window
    // is a single aggregation and the outcome is their own data, so it is
    // accepted rather than plumbed.
    final selfId = ServiceLocator.tryGet<PermissionService>()?.currentUserId;

    for (var i = 0; i < memberIds.length; i++) {
      final memberId = memberIds[i];
      final lookup = lookups[i];

      // A member's own shared list, if they have one. Never for the signed-in
      // user: their own device reads their real settings, and no share written
      // about them may stand in for that.
      final shared = memberId == selfId ? null : sharedLists?[memberId];
      // Applied unless the profile is KNOWN TO BE ABSENT — a failed read
      // leaves existence unknown, which is not the same thing. BUT-1663
      // decided that an absent person cannot be protected and must not shrink
      // the menu; a share left behind by a deleted account is exactly that
      // person, and letting it filter would restore the crouch that entry
      // declined. The exclusion lives at the CALL SITES below, not in this
      // closure — nothing inside it enforces the `missing` case.
      void applyShare() {
        if (shared == null) return;
        unionAllergens.addAll(shared.trackedAllergens);
        unionDietary.addAll(shared.trackedDietary);
        if (!shared.includeUnknownInMenu) includeUnknown = false;
      }

      // A failed read tells us nothing and may clear on its own — fail safe.
      // A profile that simply is not there is a roster-hygiene problem, not an
      // unknown allergen: nobody is at that seat to protect, and degrading
      // forever would shrink every menu with no way to recover.
      switch (lookup.status) {
        // Either the read failed outright, or the profile loaded while its
        // private settings did not — both leave this member's allergens absent
        // because of a failure, so both fail safe.
        //
        // A share still CONTRIBUTES (`applyShare()` below) but does not
        // cancel the degradation.
        case ProfileLookupStatus.unavailable ||
            ProfileLookupStatus.foundSettingsUnavailable:
          applyShare();
          unresolved.add(memberId);
          continue;
        case ProfileLookupStatus.missing:
          missing.add(memberId);
          continue;
        case ProfileLookupStatus.found:
          applyShare();
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
        //    the only protection this household has until that member SHARES
        //    their list (BUT-1693, checked just below). With the sharing flag
        //    off that is still every other account holder.
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
        // BUT-1693: unless they SHARED, in which case their real list is
        // already in the union above and guessing on top of it would put four
        // allergens back that they have told the household they do not have.
        if (!profile.settingsMerged && shared == null) {
          unionAllergens.addAll(_allergenSafetyFloor);
        }
        continue;
      }
      unionAllergens.addAll(prefs.trackedAllergens);
      unionDietary.addAll(prefs.trackedDietary);
      if (!prefs.includeUnknownInMenu) includeUnknown = false;
    }

    // Nobody but the signed-in user is on this roster, so no share could have
    // been missed and an unreadable read lost no information. Degrading here
    // would put the four-allergen floor and the menu warning on a household
    // that has nothing to tell us — the same principle as the flag-off path.
    final othersOnRoster = memberIds.any((id) => id != selfId);

    if (sharesUnavailable && othersOnRoster) {
      // The shared lists could not be read at all. Some member may have shared
      // one that this menu is now filtering without — so the household is NOT
      // fully known, and saying so is what puts BUT-1685's warning on the menu.
      AppLogger.warning(
        'Household shared allergen lists could not be read; widening with the '
        'common-allergen floor and reporting the roster as incomplete',
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

  static UserAllergenPreferences _buildPreferences({
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
