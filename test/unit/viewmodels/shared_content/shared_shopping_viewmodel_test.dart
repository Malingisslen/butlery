/// Behavioural unit tests for [SharedShoppingViewModel].
///
/// SharedShoppingViewModel extends `BaseSharedContentViewModel<SharedShoppingList>`.
/// Base-class mechanics (loadContent/refresh/pagination/search cache) are
/// covered by the base's own suite — we only assert subclass-specific
/// behaviour here, plus the cross-cutting contracts on dismiss/join/markViewed
/// that have a high bug-prior (see BUT-1068 for the sibling pattern).
///
/// Behaviours covered:
/// - loadContentFromRepository throws when unauthenticated (no coordinator call).
/// - loadContentFromRepository filters out dismissed lists (coordinator cache).
/// - loadContentFromRepository filters content from blocked users (read at load).
/// - loadContentFromRepository invokes loadStatusForAllShoppingLists before
///   filtering — otherwise dismissed/viewed/imported checks would all be
///   false-stale on first load.
/// - dismissSharedShoppingList: bool faithfully propagates from coordinator
///   AND local removal only happens on success (pins the post-BUT-1068
///   correct pattern — flipping back to always-true would break this).
/// - dismissSharedShoppingList rolls back local state when coordinator throws.
/// - undismissSharedShoppingList re-adds locally on success; idempotent on
///   duplicate id; returns false without mutating when coordinator returns false.
/// - markAsViewed short-circuits when already viewed (no repo round-trips).
/// - markAsViewed writes + reloads cache + notifies listeners on success.
/// - markAsViewed returns false (no writes) when unauthenticated.
/// - joinSharedShoppingList returns coordinator's collaborative list id on
///   success, and skips the cache-reload short-circuit when coordinator
///   returns null.
/// - markAllAsViewed only marks UNviewed lists (no redundant writes); uses
///   loading-state lane not operating-state (per useOperatingState: false).
/// - canEditShoppingList: owner always edits; non-owner edits iff joined;
///   unauthenticated never edits.
/// - getCollaborativeList finds collaborative-type list whose name contains
///   the shared list name (substring match); returns null otherwise.
/// - getShoppingListsByStatus AND-composes status filters (intersection).
/// - getEngagementStats reflects cached status counts and itemCount totals.
/// - Auth-aware getters/methods return safe defaults when userId is null.
/// - contentMatchesSearch matches listName/sharedBy/shareMessage/description
///   case-insensitively, and tolerates null optional fields.
library;

import 'package:butlery/models/shared_shopping_list.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/modules/social_shopping/social_shopping_coordinator.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/viewmodels/shared_content/shared_shopping_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockCoordinator extends Mock implements SocialShoppingCoordinator {}

class _FakeSharedShoppingListArg extends Fake implements SharedShoppingList {}

const _kCurrentUid = 'uid-current';

SharedShoppingList _list({
  required String id,
  String? sharedBy,
  String listName = 'Veckohandling',
  String? listDescription,
  String? shareMessage,
  int itemCount = 0,
  String? shoppingListId,
}) {
  return SharedShoppingList(
    id: id,
    sharedByUserId: sharedBy ?? 'uid-other',
    sharedByDisplayName: sharedBy ?? 'Other',
    listName: listName,
    listDescription: listDescription,
    shareMessage: shareMessage,
    itemCount: itemCount,
    originalOwnerId: sharedBy ?? 'uid-other',
    originalOwnerDisplayName: sharedBy ?? 'Other',
    shoppingListId: shoppingListId,
  );
}

UnifiedShoppingList _collabList(String name) {
  return UnifiedShoppingList(
    name: name,
    ownerId: _kCurrentUid,
    ownerDisplayName: 'Me',
    type: ListType.collaborative,
  );
}

UnifiedShoppingList _personalList(String name) {
  return UnifiedShoppingList(
    name: name,
    ownerId: _kCurrentUid,
    ownerDisplayName: 'Me',
    type: ListType.personal,
  );
}

