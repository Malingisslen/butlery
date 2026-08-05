/// Intent-driven unit tests for [SocialRecipeSharingService] (Intent-Test
/// Sprint 2026-05-24, batch 12 — sharing-privacy bug terrain).
///
/// Behaviours pinned (one sentence each):
/// - auth gate: every public mutation (`shareRecipeWithUsers`,
///   `shareRecipeWithGroups`, `unshareRecipe`) refuses without a current uid
///   and sets a localised error before any repo touch.
/// - owner-only sharing: a non-owner / non-creator cannot share someone else's
///   recipe — the only path to bypass is `createdBy == uid` OR
///   `socialData.ownerId == uid`.
/// - owner-only unsharing: only `socialData.ownerId` can unshare; a member
///   with `admin` ResourcePermission cannot.
/// - first-share converts personal → collaborative and seeds owner as admin
///   regardless of the `permission` argument passed in (admin escalation guard).
/// - re-share onto existing collaborative recipe merges into
///   `memberPermissions` (no clobber of unrelated members) and updates the
///   existing member's role to the new permission.
/// - share-cap (BUT-955): union of {owner, existing members, new userIds}
///   over `Recipe.maxSharesPerRecipe` is rejected pre-write, no recipe save,
///   no shared_recipes write.
/// - share-cap dedup contract: re-sharing with users who are already members
///   doesn't double-count toward the cap.
/// - data-scope: the SharedRecipe doc written to the secondary collection
///   carries only `sharedByUserId` + `sharedByDisplayName`, never the
///   sender's email/phone (GDPR minimisation).
/// - secondary-write self-heal (BUT-1503, supersedes BUT-1131): the secondary
///   `shared_recipes` write is retried with bounded backoff; a transient
///   failure that succeeds on retry lands exactly one doc and returns true,
///   but a failure that persists across all retries surfaces as `false` +
///   setError (never a phantom success — the recipient finds the share only
///   via this doc). The primary recipe-save still wins and the UI is notified.
/// - if the primary save fails, NO secondary write happens (no orphan
///   shared_recipes doc), and the operation returns false.
/// - unshareRecipe wipes `socialData` entirely (memberPermissions, owner,
///   flags) — a half-unshared recipe must not exist.
/// - group-share resolves friend-category members via UnifiedFriendsService,
///   excludes the sharer's own uid (no self-share), and refuses when the
///   resolved set is empty.
/// - throwing collaborator (saveRecipe throws / getRecipe throws) is caught,
///   no rethrow, `false` returned, error set.
/// - read-only queries (`isRecipeShared`, `getSharedUsers`) never throw
///   even when the underlying loader throws.
///
/// Production bugs spotted while writing these tests are NOT fixed here —
/// they are flagged in the report-back at the end of the session.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/firebase_shared_recipe_repository.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_sharing_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';

// -------------------- Fakes ------------------------------------------------

/// Records every `createSharedRecipe` call + lets the test program a throw.
class _FakeSharedRecipeRepo extends Fake
    implements FirebaseSharedRecipeRepository {
  final List<({SharedRecipe doc, List<String> recipientIds})> calls = [];

  /// When set, EVERY call throws this (models a persistent failure).
  Object? throwOnCreate;

  /// When > 0, the first N attempts throw [transientError] then subsequent
  /// calls succeed (models a transient failure that self-heals on retry).
  int failFirstNAttempts = 0;
  Object transientError = Exception('transient shared_recipes write failure');
  int attemptCount = 0;

  @override
  Future<String> createSharedRecipe(
    SharedRecipe sharedRecipe, {
    required List<String> recipientIds,
  }) async {
    attemptCount++;
    if (throwOnCreate != null) throw throwOnCreate!;
    if (attemptCount <= failFirstNAttempts) throw transientError;
    calls.add((doc: sharedRecipe, recipientIds: recipientIds));
    return sharedRecipe.id;
  }
}

/// Minimal Fake for `UnifiedFriendsService` exposing only the two surfaces
/// the production code touches: `getCategoryByIdInternal(id)` and `friends`.
/// Anything else throws loudly so we notice if the production contract drifts.
class _FakeFriendsService extends Fake implements UnifiedFriendsService {
  final Map<String, FriendCategory> categoriesById = {};
  final List<UserProfile> friendsSeed = [];

  @override
  FriendCategory? getCategoryByIdInternal(String categoryId) =>
      categoriesById[categoryId];

  @override
  List<UserProfile> get friends => friendsSeed;
}

// -------------------- Test harness ---------------------------------------

class _Harness {
  _Harness({
    String? currentUserId = 'me-uid',
    String? displayName = 'Anna',
    bool saveSucceeds = true,
    Object? throwOnSave,
    Object? throwOnGet,
  }) : _currentUserId = currentUserId,
       _displayName = displayName,
       _saveSucceeds = saveSucceeds,
       _throwOnSave = throwOnSave,
       _throwOnGet = throwOnGet;

  String? _currentUserId;
  String? _displayName;
  bool _saveSucceeds;
  Object? _throwOnSave;
  Object? _throwOnGet;

  final Map<String, Recipe> store = {};
  final List<Recipe> saved = [];
  final List<String> errors = [];
  int notifications = 0;
  final repo = _FakeSharedRecipeRepo();

  void setUserId(String? uid) => _currentUserId = uid;
  void setDisplayName(String? n) => _displayName = n;
  void setSaveSucceeds(bool v) => _saveSucceeds = v;
  void setThrowOnSave(Object? e) => _throwOnSave = e;
  void setThrowOnGet(Object? e) => _throwOnGet = e;

  void seed(Recipe r) => store[r.id] = r;

  SocialRecipeSharingService build() {
    return SocialRecipeSharingService(
      getCurrentUserId: () => _currentUserId,
      getCurrentUserDisplayName: () => _displayName,
      setError: errors.add,
      notifyListeners: () => notifications++,
      getRecipe: (id) async {
        if (_throwOnGet != null) throw _throwOnGet!;
        return store[id];
      },
      saveRecipe: (recipe) async {
        if (_throwOnSave != null) throw _throwOnSave!;
        if (!_saveSucceeds) return false;
        saved.add(recipe);
        store[recipe.id] = recipe;
        return true;
      },
      sharedRecipeRepository: repo,
    );
  }
}

