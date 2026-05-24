/// Behavioural unit tests for [SharedRecipeViewModel].
///
/// SharedRecipeViewModel extends `BaseSharedContentViewModel<SharedRecipe>`.
/// Base-class behaviour (debounced search filtering, addContent/removeContent,
/// pagination lifecycle, search-cache invalidation) lives in the base's own
/// test suite — we only re-test base mechanics here when the subclass's
/// override genuinely changes them.
///
/// Behaviours covered:
/// - loadContentFromRepository throws when unauthenticated (contract from line 60).
/// - loadContentFromRepository filters out dismissed recipes (coordinator cache).
/// - loadContentFromRepository filters content from blocked users.
/// - showImported=false hides imported recipes; flipping it includes them.
/// - dismissSharedRecipe removes locally ONLY on coordinator success
///   (rollback-on-failure invariant — partial-write protection).
/// - undismissSharedRecipe re-adds locally, but is idempotent on dup id.
/// - markAsViewed short-circuits when already viewed (no repo write).
/// - markAsViewed reloads cache + notifies after successful write.
/// - importSharedRecipe legacyMode==true and ==false both call joinSharedRecipe
///   (pins the documented "no-op legacy branch" — see file lines 180-192).
/// - unreadCount respects showImported (imported items don't count when hidden).
/// - importableRecipes excludes own-shared content (sharedByUserId == userId).
/// - canEditRecipe contract per (owner / collaboration flag / cow-triggered).
/// - getRecipesByStatus AND-composes status filters (intersection, not union).
/// - getEngagementStats reflects current cached state.
/// - contentMatchesSearch matches title/description/sharedBy/ingredients
///   (only when full snapshot present for ingredients).
/// - Auth-aware getters return safe defaults when userId is null.
/// - getSharedRecipeById returns null and clears error when coordinator throws
///   (executeOperation swallows exceptions per base-class contract).
library;

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/modules/social_recipe/social_recipe_coordinator.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockCoordinator extends Mock implements SocialRecipeCoordinator {}

class _FakeSharedRecipeArg extends Fake implements SharedRecipe {}

const _kCurrentUid = 'uid-current';

SharedRecipe _recipe({
  required String id,
  String? sharedBy,
  String title = 'Pasta',
  String? description,
  bool allowCollaboration = false,
  bool copyOnWriteTriggered = false,
  Recipe? snapshot,
}) {
  return SharedRecipe(
    id: id,
    sharedByUserId: sharedBy ?? 'uid-other',
    sharedByDisplayName: sharedBy ?? 'Other',
    originalRecipeId: 'orig-$id',
    recipeTitle: title,
    recipeDescription: description,
    allowCollaboration: allowCollaboration,
    copyOnWriteTriggered: copyOnWriteTriggered,
    recipeSnapshot: snapshot,
  );
}

Recipe _recipeWithIngredients(List<String> ingredients) {
  return Recipe(
    core: RecipeCore(
      id: 'r-1',
      title: 'snap',
      description: '',
      ingredients: ingredients,
      instructions: const [],
      imageUrls: const [],
      mealType: 'Middag',
    ),
    type: RecipeType.shared,
  );
}