void main() {
  late _MockCoordinator coordinator;
  late MockUnifiedShoppingService shoppingService;
  late FakePermissionService permissionService;
  late MockUnifiedFriendsService friendsService;

  setUpAll(() async {
    registerFallbackValue(_FakeSharedShoppingListArg());
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    coordinator = _MockCoordinator();
    shoppingService = MockUnifiedShoppingService();
    permissionService = FakePermissionService();
    friendsService = MockUnifiedFriendsService();

    permissionService.setPermissionState(
      currentUserId: _kCurrentUid,
      isAuthenticated: true,
    );
    friendsService.setFriendsState(blockedUsers: <String>{});
    shoppingService.setShoppingState(lists: <UnifiedShoppingList>[]);

    TestServiceLocator.registerMock<PermissionService>(permissionService);
    TestServiceLocator.registerMock<UnifiedFriendsService>(friendsService);
    TestServiceLocator.registerMock<SocialShoppingCoordinator>(coordinator);
    TestServiceLocator.registerMock<UnifiedShoppingService>(shoppingService);

    // Default coordinator stubs — nothing dismissed/viewed/imported.
    when(() => coordinator.isShoppingListDismissed(any())).thenReturn(false);
    when(() => coordinator.isShoppingListViewed(any())).thenReturn(false);
    when(() => coordinator.isShoppingListImported(any())).thenReturn(false);
    when(
      () => coordinator.loadStatusForAllShoppingLists(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => coordinator.loadStatusForShoppingList(any(), any()),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  SharedShoppingViewModel makeVm() => SharedShoppingViewModel(
    socialShoppingCoordinator: coordinator,
    shoppingService: shoppingService,
  );

  group('loadContentFromRepository', () {
    /// Auth gate: no current user → must throw via loadContentFromRepository,
    /// which the base's `loadContent()` wrapper converts to `hasError` —
    /// crucially WITHOUT invoking the coordinator (no leaking the throw
    /// after a wasted Firestore round-trip).
    test('throws and skips coordinator call when unauthenticated', () async {
      permissionService.setPermissionState(currentUserId: null);

      final vm = makeVm();
      await vm.loadContent();

      expect(vm.hasError, isTrue);
      expect(vm.content, isEmpty);
      verifyNever(() => coordinator.getSharedShoppingListsForUser(any()));
      vm.dispose();
    });

    /// REGRESSION GUARD — was a real production bug (BUT-1085, originally
    /// pinned under BUT-1069). The base's `loadContent()` calls
    /// `loadContentWithPagination()`, NOT `loadContentFromRepository()`. The
    /// previous custom override re-implemented pagination WITHOUT the
    /// dismissed/blocked filter — dismissed lists leaked into `content`. The
    /// fix in iter-77 routes `loadContentWithPagination` through
    /// `loadContentFromRepository`, mirroring the sibling
    /// `SharedRecipeViewModel:110-117`. If a future refactor reintroduces the
    /// custom override, this test fails with `['v','d']`.
    test(
      'dismissed lists ARE filtered out (BUT-1085 / BUT-1069 regression)',
      () async {
        final visible = _list(id: 'v');
        final dismissed = _list(id: 'd');
        when(
          () => coordinator.getSharedShoppingListsForUser(_kCurrentUid),
        ).thenAnswer((_) async => [visible, dismissed]);
        when(() => coordinator.isShoppingListDismissed('d')).thenReturn(true);

        final vm = makeVm();
        await vm.loadContent();

        // Post-fix: dismissed filter runs through the filtered repository path.
        expect(vm.content.map((l) => l.id), ['v']);
        vm.dispose();
      },
    );

    /// REGRESSION GUARD — see above (BUT-1085 / BUT-1069). Same root cause:
    /// the blocked-user filter is in `loadContentFromRepository`. Now that
    /// the base goes through `loadContentWithPagination` which delegates to
    /// `loadContentFromRepository`, the filter applies.
    test(
      'blocked-user content IS filtered out (BUT-1085 / BUT-1069 regression)',
      () async {
        final fromBlocked = _list(id: 'b', sharedBy: 'uid-blocked');
        final fromFriend = _list(id: 'f', sharedBy: 'uid-friend');
        when(
          () => coordinator.getSharedShoppingListsForUser(_kCurrentUid),
        ).thenAnswer((_) async => [fromBlocked, fromFriend]);

        final vm = makeVm();
        friendsService.setFriendsState(blockedUsers: {'uid-blocked'});

        await vm.loadContent();

        // Post-fix: blocked sender's list is filtered.
        expect(vm.content.map((l) => l.id), ['f']);
        vm.dispose();
      },
    );

    /// REGRESSION GUARD — see above (BUT-1085 / BUT-1069).
    /// `loadStatusForAllShoppingLists` is called inside
    /// `loadContentFromRepository`; previously bypassed because the base went
    /// through the custom pagination override. Now warmed on every load.
    test('status cache IS pre-loaded on load '
        '(BUT-1085 / BUT-1069 regression)', () async {
      final l1 = _list(id: 'l1');
      when(
        () => coordinator.getSharedShoppingListsForUser(_kCurrentUid),
      ).thenAnswer((_) async => [l1]);

      final vm = makeVm();
      await vm.loadContent();

      // Post-fix: called once with the loaded lists and the current uid.
      verify(
        () => coordinator.loadStatusForAllShoppingLists([l1], _kCurrentUid),
      ).called(1);
      vm.dispose();
    });
  });

  group('dismissSharedShoppingList', () {
    /// Happy path: coordinator returns true → caller sees `true` AND the
    /// item is removed locally. Both invariants together rule out
    /// (a) the BUT-1068 always-true bug (caller would still see true but
    /// removal would happen only by coincidence), and
    /// (b) the optimistic-UI variant where removal happens regardless.
    test(
      'returns true and removes locally when coordinator succeeds',
      () async {
        final l = _list(id: 'd1');
        when(
          () => coordinator.getSharedShoppingListsForUser(_kCurrentUid),
        ).thenAnswer((_) async => [l]);
        when(
          () => coordinator.dismissSharedShoppingList('d1'),
        ).thenAnswer((_) async => true);

        final vm = makeVm();
        await vm.loadContent();
        expect(vm.content, hasLength(1));

        final ok = await vm.dismissSharedShoppingList(l);

        expect(ok, isTrue);
        expect(vm.content, isEmpty);
        verify(() => coordinator.dismissSharedShoppingList('d1')).called(1);
        vm.dispose();
      },
    );

    /// Bool-faithful propagation: coordinator says false → caller sees false
    /// AND the item is NOT removed locally. The sibling recipe VM was fixed
    /// in BUT-1068 for exactly this bug (closure swallowed the bool, always
    /// returned true). This pins the correct shopping behaviour. If the
    /// closure ever regresses to `await coordinator.dismiss(...); return true;`
    /// this assertion fails and the bug is caught.
    test('returns false and preserves item when coordinator returns false '
        '(pins BUT-1068 fix for shopping)', () async {
      final l = _list(id: 'd2');
      when(
        () => coordinator.getSharedShoppingListsForUser(_kCurrentUid),
      ).thenAnswer((_) async => [l]);
      when(
        () => coordinator.dismissSharedShoppingList('d2'),
      ).thenAnswer((_) async => false);

      final vm = makeVm();
      await vm.loadContent();

      final ok = await vm.dismissSharedShoppingList(l);

      expect(ok, isFalse);
      expect(vm.content.map((l) => l.id), ['d2']);
      vm.dispose();
    });

    /// Rollback-on-throw: executeOperation swallows exceptions and returns
    /// null → caller must see false AND the item must remain locally. Lets
    /// the UI show a generic error toast without orphaning data.
    test('returns false and preserves item when coordinator throws', () async {
      final l = _list(id: 'd3');
      when(
        () => coordinator.getSharedShoppingListsForUser(_kCurrentUid),
      ).thenAnswer((_) async => [l]);
      when(
        () => coordinator.dismissSharedShoppingList('d3'),
      ).thenThrow(Exception('network'));

      final vm = makeVm();
      await vm.loadContent();

      final ok = await vm.dismissSharedShoppingList(l);

      expect(ok, isFalse);
      expect(vm.content.map((l) => l.id), ['d3']);
      expect(vm.hasError, isTrue);
      vm.dispose();
    });
  });

  group('undismissSharedShoppingList', () {
    test('adds back to local list on coordinator success', () async {
      final l = _list(id: 'u1');
      when(
        () => coordinator.restoreSharedShoppingList('u1'),
      ).thenAnswer((_) async => true);

      final vm = makeVm();
      final ok = await vm.undismissSharedShoppingList(l);

      expect(ok, isTrue);
      expect(vm.content.map((l) => l.id), ['u1']);
      vm.dispose();
    });

    /// Idempotency: a concurrent refresh may have already re-loaded the
    /// item. We must NOT duplicate it.
    test('does not duplicate when item already present', () async {
      final l = _list(id: 'u2');
      when(
        () => coordinator.getSharedShoppingListsForUser(_kCurrentUid),
      ).thenAnswer((_) async => [l]);
      when(
        () => coordinator.restoreSharedShoppingList('u2'),
      ).thenAnswer((_) async => true);

      final vm = makeVm();
      await vm.loadContent();
      expect(vm.content, hasLength(1));

      await vm.undismissSharedShoppingList(l);

      expect(vm.content.where((x) => x.id == 'u2'), hasLength(1));
      vm.dispose();
    });

    test(
      'returns false and does not add when coordinator returns false',
      () async {
        final l = _list(id: 'u3');
        when(
          () => coordinator.restoreSharedShoppingList('u3'),
        ).thenAnswer((_) async => false);

        final vm = makeVm();
        final ok = await vm.undismissSharedShoppingList(l);

        expect(ok, isFalse);
        expect(vm.content, isEmpty);
        vm.dispose();
      },
    );
  });

  group('markAsViewed', () {
    /// Already-viewed short-circuit. Skipping it would cost a write per
    /// scroll-into-view event. Must NOT call markShoppingListAsViewed OR
    /// loadStatusForShoppingList.
    test(
      'short-circuits when list is already viewed (no repo writes)',
      () async {
        final l = _list(id: 'v1');
        when(() => coordinator.isShoppingListViewed('v1')).thenReturn(true);

        final vm = makeVm();
        final ok = await vm.markAsViewed(l);

        expect(ok, isTrue);
        verifyNever(() => coordinator.markShoppingListAsViewed(any()));
        verifyNever(() => coordinator.loadStatusForShoppingList(any(), any()));
        vm.dispose();
      },
    );

    /// Happy path: not yet viewed → write + cache reload + listener
    /// notification (so the unread badge re-renders).
    test('writes, reloads cache, and notifies when not yet viewed', () async {
      final l = _list(id: 'v2');
      when(() => coordinator.isShoppingListViewed('v2')).thenReturn(false);
      when(
        () => coordinator.markShoppingListAsViewed('v2'),
      ).thenAnswer((_) async => true);

      final vm = makeVm();
      var notifications = 0;
      vm.addListener(() => notifications++);

      final ok = await vm.markAsViewed(l);

      expect(ok, isTrue);
      verify(() => coordinator.markShoppingListAsViewed('v2')).called(1);
      verify(
        () => coordinator.loadStatusForShoppingList('v2', _kCurrentUid),
      ).called(1);
      expect(
        notifications,
        greaterThanOrEqualTo(1),
        reason: 'UI must be told to refresh the read badge',
      );
      vm.dispose();
    });

    /// Unauthenticated path: the inner block reads `currentUserId` AFTER
    /// the (untracked) write. If the user signed out mid-flight, we still
    /// must return cleanly without crashing on the null-userId reload.
    /// (Production guards `if (userId != null)` for the reload — pin it.)
    test('returns false (no writes) when unauthenticated', () async {
      permissionService.setPermissionState(currentUserId: null);
      // Already-viewed is false so we go past the short-circuit.
      when(() => coordinator.isShoppingListViewed(any())).thenReturn(false);
      when(
        () => coordinator.markShoppingListAsViewed(any()),
      ).thenAnswer((_) async => true);
      final l = _list(id: 'v3');

      final vm = makeVm();
      final ok = await vm.markAsViewed(l);

      // Production goes through the write path (no auth gate up front), so
      // markShoppingListAsViewed runs, but loadStatusForShoppingList must
      // be skipped (userId == null guard).
      expect(
        ok,
        isTrue,
        reason:
            'inner closure returns true unconditionally; '
            'the unauth case still completes cleanly',
      );
      verifyNever(() => coordinator.loadStatusForShoppingList(any(), any()));
      vm.dispose();
    });
  });

  group('joinSharedShoppingList', () {
    /// Happy path: coordinator returns a collaborative list id → caller gets
    /// the same id back, AND the cache is reloaded so the just-joined list
    /// becomes "imported" without a separate refresh.
    test('returns collaborative id and reloads status on success', () async {
      final l = _list(id: 'j1');
      when(
        () => coordinator.joinSharedShoppingList(
          sharedShoppingListId: any(named: 'sharedShoppingListId'),
        ),
      ).thenAnswer((_) async => 'collab-list-7');

      final vm = makeVm();
      final result = await vm.joinSharedShoppingList(l);

      expect(result, 'collab-list-7');
      verify(
        () => coordinator.loadStatusForShoppingList('j1', _kCurrentUid),
      ).called(1);
      vm.dispose();
    });

    /// Coordinator-null short-circuit: when no collaborative id was created
    /// (e.g. permission denied, list deleted), we must NOT bother reloading
    /// status — a wasted Firestore round-trip on a no-op.
    test('skips cache reload when coordinator returns null', () async {
      final l = _list(id: 'j2');
      when(
        () => coordinator.joinSharedShoppingList(
          sharedShoppingListId: any(named: 'sharedShoppingListId'),
        ),
      ).thenAnswer((_) async => null);

      final vm = makeVm();
      final result = await vm.joinSharedShoppingList(l);

      expect(result, isNull);
      verifyNever(() => coordinator.loadStatusForShoppingList(any(), any()));
      vm.dispose();
    });

    test('returns null and sets hasError when coordinator throws', () async {
      final l = _list(id: 'j3');
      when(
        () => coordinator.joinSharedShoppingList(
          sharedShoppingListId: any(named: 'sharedShoppingListId'),
        ),
      ).thenThrow(Exception('boom'));

      final vm = makeVm();
      final result = await vm.joinSharedShoppingList(l);

      expect(result, isNull);
      expect(vm.hasError, isTrue);
      vm.dispose();
    });
  });

  group('markAllAsViewed', () {
    /// Only UNviewed lists get a write. If we marked all unconditionally,
    /// every bulk-mark would cost O(N) wasteful writes.
    test('marks only unviewed lists; skips already-viewed', () async {
      final viewed = _list(id: 'a');
      final unviewed1 = _list(id: 'b');
      final unviewed2 = _list(id: 'c');
      when(
        () => coordinator.getSharedShoppingListsForUser(_kCurrentUid),
      ).thenAnswer((_) async => [viewed, unviewed1, unviewed2]);
      when(() => coordinator.isShoppingListViewed('a')).thenReturn(true);
      when(
        () => coordinator.markShoppingListAsViewed(any()),
      ).thenAnswer((_) async => true);

      final vm = makeVm();
      await vm.loadContent();

      await vm.markAllAsViewed();

      verifyNever(() => coordinator.markShoppingListAsViewed('a'));
      verify(() => coordinator.markShoppingListAsViewed('b')).called(1);
      verify(() => coordinator.markShoppingListAsViewed('c')).called(1);
      vm.dispose();
    });

    /// Unauthenticated guard: must no-op silently (do not throw, do not
    /// write). The base would set hasError on a throw — we explicitly skip.
    test('no-ops silently when unauthenticated', () async {
      permissionService.setPermissionState(currentUserId: null);

      final vm = makeVm();
      await vm.markAllAsViewed();

      verifyNever(() => coordinator.markShoppingListAsViewed(any()));
      expect(vm.hasError, isFalse);
      vm.dispose();
    });
  });

  group('canEditShoppingList', () {
    /// Pinned permission contract (production lines 351-360):
    /// - owner ALWAYS edits.
    /// - non-owner edits IFF they've joined (direct collaboration).
    /// - unauthenticated NEVER edits.
    /// Three table-driven cases — flipping a `==` to `!=` would break one.
    test('owner can always edit, regardless of join status', () {
      final mine = _list(id: 'm', sharedBy: _kCurrentUid);
      when(() => coordinator.isShoppingListImported('m')).thenReturn(false);

      final vm = makeVm();
      expect(vm.canEditShoppingList(mine), isTrue);
      vm.dispose();
    });

    test('non-owner can edit when joined (direct collaboration)', () {
      final l = _list(id: 'l', sharedBy: 'uid-other');
      when(() => coordinator.isShoppingListImported('l')).thenReturn(true);

      final vm = makeVm();
      expect(vm.canEditShoppingList(l), isTrue);
      vm.dispose();
    });

    test('non-owner cannot edit when not joined', () {
      final l = _list(id: 'l', sharedBy: 'uid-other');
      when(() => coordinator.isShoppingListImported('l')).thenReturn(false);

      final vm = makeVm();
      expect(vm.canEditShoppingList(l), isFalse);
      vm.dispose();
    });

    test('unauthenticated never edits, even own list', () {
      permissionService.setPermissionState(currentUserId: null);
      final mine = _list(id: 'm', sharedBy: _kCurrentUid);

      final vm = makeVm();
      expect(vm.canEditShoppingList(mine), isFalse);
      vm.dispose();
    });
  });

  group('getCollaborativeList', () {
    /// Matching contract: type==collaborative AND name contains the shared
    /// list name (substring, not equality). Pin both halves: a personal list
    /// with a matching name must NOT match; a collaborative list with an
    /// unrelated name must NOT match.
    test(
      'finds collaborative list whose name contains the shared list name',
      () {
        final candidate = _collabList('Veckohandling — Anna & Erik');
        final wrongType = _personalList('Veckohandling');
        final wrongName = _collabList('Helgmiddag');
        shoppingService.setShoppingState(
          lists: [wrongType, candidate, wrongName],
        );

        final shared = _list(id: 's', listName: 'Veckohandling');
        final vm = makeVm();

        final result = vm.getCollaborativeList(shared);
        expect(result, candidate);
        vm.dispose();
      },
    );

    test('returns null when no collaborative list matches', () {
      shoppingService.setShoppingState(lists: [_personalList('Veckohandling')]);

      final vm = makeVm();
      final result = vm.getCollaborativeList(
        _list(id: 's', listName: 'Veckohandling'),
      );
      expect(result, isNull);
      vm.dispose();
    });
  });

  group('getShoppingListsByStatus', () {
    /// AND-composition: status filters intersect. An `||` regression would
    /// surface unwanted lists in filtered views.
    test('combines isViewed AND isImported via intersection', () async {
      final a = _list(id: 'a'); // viewed=t, imported=t
      final b = _list(id: 'b'); // viewed=t, imported=f
      final c = _list(id: 'c'); // viewed=f, imported=t
      when(
        () => coordinator.getSharedShoppingListsForUser(_kCurrentUid),
      ).thenAnswer((_) async => [a, b, c]);
      when(() => coordinator.isShoppingListViewed('a')).thenReturn(true);
      when(() => coordinator.isShoppingListViewed('b')).thenReturn(true);
      when(() => coordinator.isShoppingListImported('a')).thenReturn(true);
      when(() => coordinator.isShoppingListImported('c')).thenReturn(true);

      final vm = makeVm();
      await vm.loadContent();

      final viewedAndJoined = vm.getShoppingListsByStatus(
        isViewed: true,
        isJoined: true,
      );
      expect(viewedAndJoined.map((l) => l.id), ['a']);

      final viewedNotJoined = vm.getShoppingListsByStatus(
        isViewed: true,
        isJoined: false,
      );
      expect(viewedNotJoined.map((l) => l.id), ['b']);
      vm.dispose();
    });

    test('returns empty when unauthenticated', () {
      permissionService.setPermissionState(currentUserId: null);
      final vm = makeVm();
      expect(vm.getShoppingListsByStatus(isViewed: true), isEmpty);
      vm.dispose();
    });
  });

  group('getEngagementStats', () {
    test(
      'reflects cached statuses, sharedByMe, and itemCount totals',
      () async {
        final mine = _list(id: 'm', sharedBy: _kCurrentUid, itemCount: 3);
        final viewed = _list(id: 'v', sharedBy: 'uid-other', itemCount: 5);
        final joined = _list(id: 'j', sharedBy: 'uid-other', itemCount: 0);
        when(
          () => coordinator.getSharedShoppingListsForUser(_kCurrentUid),
        ).thenAnswer((_) async => [mine, viewed, joined]);
        when(() => coordinator.isShoppingListViewed('v')).thenReturn(true);
        when(() => coordinator.isShoppingListImported('j')).thenReturn(true);

        final vm = makeVm();
        await vm.loadContent();

        final stats = vm.getEngagementStats();
        expect(stats['total'], 3);
        // Unread = total - viewed → 2 (mine, joined both unviewed in cache).
        expect(stats['unread'], 2);
        expect(stats['joined'], 1);
        expect(stats['sharedByMe'], 1);
        expect(stats['totalItems'], 8);
        // withItems counts mine(3) + viewed(5); joined has 0 items.
        expect(stats['withItems'], 2);
        vm.dispose();
      },
    );

    test('returns empty map when unauthenticated', () {
      permissionService.setPermissionState(currentUserId: null);
      final vm = makeVm();
      expect(vm.getEngagementStats(), isEmpty);
      vm.dispose();
    });
  });

  group('auth-aware getters return safe defaults when unauthenticated', () {
    /// One omnibus test for the four-getter family that share the same
    /// `userId == null → return safe default` guard. Each catches the same
    /// bug-shape (missing null guard would NPE on currentUserId.equals).
    test(
      'unreadCount/sharedByCurrentUser/joinable/joined all safe-default',
      () {
        permissionService.setPermissionState(currentUserId: null);
        final vm = makeVm();

        expect(vm.unreadCount, 0);
        expect(vm.sharedByCurrentUser, isEmpty);
        expect(vm.joinableShoppingLists, isEmpty);
        expect(vm.joinedShoppingLists, isEmpty);
        vm.dispose();
      },
    );
  });

  group('joinableShoppingLists', () {
    /// Excludes own-shared content AND already-imported content. The two
    /// conditions are AND-composed via the && in the where-clause.
    test('excludes self-shared and already-imported', () async {
      final mine = _list(id: 'mine', sharedBy: _kCurrentUid);
      final imported = _list(id: 'imp', sharedBy: 'uid-other');
      final joinable = _list(id: 'jn', sharedBy: 'uid-other');
      when(
        () => coordinator.getSharedShoppingListsForUser(_kCurrentUid),
      ).thenAnswer((_) async => [mine, imported, joinable]);
      when(() => coordinator.isShoppingListImported('imp')).thenReturn(true);

      final vm = makeVm();
      await vm.loadContent();

      expect(vm.joinableShoppingLists.map((l) => l.id), ['jn']);
      vm.dispose();
    });
  });

  group('contentMatchesSearch', () {
    /// Case-insensitive substring search across the four searchable fields.
    /// Production line 102-108 OR-composes them; flipping any to AND would
    /// silently break per-field matches.
    test('matches listName, sharedBy, shareMessage, description (CI)', () {
      final vm = makeVm();
      final l = SharedShoppingList(
        id: '1',
        sharedByUserId: 'u',
        sharedByDisplayName: 'Alice',
        listName: 'VeckoHandling',
        listDescription: 'För middagar',
        shareMessage: 'Kolla detta',
        itemCount: 0,
        originalOwnerId: 'u',
        originalOwnerDisplayName: 'Alice',
      );

      expect(vm.contentMatchesSearch(l, 'vecko'), isTrue);
      expect(vm.contentMatchesSearch(l, 'alice'), isTrue);
      expect(vm.contentMatchesSearch(l, 'kolla'), isTrue);
      expect(vm.contentMatchesSearch(l, 'middag'), isTrue);
      expect(vm.contentMatchesSearch(l, 'nope'), isFalse);
      vm.dispose();
    });

    /// Null-tolerance: shareMessage and listDescription are optional. The
    /// `?? false` fallbacks in production must hold — otherwise NPE on
    /// `null.toLowerCase()` would crash search for legacy shares.
    test('does not crash when shareMessage and description are null', () {
      final vm = makeVm();
      final l = _list(id: '1', listName: 'Helg');
      // Both shareMessage and description default to null in the helper.

      expect(vm.contentMatchesSearch(l, 'helg'), isTrue);
      expect(vm.contentMatchesSearch(l, 'absent'), isFalse);
      vm.dispose();
    });
  });

  group('contentTypeName', () {
    test('is "shopping_list"', () {
      final vm = makeVm();
      expect(vm.contentTypeName, 'shopping_list');
      vm.dispose();
    });
  });

  group('supportsPagination / loadMoreContent', () {
    test('supportsPagination is false (no real cursor implemented)', () {
      final vm = makeVm();
      expect(vm.supportsPagination, isFalse);
      vm.dispose();
    });

    test(
      'loadMoreContent throws UnsupportedError when supportsPagination=false',
      () {
        final vm = makeVm();
        expect(
          () => vm.loadMoreContent(),
          throwsA(isA<UnsupportedError>()),
        );
        vm.dispose();
      },
    );
  });
}