// -------------------- ServiceLocator wiring for group tests --------------

/// Wires a `_FakeFriendsService` into the global GetIt instance so
/// `ServiceLocator.get<UnifiedFriendsService>()` (called from the production
/// `_resolveGroupMembers`) resolves to our fake. Both production and test
/// ServiceLocators share `GetIt.instance`, so direct registration is enough.
void _registerFakeFriendsService(_FakeFriendsService fake) {
  final g = GetIt.instance;
  if (g.isRegistered<UnifiedFriendsService>()) {
    g.unregister<UnifiedFriendsService>();
  }
  g.registerSingleton<UnifiedFriendsService>(fake);
  prod.ServiceLocator.initialize(DIContainer());
}

void _unregisterFakeFriendsService() {
  final g = GetIt.instance;
  if (g.isRegistered<UnifiedFriendsService>()) {
    g.unregister<UnifiedFriendsService>();
  }
  prod.ServiceLocator.reset();
}

// -------------------- Recipe fixtures -------------------------------------

Recipe _personal({
  String id = 'r1',
  String createdBy = 'me-uid',
}) {
  // Construct via RecipeCore so we can pin a deterministic id (the public
  // Recipe.personal factory generates a fresh uuid).
  final core = RecipeCore(
    id: id,
    title: 'Pannkakor',
    description: 'Tunna',
    ingredients: const ['ägg', 'mjöl'],
    instructions: const ['rör', 'stek'],
    imageUrls: const ['https://x/y.jpg'],
    mealType: 'Middag',
    portions: 4,
    timeMinutes: 20,
    createdBy: createdBy,
  );
  return Recipe(core: core, type: RecipeType.personal);
}

Recipe _collaborative({
  String id = 'r1',
  String ownerId = 'me-uid',
  Map<String, ResourcePermission>? members,
  Map<String, List<String>>? grants,
  List<String>? categoryIds,
}) {
  final core = RecipeCore(
    id: id,
    title: 'Pannkakor',
    description: 'Tunna',
    ingredients: const ['ägg', 'mjöl'],
    instructions: const ['rör', 'stek'],
    imageUrls: const ['https://x/y.jpg'],
    mealType: 'Middag',
    portions: 4,
    timeMinutes: 20,
    createdBy: ownerId,
  );
  return Recipe(
    core: core,
    type: RecipeType.collaborative,
    socialData: RecipeSocialData(
      ownerId: ownerId,
      ownerDisplayName: 'Anna',
      memberPermissions:
          members ??
          {
            ownerId: ResourcePermission.admin,
            'friend-A': ResourcePermission.editor,
          },
      allowGuestViewing: false,
      allowMemberInvites: true,
      grants: grants,
      categoryIds: categoryIds,
    ),
  );
}

// -------------------- Tests ----------------------------------------------