void main() {
  late _MockCoordinator coordinator;
  late FakePermissionService permissionService;
  late MockUnifiedFriendsService friendsService;

  setUpAll(() async {
    registerFallbackValue(_FakeSharedRecipeArg());
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    coordinator = _MockCoordinator();
    permissionService = FakePermissionService();
    friendsService = MockUnifiedFriendsService();

    permissionService.setPermissionState(
      currentUserId: _kCurrentUid,
      isAuthenticated: true,
    );
    friendsService.setFriendsState(blockedUsers: <String>{});

    TestServiceLocator.registerMock<PermissionService>(permissionService);
    TestServiceLocator.registerMock<UnifiedFriendsService>(friendsService);
    // Register the coordinator so the default-ctor path (no injection) also works.
    TestServiceLocator.registerMock<SocialRecipeCoordinator>(coordinator);

    // Default coordinator stubs — recipes are not viewed/imported/dismissed.
    when(() => coordinator.isRecipeDismissed(any())).thenReturn(false);
    when(() => coordinator.isRecipeImported(any())).thenReturn(false);
    when(() => coordinator.isRecipeViewed(any())).thenReturn(false);
    when(() => coordinator.loadStatusForAllRecipes(any(), any()))
        .thenAnswer((_) async {});
    when(() => coordinator.loadStatusForRecipe(any(), any()))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  SharedRecipeViewModel makeVm() =>
      SharedRecipeViewModel(socialRecipeCoordinator: coordinator);

  group('loadContentFromRepository', () {
    /// Auth-required contract: if the permission service has no current user,
    /// loadContentFromRepository must throw — and the base's `loadContent()`
    /// wrapper must surface that as `hasError` rather than crashing the view.
    test('throws when no authenticated user', () async {
      permissionService.setPermissionState(currentUserId: null);
      when(() => coordinator.getSharedRecipesForUser(any()))
          .thenAnswer((_) async => []);

      final vm = makeVm();
      await vm.loadContent();

      expect(vm.hasError, isTrue);
      expect(vm.content, isEmpty);
      // Coordinator must NOT have been queried since auth failed first.
      verifyNever(() => coordinator.getSharedRecipesForUser(any()));
      vm.dispose();
    });

    /// Dismissed recipes (per the coordinator's cache) must be filtered out
    /// of the visible list. Bug shape: if the filter used `==` instead of
    /// `!=` (or no filter at all), a dismissed item re-appears on every load.
    test('filters out dismissed recipes', () async {
      final r1 = _recipe(id: 'visible');
      final r2 = _recipe(id: 'dismissed');
      when(() => coordinator.getSharedRecipesForUser(_kCurrentUid))
          .thenAnswer((_) async => [r1, r2]);
      when(() => coordinator.isRecipeDismissed('dismissed')).thenReturn(true);

      final vm = makeVm();
      await vm.loadContent();

      expect(vm.content.map((r) => r.id), ['visible']);
      vm.dispose();
    });

    /// Recipes shared by a blocked user must NOT appear. Bug shape: filter
    /// reads blockedUsers once at construction (snapshot), so a block done
    /// after VM init would silently fail — pinning here ensures the filter
    /// reads `blockedUsers` AT LOAD TIME.
    test('excludes content from blocked users (read at load time)', () async {
      final fromBlocked = _recipe(id: 'r-blocked', sharedBy: 'uid-blocked');
      final fromOk = _recipe(id: 'r-ok', sharedBy: 'uid-friend');
      when(() => coordinator.getSharedRecipesForUser(_kCurrentUid))
          .thenAnswer((_) async => [fromBlocked, fromOk]);

      final vm = makeVm();
      // Block someone AFTER vm is constructed but BEFORE load.
      friendsService.setFriendsState(blockedUsers: {'uid-blocked'});

      await vm.loadContent();

      expect(vm.content.map((r) => r.id), ['r-ok']);
      vm.dispose();
    });

    /// showImported is a UI filter (default false = hide already-imported items
    /// for a cleaner inbox). Toggling it must change visibility on next load.
    test('showImported=false hides imported; flipping to true reveals them',
        () async {
      final imported = _recipe(id: 'imp');
      final fresh = _recipe(id: 'fresh');
      when(() => coordinator.getSharedRecipesForUser(_kCurrentUid))
          .thenAnswer((_) async => [imported, fresh]);
      when(() => coordinator.isRecipeImported('imp')).thenReturn(true);

      final vm = makeVm();
      await vm.loadContent();
      expect(vm.content.map((r) => r.id), ['fresh']);

      vm.setShowImported(true);
      await vm.loadContent();
      expect(vm.content.map((r) => r.id).toSet(), {'imp', 'fresh'});
      vm.dispose();
    });
  });

  group('dismissSharedRecipe', () {
    /// Happy path: coordinator success → removed from local list AND repo write
    /// happened. Both must be verified; a bug where only one of them fires
    /// is a classic partial-write (UI lies to the user).
    test('removes locally only when coordinator confirms success', () async {
      final r = _recipe(id: 'd1');
      when(() => coordinator.getSharedRecipesForUser(_kCurrentUid))
          .thenAnswer((_) async => [r]);
      when(() => coordinator.dismissSharedRecipe('d1'))
          .thenAnswer((_) async => true);

      final vm = makeVm();
      await vm.loadContent();
      expect(vm.content, hasLength(1));

      final ok = await vm.dismissSharedRecipe(r);

      expect(ok, isTrue);
      expect(vm.content, isEmpty);
      verify(() => coordinator.dismissSharedRecipe('d1')).called(1);
      vm.dispose();
    });

    /// PINS A PRODUCTION BUG (file: lib/viewmodels/shared_content/
    /// shared_recipe_viewmodel.dart lines 215-218): the inner closure
    /// discards the bool returned by coordinator.dismissSharedRecipe and
    /// always `return true;`. So a coordinator that returns false
    /// (e.g. silent permission denial) is still reported as success and the
    /// item IS removed locally — UI lies, Firestore still has the item.
    ///
    /// This test pins the CURRENT (buggy) behaviour so a fix is an
    /// intentional change. When the bug is fixed, invert these expects.
    test(
        'BUG: ignores coordinator=false result, still reports success + removes locally',
        () async {
      final r = _recipe(id: 'd2');
      when(() => coordinator.getSharedRecipesForUser(_kCurrentUid))
          .thenAnswer((_) async => [r]);
      when(() => coordinator.dismissSharedRecipe('d2'))
          .thenAnswer((_) async => false);

      final vm = makeVm();
      await vm.loadContent();

      final ok = await vm.dismissSharedRecipe(r);

      // Current behaviour: success reported and local list mutated even
      // though the repo write was rejected.
      expect(ok, isTrue,
          reason: 'Pins production bug; flip to isFalse once the inner closure '
              'forwards the coordinator result.');
      expect(vm.content, isEmpty,
          reason: 'Pins production bug; flip to ["d2"] once fixed.');
      vm.dispose();
    });

    /// Rollback-on-throw: if the coordinator throws, executeOperation swallows
    /// the exception, sets an error, returns null → dismissSharedRecipe must
    /// return false AND not remove the item.
    test('returns false and preserves item when coordinator throws', () async {
      final r = _recipe(id: 'd3');
      when(() => coordinator.getSharedRecipesForUser(_kCurrentUid))
          .thenAnswer((_) async => [r]);
      when(() => coordinator.dismissSharedRecipe('d3'))
          .thenThrow(Exception('network'));

      final vm = makeVm();
      await vm.loadContent();

      final ok = await vm.dismissSharedRecipe(r);

      expect(ok, isFalse);
      expect(vm.content.map((r) => r.id), ['d3']);
      expect(vm.hasError, isTrue);
      vm.dispose();
    });
  });

  group('undismissSharedRecipe', () {
    /// On success, the recipe is added back to the local list. But the add must
    /// be idempotent — if the same id is already present (e.g. a parallel
    /// refresh re-loaded it), we must NOT duplicate it.
    test('adds back to local list on success', () async {
      final r = _recipe(id: 'u1');
      when(() => coordinator.undismissSharedRecipe('u1'))
          .thenAnswer((_) async => true);

      final vm = makeVm();
      // Pre-condition: list is empty.
      final ok = await vm.undismissSharedRecipe(r);

      expect(ok, isTrue);
      expect(vm.content.map((r) => r.id), ['u1']);
      vm.dispose();
    });

    test('does not duplicate when item already present', () async {
      final r = _recipe(id: 'u2');
      when(() => coordinator.getSharedRecipesForUser(_kCurrentUid))
          .thenAnswer((_) async => [r]);
      when(() => coordinator.undismissSharedRecipe('u2'))
          .thenAnswer((_) async => true);

      final vm = makeVm();
      await vm.loadContent();
      expect(vm.content, hasLength(1));

      await vm.undismissSharedRecipe(r);

      expect(vm.content.where((r) => r.id == 'u2'), hasLength(1));
      vm.dispose();
    });

    test('does not add to local list when coordinator returns false', () async {
      final r = _recipe(id: 'u3');
      when(() => coordinator.undismissSharedRecipe('u3'))
          .thenAnswer((_) async => false);

      final vm = makeVm();
      final ok = await vm.undismissSharedRecipe(r);

      expect(ok, isFalse);
      expect(vm.content, isEmpty);
      vm.dispose();
    });
  });

  group('markAsViewed', () {
    /// Already-viewed short-circuit: must NOT call markRecipeAsViewed OR
    /// loadStatusForRecipe — both are Firestore round-trips. Skipping this
    /// check would cost a write per scroll-into-view event.
    test('short-circuits when recipe is already viewed (no repo writes)',
        () async {
      final r = _recipe(id: 'v1');
      when(() => coordinator.isRecipeViewed('v1')).thenReturn(true);

      final vm = makeVm();
      final ok = await vm.markAsViewed(r);

      expect(ok, isTrue);
      verifyNever(() => coordinator.markRecipeAsViewed(any()));
      verifyNever(() => coordinator.loadStatusForRecipe(any(), any()));
      vm.dispose();
    });

    /// Happy path: not yet viewed → write happens, then status reload runs
    /// (so the cache reflects the new state), then a notification fires for
    /// the UI to re-render the read/unread badge.
    test('writes, reloads status, and notifies when not yet viewed', () async {
      final r = _recipe(id: 'v2');
      when(() => coordinator.isRecipeViewed('v2')).thenReturn(false);
      when(() => coordinator.markRecipeAsViewed('v2'))
          .thenAnswer((_) async => true);

      final vm = makeVm();
      var notifications = 0;
      vm.addListener(() => notifications++);

      final ok = await vm.markAsViewed(r);

      expect(ok, isTrue);
      verify(() => coordinator.markRecipeAsViewed('v2')).called(1);
      verify(() => coordinator.loadStatusForRecipe('v2', _kCurrentUid))
          .called(1);
      expect(notifications, greaterThanOrEqualTo(1),
          reason: 'UI must be told to refresh the read badge');
      vm.dispose();
    });

    /// Unauthenticated path: the operation must short-circuit cleanly via
    /// executeOperation (which swallows the thrown 'No authenticated user'
    /// and returns null → markAsViewed returns false). No partial writes.
    test('returns false and writes nothing when unauthenticated', () async {
      permissionService.setPermissionState(currentUserId: null);
      final r = _recipe(id: 'v3');

      final vm = makeVm();
      final ok = await vm.markAsViewed(r);

      expect(ok, isFalse);
      verifyNever(() => coordinator.markRecipeAsViewed(any()));
      vm.dispose();
    });
  });

  group('importSharedRecipe', () {
    /// The legacyMode flag is documented as "GitHub fork-style" import — but
    /// inspecting the implementation (lib/viewmodels/shared_content/
    /// shared_recipe_viewmodel.dart:180-192) reveals BOTH branches call
    /// joinSharedRecipe with the same args. This test PINS that observed
    /// behaviour. If the dead branch is ever wired to a real legacy import,
    /// this test must be updated deliberately.
    test('legacyMode=true and legacyMode=false both call joinSharedRecipe',
        () async {
      final r = _recipe(id: 'i1', title: 'pasta');
      when(() => coordinator.joinSharedRecipe(
            sharedRecipeId: any(named: 'sharedRecipeId'),
            newTitle: any(named: 'newTitle'),
          )).thenAnswer((_) async => 'new-id');

      final vm = makeVm();
      await vm.importSharedRecipe(r, legacyMode: false, newTitle: 'A');
      await vm.importSharedRecipe(r, legacyMode: true, newTitle: 'B');

      verify(() =>
              coordinator.joinSharedRecipe(sharedRecipeId: 'i1', newTitle: 'A'))
          .called(1);
      verify(() =>
              coordinator.joinSharedRecipe(sharedRecipeId: 'i1', newTitle: 'B'))
          .called(1);
      vm.dispose();
    });

    test('returns null and sets error when coordinator throws', () async {
      final r = _recipe(id: 'i2');
      when(() => coordinator.joinSharedRecipe(
            sharedRecipeId: any(named: 'sharedRecipeId'),
            newTitle: any(named: 'newTitle'),
          )).thenThrow(Exception('boom'));

      final vm = makeVm();
      final result = await vm.importSharedRecipe(r);

      expect(result, isNull);
      expect(vm.hasError, isTrue);
      vm.dispose();
    });
  });

  group('unreadCount', () {
    /// showImported=false → imported items must NOT count as unread, even if
    /// they're technically unviewed. This matches the visible list filter so
    /// the badge count never exceeds the visible item count.
    test('excludes imported recipes when showImported is false', () async {
      final viewed = _recipe(id: 'v');
      final unread = _recipe(id: 'u');
      final imported = _recipe(id: 'i');
      when(() => coordinator.getSharedRecipesForUser(_kCurrentUid))
          .thenAnswer((_) async => [viewed, unread, imported]);
      when(() => coordinator.isRecipeViewed('v')).thenReturn(true);
      when(() => coordinator.isRecipeImported('i')).thenReturn(true);

      final vm = makeVm();
      vm.setShowImported(true); // load WITH imported so it's in `content`
      await vm.loadContent();
      vm.setShowImported(false); // but display filter hides it

      // Only 'u' counts: 'v' is viewed, 'i' is imported (hidden).
      expect(vm.unreadCount, 1);
      vm.dispose();
    });

    test('returns 0 when unauthenticated', () {
      permissionService.setPermissionState(currentUserId: null);
      final vm = makeVm();
      expect(vm.unreadCount, 0);
      vm.dispose();
    });
  });

  group('importableRecipes', () {
    /// You can't import a recipe you yourself shared (it's already yours).
    /// Bug shape: filter compares `sharedByUserId == userId` with the wrong
    /// operand (e.g. recipe.id), allowing self-import → duplicate copy.
    test('excludes recipes shared by the current user', () async {
      final mine = _recipe(id: 'mine', sharedBy: _kCurrentUid);
      final theirs = _recipe(id: 'theirs', sharedBy: 'uid-other');
      when(() => coordinator.getSharedRecipesForUser(_kCurrentUid))
          .thenAnswer((_) async => [mine, theirs]);

      final vm = makeVm();
      await vm.loadContent();

      expect(vm.importableRecipes.map((r) => r.id), ['theirs']);
      vm.dispose();
    });

    test('excludes already-imported recipes', () async {
      final imported = _recipe(id: 'imp');
      final fresh = _recipe(id: 'fresh');
      when(() => coordinator.getSharedRecipesForUser(_kCurrentUid))
          .thenAnswer((_) async => [imported, fresh]);
      when(() => coordinator.isRecipeImported('imp')).thenReturn(true);

      final vm = makeVm();
      vm.setShowImported(true); // keep imported in `content` for this assertion
      await vm.loadContent();

      expect(vm.importableRecipes.map((r) => r.id), ['fresh']);
      vm.dispose();
    });
  });

  group('canEditRecipe', () {
    /// Pinned contract per branch (production code lines 303-312):
    /// - owner ALWAYS edits.
    /// - non-owner can edit ONLY when (allowCollaboration && copyOnWriteTriggered).
    /// - unauthenticated cannot edit.
    /// Three table-driven cases — flipping any && to || would break one.
    test('owner can always edit (regardless of flags)', () {
      final mine = _recipe(
        id: 'm',
        sharedBy: _kCurrentUid,
        allowCollaboration: false,
        copyOnWriteTriggered: false,
      );
      final vm = makeVm();
      expect(vm.canEditRecipe(mine), isTrue);
      vm.dispose();
    });

    test('non-owner with allowCollaboration but no cow trigger cannot edit',
        () {
      final r = _recipe(
        id: 'r',
        sharedBy: 'uid-other',
        allowCollaboration: true,
        copyOnWriteTriggered: false,
      );
      final vm = makeVm();
      expect(vm.canEditRecipe(r), isFalse);
      vm.dispose();
    });

    test('non-owner with both allowCollaboration AND cow trigger can edit', () {
      final r = _recipe(
        id: 'r',
        sharedBy: 'uid-other',
        allowCollaboration: true,
        copyOnWriteTriggered: true,
      );
      final vm = makeVm();
      expect(vm.canEditRecipe(r), isTrue);
      vm.dispose();
    });

    test('unauthenticated never edits, even own recipe', () {
      permissionService.setPermissionState(currentUserId: null);
      final r = _recipe(id: 'r', sharedBy: _kCurrentUid);
      final vm = makeVm();
      expect(vm.canEditRecipe(r), isFalse);
      vm.dispose();
    });
  });

  group('getRecipesByStatus', () {
    /// AND-composition: status filters intersect. Bug shape: an `||` chain
    /// instead of `&&` would yield a union — wrong recipes shown.
    test('combines isViewed AND isImported via intersection', () async {
      final r1 = _recipe(id: 'r1'); // viewed=t, imported=t
      final r2 = _recipe(id: 'r2'); // viewed=t, imported=f
      final r3 = _recipe(id: 'r3'); // viewed=f, imported=t
      when(() => coordinator.getSharedRecipesForUser(_kCurrentUid))
          .thenAnswer((_) async => [r1, r2, r3]);
      when(() => coordinator.isRecipeViewed('r1')).thenReturn(true);
      when(() => coordinator.isRecipeViewed('r2')).thenReturn(true);
      when(() => coordinator.isRecipeImported('r1')).thenReturn(true);
      when(() => coordinator.isRecipeImported('r3')).thenReturn(true);

      final vm = makeVm();
      vm.setShowImported(true); // keep imported items in content
      await vm.loadContent();

      // Only r1 is BOTH viewed AND imported.
      final result = vm.getRecipesByStatus(isViewed: true, isImported: true);
      expect(result.map((r) => r.id), ['r1']);

      // r2 alone is viewed-but-not-imported.
      final viewedNotImported =
          vm.getRecipesByStatus(isViewed: true, isImported: false);
      expect(viewedNotImported.map((r) => r.id), ['r2']);
      vm.dispose();
    });

    test('returns empty list when unauthenticated', () {
      permissionService.setPermissionState(currentUserId: null);
      final vm = makeVm();
      expect(vm.getRecipesByStatus(isViewed: true), isEmpty);
      vm.dispose();
    });
  });

  group('contentMatchesSearch', () {
    /// Ingredient match must require a full snapshot. Without one, the
    /// production code is allowed to ignore ingredient queries (and does,
    /// per line 103). Bug shape: removing the `hasFullSnapshot` guard would
    /// NPE on `recipeSnapshot!.ingredients`.
    test('matches title, sharedBy, description case-insensitively', () {
      final vm = makeVm();
      final r = _recipe(
        id: '1',
        sharedBy: 'Alice',
        title: 'PaStA Carbonara',
        description: 'Italian Classic',
      );
      expect(vm.contentMatchesSearch(r, 'pasta'), isTrue);
      expect(vm.contentMatchesSearch(r, 'alice'), isTrue);
      expect(vm.contentMatchesSearch(r, 'italian'), isTrue);
      expect(vm.contentMatchesSearch(r, 'nope'), isFalse);
      vm.dispose();
    });

    test('matches ingredient only when full snapshot is present', () {
      final vm = makeVm();
      final withSnap = _recipe(
        id: '1',
        title: 'Soup',
        snapshot: _recipeWithIngredients(['Carrots', 'Onion']),
      );
      final withoutSnap = _recipe(id: '2', title: 'Soup');

      expect(vm.contentMatchesSearch(withSnap, 'carrot'), isTrue);
      // No snapshot: ingredient search must NOT crash and must NOT match.
      expect(vm.contentMatchesSearch(withoutSnap, 'carrot'), isFalse);
      vm.dispose();
    });
  });

  group('getEngagementStats', () {
    test('reflects current cached status counts', () async {
      final r1 = _recipe(id: 'r1', sharedBy: _kCurrentUid);
      final r2 = _recipe(id: 'r2', sharedBy: 'uid-other');
      final r3 = _recipe(id: 'r3', sharedBy: 'uid-other');
      when(() => coordinator.getSharedRecipesForUser(_kCurrentUid))
          .thenAnswer((_) async => [r1, r2, r3]);
      when(() => coordinator.isRecipeViewed('r1')).thenReturn(true);
      when(() => coordinator.isRecipeImported('r2')).thenReturn(true);

      final vm = makeVm();
      vm.setShowImported(true);
      await vm.loadContent();

      final stats = vm.getEngagementStats();
      expect(stats['total'], 3);
      expect(stats['unread'], 2); // r2, r3 are unread (r1 viewed)
      expect(stats['imported'], 1);
      expect(stats['sharedByMe'], 1);
      vm.dispose();
    });

    test('returns empty map when unauthenticated', () {
      permissionService.setPermissionState(currentUserId: null);
      final vm = makeVm();
      expect(vm.getEngagementStats(), isEmpty);
      vm.dispose();
    });
  });

  group('getSharedRecipeById', () {
    test('returns coordinator result on success', () async {
      final r = _recipe(id: 'deep-link-r');
      when(() => coordinator.getSharedRecipeById('deep-link-r'))
          .thenAnswer((_) async => r);

      final vm = makeVm();
      final result = await vm.getSharedRecipeById('deep-link-r');

      expect(result, r);
      vm.dispose();
    });

    /// executeOperation contract: returns null on throw and surfaces error
    /// state — the caller must not have to handle exceptions itself.
    test('returns null and sets hasError when coordinator throws', () async {
      when(() => coordinator.getSharedRecipeById(any()))
          .thenThrow(Exception('not found'));

      final vm = makeVm();
      final result = await vm.getSharedRecipeById('missing');

      expect(result, isNull);
      expect(vm.hasError, isTrue);
      vm.dispose();
    });
  });

  group('contentTypeName', () {
    test('is "recipe"', () {
      final vm = makeVm();
      expect(vm.contentTypeName, 'recipe');
      vm.dispose();
    });
  });
}