void main() {
  group('shareRecipeWithUsers — auth + permission gates', () {
    /// Proves unauthenticated callers can't share — short-circuits before any
    /// repo or saveRecipe touch.
    test(
      'unauthenticated → false, no save, no secondary write, error set',
      () async {
        final h = _Harness(currentUserId: null);
        h.seed(_personal(id: 'r1'));
        final svc = h.build();

        final ok = await svc.shareRecipeWithUsers('r1', [
          'friend-A',
        ], ResourcePermission.editor);

        expect(ok, RecipeShareResult.failed);
        expect(h.saved, isEmpty);
        expect(h.repo.calls, isEmpty);
        expect(h.errors, isNotEmpty);
        expect(h.notifications, 0);
      },
    );

    /// Proves a missing recipe id can't be shared (would otherwise crash on
    /// `recipe.copyWith` when the loader returns null).
    test('recipe not found → false, no save, no secondary write', () async {
      final h = _Harness();
      // store is empty — getRecipe returns null
      final svc = h.build();

      final ok = await svc.shareRecipeWithUsers('missing', [
        'friend-A',
      ], ResourcePermission.editor);

      expect(ok, RecipeShareResult.failed);
      expect(h.saved, isEmpty);
      expect(h.repo.calls, isEmpty);
    });

    /// CRITICAL PRIVACY GATE: a stranger (not the creator, not the owner)
    /// must not be able to share someone else's personal recipe. If this
    /// test fails, anyone with the recipe id can grant themselves and
    /// others edit access.
    test(
      'non-owner non-creator cannot share recipe → false, no save',
      () async {
        final h = _Harness(currentUserId: 'stranger-uid');
        h.seed(_personal(id: 'r1', createdBy: 'real-owner-uid'));
        final svc = h.build();

        final ok = await svc.shareRecipeWithUsers('r1', [
          'victim-uid',
        ], ResourcePermission.admin);

        expect(
          ok,
          RecipeShareResult.failed,
          reason:
              'a stranger sharing someone else\'s recipe is a privilege '
              'escalation — must be refused',
        );
        expect(h.saved, isEmpty);
        expect(
          h.repo.calls,
          isEmpty,
          reason: 'no shared_recipes doc should be created when refused',
        );
        expect(h.errors, isNotEmpty);
      },
    );

    /// Proves the creator can share their own personal recipe (positive
    /// path of the permission gate).
    test('creator of personal recipe can share it', () async {
      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_personal(id: 'r1', createdBy: 'me-uid'));
      final svc = h.build();

      final ok = await svc.shareRecipeWithUsers('r1', [
        'friend-A',
      ], ResourcePermission.editor);

      expect(ok, RecipeShareResult.full);
      expect(h.saved, hasLength(1));
    });

    /// Proves a collaborative-recipe owner can re-share even when they are
    /// not the original `createdBy` (the OR branch in the permission check).
    test('socialData.ownerId can share even if createdBy differs', () async {
      final h = _Harness(currentUserId: 'owner-uid');
      // createdBy is some other uid but socialData.ownerId == current user
      final r = _collaborative(
        id: 'r1',
        ownerId: 'owner-uid',
        members: {'owner-uid': ResourcePermission.admin},
      );
      h.seed(r);
      final svc = h.build();

      final ok = await svc.shareRecipeWithUsers('r1', [
        'friend-A',
      ], ResourcePermission.editor);

      expect(ok, RecipeShareResult.full);
    });
  });

  group('shareRecipeWithUsers — first-share converts personal to '
      'collaborative', () {
    /// Pinned contract: the FIRST share of a personal recipe converts it
    /// to collaborative AND seeds the owner with `admin` regardless of the
    /// `permission` arg. A bug here would either (a) skip the conversion
    /// and leave the recipe stuck as personal, or (b) escalate the new
    /// users to admin instead of the requested viewer/editor role.
    test('first share: type=collaborative, owner=admin, members get requested '
        'permission', () async {
      final h = _Harness(currentUserId: 'me-uid', displayName: 'Anna');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      final ok = await svc.shareRecipeWithUsers('r1', [
        'friend-A',
        'friend-B',
      ], ResourcePermission.viewer);

      expect(ok, RecipeShareResult.full);
      expect(h.saved, hasLength(1));
      final saved = h.saved.single;
      expect(saved.type, RecipeType.collaborative);
      expect(saved.socialData?.ownerId, 'me-uid');
      expect(saved.socialData?.ownerDisplayName, 'Anna');
      final perms = saved.socialData!.memberPermissions!;
      expect(
        perms['me-uid'],
        ResourcePermission.admin,
        reason:
            'owner must always be admin regardless of `permission` arg — '
            'never escalate new members to admin in the seed step',
      );
      expect(perms['friend-A'], ResourcePermission.viewer);
      expect(perms['friend-B'], ResourcePermission.viewer);
    });

    /// BUT-1797, the FIRST-share twin of 'a share whose recipient list contains
    /// the sharer keeps their admin'. That one covers the already-collaborative
    /// branch; this one covers `forShare(excludeUserId:)` on the conversion
    /// branch, where the permission half is safe for a different reason (the
    /// owner's `admin` is written AFTER the loop) and the grant half is not.
    /// Drop `excludeUserId` here and the owner acquires a revocable reason of
    /// their own — a sharee row in the panel offering to un-share the owner
    /// from their own recipe. Nothing else in the suite reaches it: the group
    /// path strips self upstream, so its assertions hold for that reason.
    test('a first share that includes the sharer gives them no revocable '
        'reason', () async {
      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      await svc.shareRecipeWithUsers('r1', [
        'me-uid',
        'friend-B',
      ], ResourcePermission.viewer);

      final social = h.saved.single.socialData!;
      expect(social.grants?.containsKey('me-uid'), isFalse);
      expect(
        social.grants?['friend-B'],
        [RecipeSocialData.directGrant],
        reason: 'control: the loop ran, so the absence above is the exclusion',
      );
      expect(social.memberPermissions?['me-uid'], ResourcePermission.admin);
    });

    /// Proves the SharedRecipe doc written to the secondary collection
    /// carries `sharedByUserId` = current user AND the recipient list AND
    /// nothing more sensitive than display name.
    test('first share: secondary write carries minimal sender PII', () async {
      final h = _Harness(currentUserId: 'me-uid', displayName: 'Anna');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      await svc.shareRecipeWithUsers('r1', [
        'friend-A',
      ], ResourcePermission.editor);

      expect(h.repo.calls, hasLength(1));
      final call = h.repo.calls.single;
      expect(call.doc.sharedByUserId, 'me-uid');
      expect(call.doc.sharedByDisplayName, 'Anna');
      expect(call.recipientIds, ['friend-A']);
      // GDPR / data-scope. Every recipient can read this document, so a field
      // carrying contact details would leak on every share. The previous version
      // of this comment promised "an explicit pin" and then delivered prose —
      // this is the assertion it claimed.
      final keys = call.doc.toFirestore().keys.map((k) => k.toLowerCase());
      expect(
        keys.where(
          (k) =>
              k.contains('email') ||
              k.contains('phone') ||
              k.contains('mail') ||
              k.contains('tel'),
        ),
        isEmpty,
        reason:
            'a new contact-shaped field on SharedRecipe must be a deliberate '
            'decision, not something that ships because nothing looked',
      );
    });

    /// Proves allowCollaboration mirrors the permission arg: editor/admin
    /// → true, viewer → false. A bug shape here would be inverted polarity
    /// granting collab to viewers (and vice-versa).
    test('allowCollaboration flag tracks permission level', () async {
      final h = _Harness();
      h.seed(_personal(id: 'rv'));
      h.seed(_personal(id: 're'));
      h.seed(_personal(id: 'ra'));
      final svc = h.build();

      await svc.shareRecipeWithUsers('rv', ['f'], ResourcePermission.viewer);
      await svc.shareRecipeWithUsers('re', ['f'], ResourcePermission.editor);
      await svc.shareRecipeWithUsers('ra', ['f'], ResourcePermission.admin);

      expect(h.repo.calls, hasLength(3));
      expect(
        h.repo.calls[0].doc.allowCollaboration,
        isFalse,
        reason: 'viewer permission → no collaboration',
      );
      expect(h.repo.calls[1].doc.allowCollaboration, isTrue);
      expect(h.repo.calls[2].doc.allowCollaboration, isTrue);
    });
  });

  group('shareRecipeWithUsers — re-share onto collaborative recipe', () {
    /// Pinned contract: re-sharing must MERGE into existing
    /// memberPermissions, never clobber. A common bug shape is the new map
    /// replacing the old one, silently dropping existing members.
    test('re-share preserves existing members + adds new ones', () async {
      final h = _Harness(currentUserId: 'me-uid');
      final existing = _collaborative(
        id: 'r1',
        ownerId: 'me-uid',
        members: {
          'me-uid': ResourcePermission.admin,
          'friend-A': ResourcePermission.editor,
        },
      );
      h.seed(existing);
      final svc = h.build();

      final ok = await svc.shareRecipeWithUsers('r1', [
        'friend-B',
      ], ResourcePermission.viewer);

      expect(ok, RecipeShareResult.full);
      final saved = h.saved.single;
      final perms = saved.socialData!.memberPermissions!;
      expect(perms.keys, containsAll(['me-uid', 'friend-A', 'friend-B']));
      expect(
        perms['friend-A'],
        ResourcePermission.editor,
        reason:
            'existing member must not be downgraded by an unrelated '
            're-share',
      );
      expect(perms['friend-B'], ResourcePermission.viewer);
    });

    /// Pinned contract: re-sharing with an EXISTING member updates their
    /// role to the new permission. (This is the documented behaviour —
    /// "add or upgrade.")
    test(
      're-share with existing member upgrades that member\'s permission',
      () async {
        final h = _Harness(currentUserId: 'me-uid');
        h.seed(
          _collaborative(
            id: 'r1',
            ownerId: 'me-uid',
            members: {
              'me-uid': ResourcePermission.admin,
              'friend-A': ResourcePermission.viewer,
            },
          ),
        );
        final svc = h.build();

        await svc.shareRecipeWithUsers('r1', [
          'friend-A',
        ], ResourcePermission.editor);

        final perms = h.saved.single.socialData!.memberPermissions!;
        expect(perms['friend-A'], ResourcePermission.editor);
      },
    );

    // The permission-write skip for the sharer's own uid is pinned by
    // 'a share whose recipient list contains the sharer keeps their admin',
    // further down this file. Not duplicated here.
  });

  group('shareRecipeWithUsers — share-cap (BUT-955)', () {
    /// Pinned: when union(owner, existing, new) > maxSharesPerRecipe the
    /// share is refused BEFORE any save. The cap is a multi-tenancy abuse
    /// guard; a bypass here would let a single recipe become unbounded.
    test(
      'union over cap → false, no save, no secondary write, error set',
      () async {
        final cap = Recipe.maxSharesPerRecipe;
        // Pre-populate (cap - 1) existing members so adding 5 more pushes over.
        final members = <String, ResourcePermission>{
          'me-uid': ResourcePermission.admin,
          for (int i = 0; i < cap - 1; i++)
            'existing-$i': ResourcePermission.viewer,
        };
        final h = _Harness(currentUserId: 'me-uid');
        h.seed(_collaborative(id: 'r1', ownerId: 'me-uid', members: members));
        final svc = h.build();

        // 5 new ids → total would be cap + 4 (cap-1 existing + owner + 5 new)
        final newIds = List.generate(5, (i) => 'new-$i');
        final ok = await svc.shareRecipeWithUsers(
          'r1',
          newIds,
          ResourcePermission.viewer,
        );

        expect(ok, RecipeShareResult.failed);
        expect(h.saved, isEmpty);
        expect(h.repo.calls, isEmpty);
        expect(h.errors.last, contains(cap.toString()));
      },
    );

    /// Pinned: a re-share of users who are ALREADY members must not
    /// double-count toward the cap. If this test fails, owners get stuck
    /// unable to re-confirm permissions on a near-cap recipe.
    test(
      're-sharing existing members at the cap is allowed (dedup union)',
      () async {
        final cap = Recipe.maxSharesPerRecipe;
        // Exactly cap members (including owner).
        final members = <String, ResourcePermission>{
          'me-uid': ResourcePermission.admin,
          for (int i = 0; i < cap - 1; i++)
            'existing-$i': ResourcePermission.viewer,
        };
        final h = _Harness(currentUserId: 'me-uid');
        h.seed(_collaborative(id: 'r1', ownerId: 'me-uid', members: members));
        final svc = h.build();

        // Re-share the SAME existing ids — union size == cap, no new entries.
        final ok = await svc.shareRecipeWithUsers(
          'r1',
          members.keys.where((k) => k != 'me-uid').toList(),
          ResourcePermission.editor,
        );

        expect(
          ok,
          RecipeShareResult.full,
          reason: 'at-cap re-share must succeed when no new members added',
        );
      },
    );
  });

  group('shareRecipeWithUsers — write-ordering / partial-failure', () {
    /// Pinned: if the PRIMARY save fails, the operation reports false AND
    /// no secondary shared_recipes doc is created. Otherwise we'd have an
    /// orphan share row pointing at a recipe that never got its socialData
    /// updated — the recipient would see "shared with me" but be denied on
    /// open (rules check `memberPermissions`).
    test(
      'primary save returns false → no secondary write, returns false',
      () async {
        final h = _Harness(saveSucceeds: false);
        h.seed(_personal(id: 'r1'));
        final svc = h.build();

        final ok = await svc.shareRecipeWithUsers('r1', [
          'friend-A',
        ], ResourcePermission.editor);

        expect(ok, RecipeShareResult.failed);
        expect(
          h.repo.calls,
          isEmpty,
          reason: 'no orphan shared_recipes doc on primary-save failure',
        );
      },
    );

    /// BUT-1503 (supersedes BUT-1131's "best-effort, return true" contract):
    /// the recipient only *finds* a share via the secondary `shared_recipes`
    /// doc, so a persistently failing secondary write is a real failure of
    /// the operation's intent — reporting success while the recipient can
    /// never see the share is the bug. After the bounded self-heal retries
    /// are exhausted the operation must surface the failure (return false),
    /// NOT silently return true. The primary save still happened (the recipe
    /// is collaborative) and the UI is still notified, but the caller is told
    /// the share did not fully land so it can prompt a retry.
    test('secondary write throws on every retry → returns false', () async {
      final h = _Harness();
      h.seed(_personal(id: 'r1'));
      h.repo.throwOnCreate = Exception('shared_recipes write denied');
      final svc = h.build();

      final ok = await svc.shareRecipeWithUsers('r1', [
        'friend-A',
      ], ResourcePermission.editor);

      expect(
        ok,
        RecipeShareResult.partial,
        reason:
            'BUT-1503: a persistently failing secondary write is a PARTIAL '
            'share — access was granted (primary write) but not yet discoverable',
      );
      expect(
        ok.accessGranted,
        isTrue,
        reason:
            'BUT-1503: accept-request and notify callers must see access was '
            'granted, so they do not treat this as a total failure',
      );
      expect(h.saved, hasLength(1), reason: 'primary save still happened');
      expect(
        h.notifications,
        greaterThanOrEqualTo(1),
        reason: 'UI is still notified of the successful primary save',
      );
      expect(
        h.repo.attemptCount,
        greaterThan(1),
        reason: 'BUT-1503: the idempotent secondary write must be retried',
      );
    });

    /// BUT-1503 self-heal: a secondary write that fails once then succeeds on
    /// retry must land exactly one `shared_recipes` doc and return true — the
    /// bounded retry absorbs a transient failure without bothering the user.
    test('secondary write fails once then succeeds → returns true, one '
        'shared_recipes write', () async {
      final h = _Harness();
      h.seed(_personal(id: 'r1'));
      h.repo.failFirstNAttempts = 1;
      final svc = h.build();

      final ok = await svc.shareRecipeWithUsers('r1', [
        'friend-A',
      ], ResourcePermission.editor);

      expect(
        ok,
        RecipeShareResult.full,
        reason: 'transient failure self-heals on retry',
      );
      expect(
        h.repo.calls,
        hasLength(1),
        reason:
            'idempotent retry must not duplicate the shared_recipes doc — '
            'exactly one successful write',
      );
      expect(h.errors, isEmpty, reason: 'a self-healed write shows no error');
    });

    /// BUT-1503: when the secondary write fails on every retry, the surfaced
    /// error must be the sanitised localised key — never the raw exception
    /// text — so the UI can prompt "share may not be visible, try again"
    /// without leaking internals.
    test(
      'secondary write throws on every retry → setError sanitised message',
      () async {
        final h = _Harness();
        h.seed(_personal(id: 'r1'));
        h.repo.throwOnCreate = Exception(
          'shared_recipes write denied: permission-denied',
        );
        final svc = h.build();

        final ok = await svc.shareRecipeWithUsers('r1', [
          'friend-A',
        ], ResourcePermission.editor);

        expect(
          ok,
          RecipeShareResult.partial,
          reason:
              'BUT-1503: exhausted retries → partial (access granted, '
              'discovery doc not yet written)',
        );
        expect(
          h.errors,
          isNotEmpty,
          reason: 'secondary failure must surface via setError',
        );
        final lastErr = h.errors.last;
        expect(lastErr, isNotEmpty);
        // Must NOT leak the raw exception text — must be the localised key
        // (sanitised, user-facing).
        expect(
          lastErr,
          isNot(contains('permission-denied')),
          reason: 'raw exception text must not leak into the user-facing error',
        );
        expect(
          lastErr,
          isNot(contains('Exception:')),
          reason: 'raw exception prefix must not leak',
        );
      },
    );

    /// Throwing saveRecipe is caught at the outer try → false, error set.
    test('saveRecipe throws → false, error set, no rethrow', () async {
      final h = _Harness()..setThrowOnSave(Exception('disk full'));
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      final ok = await svc.shareRecipeWithUsers('r1', [
        'friend-A',
      ], ResourcePermission.editor);

      expect(ok, RecipeShareResult.failed);
      expect(h.errors, isNotEmpty);
    });

    /// Throwing getRecipe is caught at the outer try → false, no rethrow.
    test('getRecipe throws → false, no save, no rethrow', () async {
      final h = _Harness()..setThrowOnGet(StateError('network'));
      final svc = h.build();

      final ok = await svc.shareRecipeWithUsers('r1', [
        'friend-A',
      ], ResourcePermission.editor);

      expect(ok, RecipeShareResult.failed);
      expect(h.saved, isEmpty);
      expect(h.repo.calls, isEmpty);
    });
  });

  group('unshareRecipe — owner-only contract', () {
    /// Unauthenticated unshare is refused before any repo touch.
    test('unauthenticated → false, no save', () async {
      final h = _Harness(currentUserId: null);
      h.seed(_collaborative(id: 'r1', ownerId: 'me-uid'));
      final svc = h.build();

      final ok = await svc.unshareRecipe('r1');

      expect(ok, isFalse);
      expect(h.saved, isEmpty);
    });

    /// Not-found → false. Loader returns null → must short-circuit.
    test('recipe not found → false, no save', () async {
      final h = _Harness();
      final svc = h.build();

      final ok = await svc.unshareRecipe('missing');

      expect(ok, isFalse);
      expect(h.saved, isEmpty);
    });

    /// Personal recipe → "not shared" error, no save. A bug here would
    /// happily strip socialData from a personal recipe (no-op but wastes
    /// a write) and possibly nuke other fields.
    test('non-collaborative recipe → false (errorRecipeNotShared)', () async {
      final h = _Harness();
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      final ok = await svc.unshareRecipe('r1');

      expect(ok, isFalse);
      expect(h.saved, isEmpty);
    });

    /// CRITICAL: a member with `admin` ResourcePermission who is NOT the
    /// `ownerId` cannot unshare. Otherwise any admin could unilaterally
    /// kick everyone off the recipe.
    test('admin member who is not socialData.ownerId cannot unshare', () async {
      final h = _Harness(currentUserId: 'admin-member-uid');
      h.seed(
        _collaborative(
          id: 'r1',
          ownerId: 'real-owner-uid',
          members: {
            'real-owner-uid': ResourcePermission.admin,
            'admin-member-uid': ResourcePermission.admin, // co-admin
          },
        ),
      );
      final svc = h.build();

      final ok = await svc.unshareRecipe('r1');

      expect(
        ok,
        isFalse,
        reason: 'only socialData.ownerId can unshare — admin perm != ownership',
      );
      expect(h.saved, isEmpty);
    });

    /// Happy path: owner unshares → type back to personal, socialData wiped
    /// to null. A bug shape here is a half-unshared recipe that keeps
    /// `memberPermissions` populated under `type=personal`, leaving stale
    /// access tokens for friend-A in the document.
    test(
      'owner unshare wipes socialData entirely + flips type to personal',
      () async {
        final h = _Harness(currentUserId: 'me-uid');
        h.seed(
          _collaborative(
            id: 'r1',
            ownerId: 'me-uid',
            members: {
              'me-uid': ResourcePermission.admin,
              'friend-A': ResourcePermission.editor,
            },
          ),
        );
        final svc = h.build();

        final ok = await svc.unshareRecipe('r1');

        expect(ok, isTrue);
        expect(h.saved, hasLength(1));
        final saved = h.saved.single;
        expect(saved.type, RecipeType.personal);
        expect(
          saved.socialData,
          isNull,
          reason:
              'half-unshared recipe with leftover memberPermissions is a '
              'privacy bug — must be null, not just empty map',
        );
      },
    );

    /// Throwing saveRecipe during unshare is caught → false, error set.
    test('saveRecipe throws → false, error set, no rethrow', () async {
      final h = _Harness(currentUserId: 'me-uid')
        ..setThrowOnSave(Exception('boom'));
      h.seed(_collaborative(id: 'r1', ownerId: 'me-uid'));
      final svc = h.build();

      final ok = await svc.unshareRecipe('r1');

      expect(ok, isFalse);
      expect(h.errors, isNotEmpty);
    });

    /// Save returns false (rules denied) → false, error set.
    test('saveRecipe returns false → false, error set', () async {
      final h = _Harness(currentUserId: 'me-uid', saveSucceeds: false);
      h.seed(_collaborative(id: 'r1', ownerId: 'me-uid'));
      final svc = h.build();

      final ok = await svc.unshareRecipe('r1');

      expect(ok, isFalse);
      expect(h.errors, isNotEmpty);
    });
  });

  group('shareRecipeWithGroups — friend-category resolution', () {
    late _FakeFriendsService fakeFriends;

    setUp(() {
      fakeFriends = _FakeFriendsService();
      _registerFakeFriendsService(fakeFriends);
    });

    tearDown(_unregisterFakeFriendsService);

    /// Pinned: shareRecipeWithGroups resolves friend-category members via
    /// the friends service AND excludes the sharer's own uid from the
    /// recipient list. A bug here ("share with self") would be visible
    /// noise in the recipient's inbox AND violate the auth/permission
    /// contract (you can't grant yourself a permission you already have).
    /// BUT-1797. This is the SECOND group-share path (the universal share
    /// dialog); `GroupRecipeSelectionViewModel` is the first. Both had to record
    /// provenance or a group share would be revocable or not depending on which
    /// dialog the user happened to open.
    ///
    /// The union of members inside `shareRecipeWithGroups` throws away which
    /// group each person came through, so the attribution has to be captured
    /// before it — that is what these pin.
    test('a group share records who came through which group', () async {
      fakeFriends.categoriesById['grp-fam'] = FriendCategory(
        id: 'grp-fam',
        ownerId: 'me-uid',
        name: 'Familj',
        friendUserIds: const ['me-uid', 'mom-uid'],
      );

      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      await svc.shareRecipeWithGroups('r1', [
        'grp-fam',
      ], ResourcePermission.viewer);

      final saved = h.saved.single;
      expect(saved.socialData?.grants?['mom-uid'], ['group:grp-fam']);
      expect(
        saved.socialData?.categoryIds,
        ['grp-fam'],
        reason: 'the panel needs a row to offer a revoke on',
      );
      expect(
        saved.socialData?.grants?.containsKey('me-uid'),
        isFalse,
        reason: 'the sharer is the owner, not a sharee, and is never revocable',
      );
    });

    test('a member in TWO groups carries both reasons', () async {
      // The decided case, from the other direction: revoking one group must
      // leave this person standing, and that is only possible if both tokens
      // were recorded at share time.
      fakeFriends.categoriesById['grp-fam'] = FriendCategory(
        id: 'grp-fam',
        ownerId: 'me-uid',
        name: 'Familj',
        friendUserIds: const ['mom-uid'],
      );
      fakeFriends.categoriesById['grp-jobb'] = FriendCategory(
        id: 'grp-jobb',
        ownerId: 'me-uid',
        name: 'Jobb',
        friendUserIds: const ['mom-uid'],
      );

      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      await svc.shareRecipeWithGroups('r1', [
        'grp-fam',
        'grp-jobb',
      ], ResourcePermission.viewer);

      final saved = h.saved.single;
      expect(saved.socialData?.grants?['mom-uid'], [
        'group:grp-fam',
        'group:grp-jobb',
      ]);
      expect(
        saved.socialData?.categoryIds,
        containsAll(['grp-fam', 'grp-jobb']),
      );
    });

    /// The sharer is dropped from the attribution map as well as from the
    /// recipient list, and only this shape can tell the two apart: a group whose
    /// ONLY member is you contributes a group id that no recipient holds. If
    /// that id reached `categoryIds` the sharing panel would offer a revoke row
    /// for a group nobody was ever shared with, and pressing it would report
    /// success while cutting no one.
    test('a group containing only the sharer adds no revocable row', () async {
      fakeFriends.categoriesById['grp-solo'] = FriendCategory(
        id: 'grp-solo',
        ownerId: 'me-uid',
        name: 'Bara jag',
        friendUserIds: const ['me-uid'],
      );
      fakeFriends.categoriesById['grp-fam'] = FriendCategory(
        id: 'grp-fam',
        ownerId: 'me-uid',
        name: 'Familj',
        friendUserIds: const ['mom-uid'],
      );

      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      await svc.shareRecipeWithGroups('r1', [
        'grp-solo',
        'grp-fam',
      ], ResourcePermission.viewer);

      expect(h.saved.single.socialData?.categoryIds, ['grp-fam']);
    });

    test(
      'a share whose recipient list contains the sharer keeps their admin',
      () async {
        // Every test in this file passes non-self ids, and the group path strips
        // self before calling — so the permission-write skip was unpinned, and
        // deleting it left the whole suite green. The regression it prevents is
        // not cosmetic: the sharer is the owner, and overwriting their `admin`
        // with the share's `permission` locks them out of every
        // `_hasAdminPermission`-gated member operation on their own recipe.
        final h = _Harness(currentUserId: 'me-uid');
        h.seed(
          _collaborative(
            id: 'r1',
            members: const {
              'me-uid': ResourcePermission.admin,
              'friend-A': ResourcePermission.viewer,
            },
          ),
        );
        final svc = h.build();

        await svc.shareRecipeWithUsers('r1', [
          'me-uid',
          'friend-B',
        ], ResourcePermission.viewer);

        final social = h.saved.single.socialData!;
        expect(
          social.memberPermissions?['me-uid'],
          ResourcePermission.admin,
          reason: 'the sharer owns this recipe — a share must not demote them',
        );
        expect(
          social.grants?.containsKey('me-uid'),
          isFalse,
          reason: 'and they are not a sharee, so they get no revocable reason',
        );
        // Control: the same loop demonstrably writes both for an id it does not
        // skip, so the two negatives above cannot pass for the wrong reason.
        expect(
          social.memberPermissions?['friend-B'],
          ResourcePermission.viewer,
        );
        expect(social.grants?['friend-B'], [RecipeSocialData.directGrant]);
      },
    );

    test('resolves members, excludes self, shares with the rest', () async {
      fakeFriends.categoriesById['grp-fam'] = FriendCategory(
        id: 'grp-fam',
        ownerId: 'me-uid',
        name: 'Familj',
        friendUserIds: const ['me-uid', 'mom-uid', 'dad-uid'],
      );

      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      final ok = await svc.shareRecipeWithGroups('r1', [
        'grp-fam',
      ], ResourcePermission.viewer);

      expect(ok, isTrue);
      expect(h.saved, hasLength(1));
      final saved = h.saved.single;
      final perms = saved.socialData!.memberPermissions!;
      expect(
        perms.keys,
        containsAll(['mom-uid', 'dad-uid', 'me-uid']),
        reason: 'mom + dad become members, me-uid is the owner-admin',
      );
      // me-uid must NOT appear in the recipient list of the secondary write
      // (it's the sharer). The set must be only {mom-uid, dad-uid}.
      expect(
        h.repo.calls.single.recipientIds.toSet(),
        {'mom-uid', 'dad-uid'},
        reason: 'self must be excluded from the recipient list',
      );
    });

    /// Pinned: an empty group (or one containing only the sharer) → false
    /// with errorNoGroupMembersFound. Without this guard we'd silently
    /// succeed on a no-op share.
    test('group containing only the sharer → false, no save', () async {
      fakeFriends.categoriesById['grp-self'] = FriendCategory(
        id: 'grp-self',
        ownerId: 'me-uid',
        name: 'Solo',
        friendUserIds: const ['me-uid'],
      );

      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      final ok = await svc.shareRecipeWithGroups('r1', [
        'grp-self',
      ], ResourcePermission.editor);

      expect(ok, isFalse);
      expect(h.saved, isEmpty);
      expect(h.errors, isNotEmpty);
    });

    /// Pinned: unknown group id resolves to an empty member set → false.
    /// A bug here would skip the empty-check and crash on an empty list,
    /// or worse, create an orphan SharedRecipe with no recipients.
    test('unknown group id → false, no save', () async {
      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      final ok = await svc.shareRecipeWithGroups('r1', [
        'does-not-exist',
      ], ResourcePermission.editor);

      expect(ok, isFalse);
      expect(h.saved, isEmpty);
      expect(h.repo.calls, isEmpty);
    });

    /// Pinned: multiple groups union their members (dedup → one entry per
    /// user, even if they're in both groups).
    test('multiple groups: union of members, deduped', () async {
      fakeFriends.categoriesById['grp-a'] = FriendCategory(
        id: 'grp-a',
        ownerId: 'me-uid',
        name: 'A',
        friendUserIds: const ['friend-A', 'friend-B'],
      );
      fakeFriends.categoriesById['grp-b'] = FriendCategory(
        id: 'grp-b',
        ownerId: 'me-uid',
        name: 'B',
        friendUserIds: const ['friend-B', 'friend-C'], // friend-B in both
      );

      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      final ok = await svc.shareRecipeWithGroups('r1', [
        'grp-a',
        'grp-b',
      ], ResourcePermission.viewer);

      expect(ok, isTrue);
      final perms = h.saved.single.socialData!.memberPermissions!;
      // 3 friends + owner = 4 keys
      expect(perms.keys.length, 4);
      expect(
        perms.keys,
        containsAll(['me-uid', 'friend-A', 'friend-B', 'friend-C']),
      );
    });

    /// Unauthenticated group-share is refused early.
    test('unauthenticated → false, no save', () async {
      final h = _Harness(currentUserId: null);
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      final ok = await svc.shareRecipeWithGroups('r1', [
        'grp-x',
      ], ResourcePermission.editor);

      expect(ok, isFalse);
      expect(h.saved, isEmpty);
    });
  });

  group('shareRecipeWithGroups — no service locator registered', () {
    /// Pinned: if UnifiedFriendsService isn't registered in the
    /// ServiceLocator (e.g. mid-startup), the resolver catches the throw
    /// and returns an empty member map → operation returns false with
    /// "no group members found", NOT a crash.
    test('no UnifiedFriendsService → false, no crash', () async {
      // Make sure neither GetIt nor the production ServiceLocator has
      // anything registered for UnifiedFriendsService.
      _unregisterFakeFriendsService();
      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      final ok = await svc.shareRecipeWithGroups('r1', [
        'grp-x',
      ], ResourcePermission.editor);

      expect(
        ok,
        isFalse,
        reason:
            'service-unavailable must not crash, must surface as a clean '
            'no-members-found error',
      );
    });
  });

  /// BUT-1797, the arm the two provenance tests above never reach. Both of them
  /// share a PERSONAL recipe, so `RecipeShareGrants.forShare` is called with `existing: null`
  /// and there is nothing to merge into. Every share after the first takes the
  /// already-collaborative branch, which passes the recipe's CURRENT grants —
  /// and that is where the decided behaviour lives: "revoking a group does not
  /// cut a member who also holds a direct share" is only possible if an earlier
  /// share's reasons survive a later one.
  group('shareRecipeWithUsers — provenance merges into what is already '
      'there', () {
    /// Proves an unrelated share does not wipe the group provenance of a member
    /// it never mentions. If `RecipeShareGrants.forShare` started from an empty map instead of
    /// the recipe's own grants, mom-uid would silently become ungranted and a
    /// later revoke of grp-old would find nobody to cut while reporting success.
    test('a plain share preserves another member\'s group grant', () async {
      final h = _Harness(currentUserId: 'me-uid');
      h.seed(
        _collaborative(
          id: 'r1',
          ownerId: 'me-uid',
          members: {
            'me-uid': ResourcePermission.admin,
            'mom-uid': ResourcePermission.editor,
          },
          grants: {
            'mom-uid': ['group:grp-old'],
          },
          categoryIds: ['grp-old'],
        ),
      );
      final svc = h.build();

      await svc.shareRecipeWithUsers('r1', [
        'dad-uid',
      ], ResourcePermission.viewer);

      final grants = h.saved.single.socialData!.grants!;
      expect(grants['mom-uid'], ['group:grp-old']);
      expect(grants['dad-uid'], ['direct']);
    });

    /// `RecipeSocialData.copyWith` treats an explicit null as "erase" (sentinel
    /// defaults), so `categoryIds` survives a non-group share only because
    /// `RecipeShareGrants.mergeCategoryIds` folds the existing list in first. Passing `null` for
    /// the existing list there — which reads as a harmless simplification, and
    /// is exactly what the personal branch two lines up does — would drop the
    /// group row out of the sharing panel with no other symptom.
    test(
      'a plain share does not erase a group already on the recipe',
      () async {
        final h = _Harness(currentUserId: 'me-uid');
        h.seed(
          _collaborative(
            id: 'r1',
            ownerId: 'me-uid',
            members: {'me-uid': ResourcePermission.admin},
            categoryIds: ['grp-old'],
          ),
        );
        final svc = h.build();

        await svc.shareRecipeWithUsers('r1', [
          'dad-uid',
        ], ResourcePermission.viewer);

        expect(h.saved.single.socialData?.categoryIds, ['grp-old']);
      },
    );

    /// The decided invariant (Malin, 2026-08-03) as this path produces it:
    /// two separate decisions were made about mom-uid, so both reasons are on
    /// the document and revoking the group leaves the direct share standing.
    test('someone shared with by group AND directly carries both '
        'reasons', () async {
      final h = _Harness(currentUserId: 'me-uid');
      h.seed(
        _collaborative(
          id: 'r1',
          ownerId: 'me-uid',
          members: {
            'me-uid': ResourcePermission.admin,
            'mom-uid': ResourcePermission.viewer,
          },
          grants: {
            'mom-uid': ['group:grp-fam'],
          },
          categoryIds: ['grp-fam'],
        ),
      );
      final svc = h.build();

      await svc.shareRecipeWithUsers('r1', [
        'mom-uid',
      ], ResourcePermission.editor);

      expect(h.saved.single.socialData?.grants?['mom-uid'], [
        'group:grp-fam',
        'direct',
      ]);
    });

    /// A share with no group behind it leaves the field absent rather than
    /// writing an empty array — `categoryIds` is what the panel renders rows
    /// from, and `[]` and `null` must not both have to be handled downstream.
    test('a first plain share leaves categoryIds null', () async {
      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      await svc.shareRecipeWithUsers('r1', [
        'dad-uid',
      ], ResourcePermission.viewer);

      expect(h.saved.single.socialData?.categoryIds, isNull);
      expect(h.saved.single.socialData?.grants, {
        'dad-uid': ['direct'],
      });
    });

    /// The `startsWith('group:')` guard in `RecipeShareGrants.mergeCategoryIds`,
    /// reached through the public `grantsByUserId` parameter.
    ///
    /// Note what this does NOT prove: a stray 'direct' is refused by EITHER
    /// guard, because `'direct'.substring(6)` is '' and the empty-id guard
    /// catches it. The two guards are separated in recipe_share_grants_test.dart
    /// with a token whose remainder is non-empty. What this pins is that the
    /// input is reachable at all from a caller.
    test('a direct token in the attribution map never becomes a category '
        'id', () async {
      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      await svc.shareRecipeWithUsers(
        'r1',
        ['dad-uid'],
        ResourcePermission.viewer,
        grantsByUserId: const {
          'dad-uid': [RecipeSocialData.directGrant],
        },
      );

      expect(h.saved.single.socialData?.categoryIds, isNull);
      expect(h.saved.single.socialData?.grants?['dad-uid'], ['direct']);
    });
  });

  group('read-only queries — never throw', () {
    /// `isRecipeShared` swallows loader throws → false.
    test('isRecipeShared: getRecipe throws → false (no rethrow)', () async {
      final h = _Harness()..setThrowOnGet(Exception('network'));
      final svc = h.build();

      expect(await svc.isRecipeShared('r1'), isFalse);
    });

    test('isRecipeShared: personal recipe → false', () async {
      final h = _Harness();
      h.seed(_personal(id: 'r1'));
      final svc = h.build();

      expect(await svc.isRecipeShared('r1'), isFalse);
    });

    test('isRecipeShared: collaborative recipe → true', () async {
      final h = _Harness(currentUserId: 'me-uid');
      h.seed(_collaborative(id: 'r1', ownerId: 'me-uid'));
      final svc = h.build();

      expect(await svc.isRecipeShared('r1'), isTrue);
    });

    test('isRecipeShared: missing recipe → false', () async {
      final h = _Harness();
      final svc = h.build();

      expect(await svc.isRecipeShared('missing'), isFalse);
    });

    /// `getSharedUsers` swallows throws → empty list (never null).
    test('getSharedUsers: getRecipe throws → empty list', () async {
      final h = _Harness()..setThrowOnGet(Exception('boom'));
      final svc = h.build();

      expect(await svc.getSharedUsers('r1'), isEmpty);
    });

    test(
      'getSharedUsers: personal recipe (no socialData) → empty list',
      () async {
        final h = _Harness();
        h.seed(_personal(id: 'r1'));
        final svc = h.build();

        expect(await svc.getSharedUsers('r1'), isEmpty);
      },
    );

    /// Pinned: getSharedUsers includes the OWNER in the returned list.
    /// The map is keyed on every member (owner + friends). A bug shape
    /// would be filtering out the current user and silently dropping
    /// the owner from "who has access".
    test(
      'getSharedUsers: collaborative recipe returns all member keys',
      () async {
        final h = _Harness();
        h.seed(
          _collaborative(
            id: 'r1',
            ownerId: 'me-uid',
            members: {
              'me-uid': ResourcePermission.admin,
              'friend-A': ResourcePermission.editor,
              'friend-B': ResourcePermission.viewer,
            },
          ),
        );
        final svc = h.build();

        final users = await svc.getSharedUsers('r1');
        expect(users.toSet(), {'me-uid', 'friend-A', 'friend-B'});
      },
    );
  });
}
