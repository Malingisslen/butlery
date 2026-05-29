/// Behavioural unit tests for [SharedMenuViewModel].
///
/// SharedMenuViewModel extends `BaseSharedContentViewModel<SharedMenu>`.
/// Base-class behaviour (search filtering, addContent/removeContent,
/// pagination lifecycle, cache invalidation) lives in the base's own test
/// suite — we only assert subclass overrides and the menu-specific surface.
///
/// Behaviours covered:
/// - loadContentFromRepository throws when unauthenticated → loadContent
///   surfaces hasError (auth contract from production lines 59-62).
/// - clearStatusCache MUST run before getSharedMenusForUser (bug fix per
///   production line 67-69: dismissed-menus-reappear regression).
/// - loadStatusForAllMenus is invoked with the loaded list + userId so the
///   filter calls below have populated cache.
/// - Dismissed / blocked-user / imported (when !showImported) menus are
///   filtered out of the visible list.
/// - showImported toggles imported-menu visibility.
/// - dismissSharedMenu propagates coordinator's bool verbatim (NOT the
///   BUT-1068 swallow-and-return-true pattern). Pinned per-branch:
///   coordinator true → returns true + removes locally; coordinator false →
///   returns false + preserves item; coordinator throws → returns false +
///   preserves item + sets hasError.
/// - undismissSharedMenu adds back idempotently on success; no-add on false.
/// - markAsViewed short-circuits when already viewed (no Firestore writes).
/// - markAsViewed writes + reloads status + notifies on first view.
/// - markAsViewed swallows unauthenticated via executeOperation (returns false).
/// - importSharedMenu delegates to joinSharedMenu with newTitle; toggles
///   per-item operating state across success AND failure paths.
/// - markAllAsViewed updates only unviewed menus and sets viewed-status on success.
/// - canEditMenu contract: owner always; non-owner only if isCollaborative;
///   unauthenticated never.
/// - getMenusByStatus AND-composes filters (intersection, not union).
/// - getMenusByCollaborationStatus filters by isCollaborative / isOriginalReference.
/// - getMenuCategories has three formatting branches (empty / 1 / ≤3 / >3).
/// - unreadCount excludes imported when !showImported; returns 0 unauthenticated.
/// - importableMenus excludes self-shared and already-imported menus.
/// - totalRecipesInMenus sums per-menu counts.
/// - getEngagementStats returns shape with auth-gated empty fallback.
/// - getCategoryStats sorts descending by count.
/// - contentMatchesSearch matches title/sharedBy/category/shareMessage
///   case-insensitively; safe when shareMessage is null.
/// - Auth-aware getters return safe defaults when userId is null.
/// - getSharedMenuById returns null and surfaces hasError when coordinator throws.
/// - contentTypeName is 'menu' (pinning the override).
library;

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/shared_content/shared_menu_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockCoordinator extends Mock implements SocialMenuCoordinator {}

class _FakeSharedMenuArg extends Fake implements SharedMenu {}

const _kCurrentUid = 'uid-current';

SharedMenu _menu({
  required String id,
  String? sharedBy,
  String title = 'Veckomeny',
  String? shareMessage,
  bool allowCollaboration = false,
  bool copyOnWriteTriggered = false,
  bool isOriginalReference = true,
  Map<String, List<Recipe>>? snapshot,
}) {
  return SharedMenu(
    id: id,
    sharedByUserId: sharedBy ?? 'uid-other',
    sharedByDisplayName: sharedBy ?? 'Other',
    menuTitle: title,
    shareMessage: shareMessage,
    menuSnapshot: snapshot ?? const {},
    allowCollaboration: allowCollaboration,
    copyOnWriteTriggered: copyOnWriteTriggered,
    isOriginalReference: isOriginalReference,
  );
}

Recipe _recipe(String id) {
  return Recipe(
    core: RecipeCore(
      id: id,
      title: 'r-$id',
      description: '',
      ingredients: const [],
      instructions: const [],
      imageUrls: const [],
      mealType: 'Middag',
    ),
    type: RecipeType.personal,
  );
}

void main() {
  late _MockCoordinator coordinator;
  late FakePermissionService permissionService;
  late MockUnifiedFriendsService friendsService;

  setUpAll(() async {
    registerFallbackValue(_FakeSharedMenuArg());
    registerFallbackValue(<SharedMenu>[]);
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
    TestServiceLocator.registerMock<SocialMenuCoordinator>(coordinator);

    // Default coordinator stubs — menus are not viewed/imported/dismissed.
    when(() => coordinator.isMenuDismissed(any())).thenReturn(false);
    when(() => coordinator.isMenuImported(any())).thenReturn(false);
    when(() => coordinator.isMenuViewed(any())).thenReturn(false);
    when(() => coordinator.clearStatusCache()).thenReturn(null);
    when(() => coordinator.setViewedStatus(any(), any())).thenReturn(null);
    when(() => coordinator.loadStatusForAllMenus(any(), any()))
        .thenAnswer((_) async {});
    when(() => coordinator.loadStatusForMenu(any(), any()))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  SharedMenuViewModel makeVm() =>
      SharedMenuViewModel(socialMenuCoordinator: coordinator);

  group('loadContentFromRepository', () {
    /// Auth contract: a null currentUserId must throw inside
    /// loadContentFromRepository — `loadContent()` catches it and surfaces
    /// `hasError`. Bug shape: a missing null-check would NPE on
    /// `getSharedMenusForUser(null)` and crash the view.
    test('throws when unauthenticated → loadContent sets hasError', () async {
      permissionService.setPermissionState(currentUserId: null);
      final vm = makeVm();

      await vm.loadContent();

      expect(vm.hasError, isTrue);
      expect(vm.content, isEmpty);
      verifyNever(() => coordinator.getSharedMenusForUser(any()));
      vm.dispose();
    });

    /// Order-of-operations contract: clearStatusCache MUST be called BEFORE
    /// getSharedMenusForUser so that stale "isDismissed" state from a prior
    /// session can't bleed into the new load. The fix that put it in lives
    /// in production lines 67-69 — pinning the order prevents regression.
    test('clears status cache BEFORE fetching menus', () async {
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => []);

      final vm = makeVm();
      await vm.loadContent();

      verifyInOrder([
        () => coordinator.clearStatusCache(),
        () => coordinator.getSharedMenusForUser(_kCurrentUid),
      ]);
      vm.dispose();
    });

    /// After fetching the raw list, status MUST be hydrated into the cache
    /// before the filter loop runs (otherwise isMenuDismissed/Imported would
    /// always return false → dismissed menus reappear, imported menus stay).
    test('loads status for all menus before filtering', () async {
      final menus = [_menu(id: 'a'), _menu(id: 'b')];
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => menus);

      final vm = makeVm();
      await vm.loadContent();

      verify(() => coordinator.loadStatusForAllMenus(menus, _kCurrentUid))
          .called(1);
      vm.dispose();
    });

    /// Dismissed menus must be filtered out (per coordinator cache). Bug
    /// shape: `!=` flipped to `==` would HIDE the visible ones instead.
    test('filters out dismissed menus', () async {
      final visible = _menu(id: 'visible');
      final dismissed = _menu(id: 'dismissed');
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [visible, dismissed]);
      when(() => coordinator.isMenuDismissed('dismissed')).thenReturn(true);

      final vm = makeVm();
      await vm.loadContent();

      expect(vm.content.map((m) => m.id), ['visible']);
      vm.dispose();
    });

    /// Blocked-user filter must read `blockedUsers` AT LOAD TIME (not at VM
    /// construction). Bug shape: caching the set at ctor would leak content
    /// from someone the user just blocked.
    test('excludes content from blocked users (read at load time)', () async {
      final fromBlocked = _menu(id: 'b', sharedBy: 'uid-blocked');
      final fromOk = _menu(id: 'ok', sharedBy: 'uid-friend');
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [fromBlocked, fromOk]);

      final vm = makeVm();
      // Block AFTER vm exists, BEFORE load — proves load-time read.
      friendsService.setFriendsState(blockedUsers: {'uid-blocked'});

      await vm.loadContent();

      expect(vm.content.map((m) => m.id), ['ok']);
      vm.dispose();
    });

    /// showImported=false hides imported menus; flipping to true reveals them.
    test('showImported=false hides imported; flipping to true reveals them',
        () async {
      final imported = _menu(id: 'imp');
      final fresh = _menu(id: 'fresh');
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [imported, fresh]);
      when(() => coordinator.isMenuImported('imp')).thenReturn(true);

      final vm = makeVm();
      await vm.loadContent();
      expect(vm.content.map((m) => m.id), ['fresh']);

      vm.setShowImported(true);
      await vm.loadContent();
      expect(vm.content.map((m) => m.id).toSet(), {'imp', 'fresh'});
      vm.dispose();
    });
  });

  group('dismissSharedMenu', () {
    /// PRIMARY TARGET — sibling SharedRecipeViewModel had BUT-1068:
    /// the dismiss closure awaited the coordinator but always returned
    /// `true`. This file's closure correctly forwards the coordinator's
    /// bool. This trio of tests pins that propagation per-branch so any
    /// future "simplification" to always-return-true is caught.
    test('coordinator true → returns true AND removes locally', () async {
      final m = _menu(id: 'd1');
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [m]);
      when(() => coordinator.dismissSharedMenu('d1'))
          .thenAnswer((_) async => true);

      final vm = makeVm();
      await vm.loadContent();
      expect(vm.content, hasLength(1));

      final ok = await vm.dismissSharedMenu(m);

      expect(ok, isTrue);
      expect(vm.content, isEmpty);
      verify(() => coordinator.dismissSharedMenu('d1')).called(1);
      vm.dispose();
    });

    /// Coordinator-false → VM must forward false AND preserve item. Without
    /// this pin, a regression to "always true" silently lies to the UI.
    test('coordinator false → returns false AND preserves item', () async {
      final m = _menu(id: 'd2');
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [m]);
      when(() => coordinator.dismissSharedMenu('d2'))
          .thenAnswer((_) async => false);

      final vm = makeVm();
      await vm.loadContent();

      final ok = await vm.dismissSharedMenu(m);

      expect(ok, isFalse);
      expect(vm.content.map((x) => x.id), ['d2']);
      vm.dispose();
    });

    /// Coordinator throws → executeOperation swallows, returns null →
    /// dismissSharedMenu returns false AND preserves item AND sets hasError.
    test('coordinator throws → returns false, preserves item, sets hasError',
        () async {
      final m = _menu(id: 'd3');
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [m]);
      when(() => coordinator.dismissSharedMenu('d3'))
          .thenThrow(Exception('network'));

      final vm = makeVm();
      await vm.loadContent();

      final ok = await vm.dismissSharedMenu(m);

      expect(ok, isFalse);
      expect(vm.content.map((x) => x.id), ['d3']);
      expect(vm.hasError, isTrue);
      vm.dispose();
    });
  });

  group('undismissSharedMenu', () {
    test('coordinator true → returns true AND adds back to list', () async {
      final m = _menu(id: 'u1');
      when(() => coordinator.restoreSharedMenu('u1'))
          .thenAnswer((_) async => true);

      final vm = makeVm();
      final ok = await vm.undismissSharedMenu(m);

      expect(ok, isTrue);
      expect(vm.content.map((x) => x.id), ['u1']);
      vm.dispose();
    });

    /// Idempotency: if a parallel reload already put the menu back, the
    /// undismiss MUST NOT duplicate it. Bug shape: blind `addContent` here
    /// produces duplicate list entries → duplicate UI tiles.
    test('does not duplicate when item already present', () async {
      final m = _menu(id: 'u2');
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [m]);
      when(() => coordinator.restoreSharedMenu('u2'))
          .thenAnswer((_) async => true);

      final vm = makeVm();
      await vm.loadContent();
      expect(vm.content, hasLength(1));

      await vm.undismissSharedMenu(m);

      expect(vm.content.where((x) => x.id == 'u2'), hasLength(1));
      vm.dispose();
    });

    test('coordinator false → returns false AND does not add to list',
        () async {
      final m = _menu(id: 'u3');
      when(() => coordinator.restoreSharedMenu('u3'))
          .thenAnswer((_) async => false);

      final vm = makeVm();
      final ok = await vm.undismissSharedMenu(m);

      expect(ok, isFalse);
      expect(vm.content, isEmpty);
      vm.dispose();
    });
  });

  group('markAsViewed', () {
    /// Already-viewed short-circuit: production line 245-247 checks the
    /// cache and returns early. Without this, every scroll-into-view would
    /// trigger a Firestore write — real $$ in a paid plan.
    test('short-circuits when already viewed (no Firestore writes)', () async {
      final m = _menu(id: 'v1');
      when(() => coordinator.isMenuViewed('v1')).thenReturn(true);

      final vm = makeVm();
      final ok = await vm.markAsViewed(m);

      expect(ok, isTrue);
      verifyNever(() => coordinator.markMenuAsViewed(any()));
      verifyNever(() => coordinator.loadStatusForMenu(any(), any()));
      vm.dispose();
    });

    /// Happy path: writes → reloads cache → notifies. All three must fire,
    /// in that order, or the UI won't re-render the read badge.
    test('writes, reloads status, notifies on first view', () async {
      final m = _menu(id: 'v2');
      when(() => coordinator.isMenuViewed('v2')).thenReturn(false);
      when(() => coordinator.markMenuAsViewed('v2'))
          .thenAnswer((_) async => true);

      final vm = makeVm();
      var notifications = 0;
      vm.addListener(() => notifications++);

      final ok = await vm.markAsViewed(m);

      expect(ok, isTrue);
      verifyInOrder([
        () => coordinator.markMenuAsViewed('v2'),
        () => coordinator.loadStatusForMenu('v2', _kCurrentUid),
      ]);
      expect(notifications, greaterThanOrEqualTo(1),
          reason: 'UI must be notified so the read badge re-renders');
      vm.dispose();
    });

    /// Unauthenticated: production line 252-255 guards the cache reload.
    /// The write still happens (because markMenuAsViewed comes first), but
    /// the cache reload is skipped. The overall result remains true.
    /// Pinning this contract: result=true even with no userId, AND no
    /// loadStatusForMenu call.
    test('unauthenticated → still returns true but skips cache reload',
        () async {
      final m = _menu(id: 'v3');
      when(() => coordinator.isMenuViewed('v3')).thenReturn(false);
      when(() => coordinator.markMenuAsViewed('v3'))
          .thenAnswer((_) async => true);
      permissionService.setPermissionState(currentUserId: null);

      final vm = makeVm();
      final ok = await vm.markAsViewed(m);

      expect(ok, isTrue);
      verifyNever(() => coordinator.loadStatusForMenu(any(), any()));
      vm.dispose();
    });
  });

  group('importSharedMenu', () {
    /// importSharedMenu must delegate to joinSharedMenu (NOT the deprecated
    /// importSharedMenu coordinator method) and pass newTitle through.
    test('forwards id + newTitle to coordinator.joinSharedMenu', () async {
      final m = _menu(id: 'i1');
      final result = MenuJoinResult(menuId: 'new', isCollaborative: false);
      when(() => coordinator.joinSharedMenu(
            sharedMenuId: any(named: 'sharedMenuId'),
            newTitle: any(named: 'newTitle'),
          )).thenAnswer((_) async => result);

      final vm = makeVm();
      final out = await vm.importSharedMenu(m, newTitle: 'Min meny');

      expect(out, same(result));
      verify(() => coordinator.joinSharedMenu(
          sharedMenuId: 'i1', newTitle: 'Min meny')).called(1);
      vm.dispose();
    });

    /// Per-item operating-state contract: the spinner toggles ON before the
    /// coordinator call and OFF after — even on throw. Without `finally`,
    /// a thrown import would leave the spinner spinning forever.
    test('clears per-item operating state even when coordinator throws',
        () async {
      final m = _menu(id: 'i2');
      when(() => coordinator.joinSharedMenu(
            sharedMenuId: any(named: 'sharedMenuId'),
            newTitle: any(named: 'newTitle'),
          )).thenThrow(Exception('boom'));

      final vm = makeVm();
      final out = await vm.importSharedMenu(m);

      expect(out, isNull);
      expect(vm.isItemOperating('i2'), isFalse,
          reason: 'finally-block must clear per-item state on failure');
      vm.dispose();
    });

    /// Happy path: per-item operating state also cleared on success.
    test('clears per-item operating state on success', () async {
      final m = _menu(id: 'i3');
      when(() => coordinator.joinSharedMenu(
                sharedMenuId: any(named: 'sharedMenuId'),
                newTitle: any(named: 'newTitle'),
              ))
          .thenAnswer(
              (_) async => MenuJoinResult(menuId: 'x', isCollaborative: true));

      final vm = makeVm();
      await vm.importSharedMenu(m);

      expect(vm.isItemOperating('i3'), isFalse);
      vm.dispose();
    });
  });

  group('markAllAsViewed', () {
    /// Bulk view: only unviewed menus go to the coordinator. Bug shape:
    /// dropping the `!isMenuViewed` guard would re-write every already-viewed
    /// menu (Firestore write cost amplification).
    test('only writes for unviewed menus + sets viewed-status on success',
        () async {
      final viewed = _menu(id: 'v');
      final unread1 = _menu(id: 'u1');
      final unread2 = _menu(id: 'u2');
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [viewed, unread1, unread2]);
      when(() => coordinator.isMenuViewed('v')).thenReturn(true);
      when(() => coordinator.markMenuAsViewed('u1'))
          .thenAnswer((_) async => true);
      when(() => coordinator.markMenuAsViewed('u2'))
          .thenAnswer((_) async => false);

      final vm = makeVm();
      await vm.loadContent();
      await vm.markAllAsViewed();

      verifyNever(() => coordinator.markMenuAsViewed('v'));
      verify(() => coordinator.markMenuAsViewed('u1')).called(1);
      verify(() => coordinator.markMenuAsViewed('u2')).called(1);

      // setViewedStatus only fires for the successful one (per prod 342-344).
      verify(() => coordinator.setViewedStatus('u1', true)).called(1);
      verifyNever(() => coordinator.setViewedStatus('u2', any()));
      vm.dispose();
    });

    test('no-op when unauthenticated', () async {
      permissionService.setPermissionState(currentUserId: null);
      final vm = makeVm();
      await vm.markAllAsViewed();
      verifyNever(() => coordinator.markMenuAsViewed(any()));
      vm.dispose();
    });
  });

  group('canEditMenu', () {
    test('owner can always edit (regardless of isCollaborative flag)', () {
      final mine = _menu(
        id: 'm',
        sharedBy: _kCurrentUid,
        allowCollaboration: false,
        copyOnWriteTriggered: false,
      );
      final vm = makeVm();
      expect(vm.canEditMenu(mine), isTrue);
      vm.dispose();
    });

    /// isCollaborative comes from the model mixin (CopyOnWriteSupport):
    /// `isCollaborative => copyOnWriteTriggered`. allowCollaboration is NOT
    /// part of it. Non-owner with allowCollaboration=true but no cow-trigger
    /// → isCollaborative=false → MUST NOT edit.
    test('non-owner with allowCollaboration but no cow-trigger cannot edit',
        () {
      final m = _menu(
        id: 'm',
        sharedBy: 'uid-other',
        allowCollaboration: true,
        copyOnWriteTriggered: false,
      );
      final vm = makeVm();
      expect(vm.canEditMenu(m), isFalse);
      vm.dispose();
    });

    /// Discriminating case that pins the REAL mixin contract: copyOnWrite
    /// triggered alone makes isCollaborative true even when allowCollaboration
    /// is false. The previous suite never covered this — it passed only
    /// because copyOnWriteTriggered=false made the false "allowCollaboration
    /// AND cow" definition agree with the true "cow only" one. This would
    /// catch a future change to canEditMenu that wrongly ANDed in
    /// allowCollaboration.
    test(
        'non-owner with cow-trigger but allowCollaboration=false CAN edit '
        '(isCollaborative == copyOnWriteTriggered)', () {
      final m = _menu(
        id: 'm',
        sharedBy: 'uid-other',
        allowCollaboration: false,
        copyOnWriteTriggered: true,
      );
      expect(m.isCollaborative, isTrue,
          reason: 'mixin: isCollaborative => copyOnWriteTriggered');
      final vm = makeVm();
      expect(vm.canEditMenu(m), isTrue);
      vm.dispose();
    });

    test('non-owner with both flags (isCollaborative=true) CAN edit', () {
      final m = _menu(
        id: 'm',
        sharedBy: 'uid-other',
        allowCollaboration: true,
        copyOnWriteTriggered: true,
      );
      final vm = makeVm();
      expect(vm.canEditMenu(m), isTrue);
      vm.dispose();
    });

    test('unauthenticated cannot edit, even own menu', () {
      permissionService.setPermissionState(currentUserId: null);
      final m = _menu(id: 'm', sharedBy: _kCurrentUid);
      final vm = makeVm();
      expect(vm.canEditMenu(m), isFalse);
      vm.dispose();
    });
  });

  group('getMenusByStatus', () {
    /// AND-composition: filters intersect. Bug shape: flipping any `if`
    /// from `return false` to `return true` makes a filter into a union →
    /// wrong menus shown.
    test('combines isViewed AND isImported via intersection', () async {
      final m1 = _menu(id: 'm1'); // viewed=t, imported=t
      final m2 = _menu(id: 'm2'); // viewed=t, imported=f
      final m3 = _menu(id: 'm3'); // viewed=f, imported=t
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [m1, m2, m3]);
      when(() => coordinator.isMenuViewed('m1')).thenReturn(true);
      when(() => coordinator.isMenuViewed('m2')).thenReturn(true);
      when(() => coordinator.isMenuImported('m1')).thenReturn(true);
      when(() => coordinator.isMenuImported('m3')).thenReturn(true);

      final vm = makeVm();
      vm.setShowImported(true);
      await vm.loadContent();

      final both = vm.getMenusByStatus(isViewed: true, isImported: true);
      expect(both.map((m) => m.id), ['m1']);

      final viewedNotImported =
          vm.getMenusByStatus(isViewed: true, isImported: false);
      expect(viewedNotImported.map((m) => m.id), ['m2']);
      vm.dispose();
    });

    test('returns empty when unauthenticated', () {
      permissionService.setPermissionState(currentUserId: null);
      final vm = makeVm();
      expect(vm.getMenusByStatus(isViewed: true), isEmpty);
      vm.dispose();
    });
  });

  group('getMenusByCollaborationStatus', () {
    test('collaborativeOnly returns only menus with isCollaborative=true',
        () async {
      final cowMenu = _menu(
        id: 'cow',
        allowCollaboration: true,
        copyOnWriteTriggered: true,
      );
      final stillStatic = _menu(
        id: 'static',
        allowCollaboration: true,
        copyOnWriteTriggered: false,
      );
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [cowMenu, stillStatic]);

      final vm = makeVm();
      await vm.loadContent();

      final result = vm.getMenusByCollaborationStatus(collaborativeOnly: true);
      expect(result.map((m) => m.id), ['cow']);
      vm.dispose();
    });

    test('originalReferenceOnly returns menus that have not yet forked',
        () async {
      final original = _menu(id: 'orig', isOriginalReference: true);
      final forked = _menu(id: 'forked', isOriginalReference: false);
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [original, forked]);

      final vm = makeVm();
      await vm.loadContent();

      final result =
          vm.getMenusByCollaborationStatus(originalReferenceOnly: true);
      expect(result.map((m) => m.id), ['orig']);
      vm.dispose();
    });
  });

  group('getMenuCategories', () {
    /// Three formatting branches in production lines 314-323. Empty →
    /// localized "no categories" label. 1 → just the name. ≤3 → comma-joined.
    /// >3 → "first, second och N till" (Swedish "and N more" pattern).
    /// Bug shape: off-by-one in `take(2)` would show wrong leading items;
    /// `length - 2` arithmetic error would mis-state the remainder.
    test('empty categories returns labelNoCategories', () {
      final vm = makeVm();
      final m = _menu(id: 'e', snapshot: const {});
      final text = vm.getMenuCategories(m);
      expect(text, isNotEmpty); // localized — content is locale-dependent
      vm.dispose();
    });

    test('single category returns the category name verbatim', () {
      final vm = makeVm();
      final m = _menu(id: 's', snapshot: {
        'Middag': [_recipe('r')]
      });
      expect(vm.getMenuCategories(m), 'Middag');
      vm.dispose();
    });

    test('≤3 categories joined with comma', () {
      final vm = makeVm();
      final m = _menu(id: 't', snapshot: {
        'Middag': [_recipe('a')],
        'Lunch': [_recipe('b')],
        'Frukost': [_recipe('c')],
      });
      expect(vm.getMenuCategories(m), 'Middag, Lunch, Frukost');
      vm.dispose();
    });

    test('>3 categories: first two + localized "N more" label', () {
      final vm = makeVm();
      final m = _menu(id: 'big', snapshot: {
        'Middag': [_recipe('a')],
        'Lunch': [_recipe('b')],
        'Frukost': [_recipe('c')],
        'Snack': [_recipe('d')],
        'Dryck': [_recipe('e')],
      });
      // 5 cats → "Middag, Lunch " + AppLocale.current.labelAndNMore(3).
      // In the test locale (sv), labelAndNMore(3) == "och 3 till".
      expect(vm.getMenuCategories(m), 'Middag, Lunch och 3 till');
      vm.dispose();
    });
  });

  group('unreadCount', () {
    /// Badge-count consistency: when imported items are hidden from the list,
    /// they must also be excluded from the unread badge. Otherwise the badge
    /// could exceed the visible item count.
    test('excludes imported menus when showImported=false', () async {
      final viewed = _menu(id: 'v');
      final unread = _menu(id: 'u');
      final imported = _menu(id: 'i');
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [viewed, unread, imported]);
      when(() => coordinator.isMenuViewed('v')).thenReturn(true);
      when(() => coordinator.isMenuImported('i')).thenReturn(true);

      final vm = makeVm();
      vm.setShowImported(true); // load WITH imported in content
      await vm.loadContent();
      vm.setShowImported(false); // but hide from display

      expect(vm.unreadCount, 1, reason: 'only "u" counts');
      vm.dispose();
    });

    test('returns 0 when unauthenticated', () {
      permissionService.setPermissionState(currentUserId: null);
      final vm = makeVm();
      expect(vm.unreadCount, 0);
      vm.dispose();
    });
  });

  group('importableMenus', () {
    /// You cannot import your own menu (duplicate copy). Bug shape: filter
    /// compares the wrong operand (`menu.id == userId`) → self-import path
    /// always taken.
    test('excludes menus shared by current user', () async {
      final mine = _menu(id: 'mine', sharedBy: _kCurrentUid);
      final theirs = _menu(id: 'theirs', sharedBy: 'uid-other');
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [mine, theirs]);

      final vm = makeVm();
      await vm.loadContent();

      expect(vm.importableMenus.map((m) => m.id), ['theirs']);
      vm.dispose();
    });

    test('excludes already-imported menus', () async {
      final imp = _menu(id: 'imp');
      final fresh = _menu(id: 'fresh');
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [imp, fresh]);
      when(() => coordinator.isMenuImported('imp')).thenReturn(true);

      final vm = makeVm();
      vm.setShowImported(true); // keep imp in content
      await vm.loadContent();

      expect(vm.importableMenus.map((m) => m.id), ['fresh']);
      vm.dispose();
    });
  });

  group('totalRecipesInMenus', () {
    /// Sums per-menu totalRecipeCount. Bug shape: starting accumulator at
    /// 1 instead of 0 (classic fold off-by-one).
    test('sums totalRecipeCount across all menus', () async {
      final m1 = _menu(id: 'a', snapshot: {
        'Middag': [_recipe('r1'), _recipe('r2')]
      });
      final m2 = _menu(id: 'b', snapshot: {
        'Lunch': [_recipe('r3')]
      });
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [m1, m2]);

      final vm = makeVm();
      await vm.loadContent();

      expect(vm.totalRecipesInMenus, 3);
      vm.dispose();
    });

    test('returns 0 when content empty', () {
      final vm = makeVm();
      expect(vm.totalRecipesInMenus, 0);
      vm.dispose();
    });
  });

  group('contentMatchesSearch', () {
    test('matches title and sharedBy case-insensitively', () {
      final vm = makeVm();
      final m = _menu(id: '1', title: 'Sommarmeny', sharedBy: 'Alice');
      expect(vm.contentMatchesSearch(m, 'sommar'), isTrue);
      expect(vm.contentMatchesSearch(m, 'ALICE'), isTrue);
      expect(vm.contentMatchesSearch(m, 'nope'), isFalse);
      vm.dispose();
    });

    test('matches category from menuSnapshot', () {
      final vm = makeVm();
      final m = _menu(id: '1', title: 'X', snapshot: {
        'Vegetariskt': [_recipe('a')]
      });
      expect(vm.contentMatchesSearch(m, 'vegetariskt'), isTrue);
      vm.dispose();
    });

    /// shareMessage may be null. Bug shape: removing the `?? false` would
    /// throw on null while iterating the search query.
    test('handles null shareMessage without crashing', () {
      final vm = makeVm();
      final m = _menu(id: '1', shareMessage: null);
      expect(vm.contentMatchesSearch(m, 'anything'), isFalse);
      vm.dispose();
    });

    test('matches shareMessage when present', () {
      final vm = makeVm();
      final m = _menu(id: '1', shareMessage: 'Smaklig måltid!');
      expect(vm.contentMatchesSearch(m, 'smaklig'), isTrue);
      vm.dispose();
    });
  });

  group('getEngagementStats', () {
    test('reflects current cached counts', () async {
      final m1 = _menu(id: 'm1', sharedBy: _kCurrentUid, snapshot: {
        'Middag': [_recipe('a'), _recipe('b')]
      });
      final m2 = _menu(
        id: 'm2',
        sharedBy: 'uid-other',
        allowCollaboration: true,
        copyOnWriteTriggered: true,
      );
      final m3 = _menu(id: 'm3', sharedBy: 'uid-other');
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [m1, m2, m3]);
      when(() => coordinator.isMenuViewed('m1')).thenReturn(true);
      when(() => coordinator.isMenuImported('m2')).thenReturn(true);

      final vm = makeVm();
      vm.setShowImported(true);
      await vm.loadContent();

      final stats = vm.getEngagementStats();
      expect(stats['total'], 3);
      expect(stats['unread'], 2); // m1 viewed → m2,m3 unread
      expect(stats['imported'], 1);
      expect(stats['collaborative'], 1); // only m2 has isCollaborative
      expect(stats['sharedByMe'], 1);
      expect(stats['totalRecipes'], 2);
      expect(stats['withContent'], 1); // only m1 has recipes
      vm.dispose();
    });

    test('returns empty map when unauthenticated', () {
      permissionService.setPermissionState(currentUserId: null);
      final vm = makeVm();
      expect(vm.getEngagementStats(), isEmpty);
      vm.dispose();
    });
  });

  group('getCategoryStats', () {
    /// Sorted descending by count (production line 435-436 `b.value -
    /// a.value`). Bug shape: swap the operands → ascending order, breaks
    /// any UI that takes the "top N categories."
    test('aggregates and sorts descending by count', () async {
      final m1 = _menu(id: 'a', snapshot: {
        'Middag': [_recipe('r1')],
        'Lunch': [_recipe('r2')],
      });
      final m2 = _menu(id: 'b', snapshot: {
        'Middag': [_recipe('r3')],
      });
      final m3 = _menu(id: 'c', snapshot: {
        'Middag': [_recipe('r4')],
        'Frukost': [_recipe('r5')],
      });
      when(() => coordinator.getSharedMenusForUser(_kCurrentUid))
          .thenAnswer((_) async => [m1, m2, m3]);

      final vm = makeVm();
      await vm.loadContent();

      final stats = vm.getCategoryStats();
      expect(stats.keys.toList(), ['Middag', 'Lunch', 'Frukost']);
      expect(stats['Middag'], 3);
      expect(stats['Lunch'], 1);
      expect(stats['Frukost'], 1);
      vm.dispose();
    });
  });

  group('getSharedMenuById', () {
    test('returns coordinator result on success', () async {
      final m = _menu(id: 'deep-link');
      when(() => coordinator.getSharedMenuById('deep-link'))
          .thenAnswer((_) async => m);

      final vm = makeVm();
      final result = await vm.getSharedMenuById('deep-link');

      expect(result, same(m));
      vm.dispose();
    });

    test('returns null and sets hasError when coordinator throws', () async {
      when(() => coordinator.getSharedMenuById(any()))
          .thenThrow(Exception('not found'));

      final vm = makeVm();
      final result = await vm.getSharedMenuById('missing');

      expect(result, isNull);
      expect(vm.hasError, isTrue);
      vm.dispose();
    });
  });

  group('isMenuViewed / isMenuImported / isMenuDismissed', () {
    /// Auth-aware getters: ALL three return false when no user is signed in.
    /// Bug shape: forgetting the null-check would leak true from the
    /// (still-populated) coordinator cache after sign-out.
    test('return false for any menu when unauthenticated', () {
      permissionService.setPermissionState(currentUserId: null);
      when(() => coordinator.isMenuViewed(any())).thenReturn(true);
      when(() => coordinator.isMenuImported(any())).thenReturn(true);
      when(() => coordinator.isMenuDismissed(any())).thenReturn(true);

      final vm = makeVm();
      final m = _menu(id: 'x');

      expect(vm.isMenuViewed(m), isFalse);
      expect(vm.isMenuImported(m), isFalse);
      expect(vm.isMenuDismissed(m), isFalse);
      vm.dispose();
    });

    test('delegate to coordinator when authenticated', () {
      when(() => coordinator.isMenuViewed('x')).thenReturn(true);
      final vm = makeVm();
      expect(vm.isMenuViewed(_menu(id: 'x')), isTrue);
      vm.dispose();
    });
  });

  group('startCollaborativeEditing', () {
    test('forwards menu id to coordinator and returns the new id', () async {
      final m = _menu(id: 'cow-target');
      when(() => coordinator.startCollaborativeMenuEditing(
          sharedMenuId: 'cow-target')).thenAnswer((_) async => 'new-menu-id');

      final vm = makeVm();
      final result = await vm.startCollaborativeEditing(m);

      expect(result, 'new-menu-id');
      vm.dispose();
    });

    test('returns null and sets error when coordinator throws', () async {
      final m = _menu(id: 'fail');
      when(() => coordinator.startCollaborativeMenuEditing(
              sharedMenuId: any(named: 'sharedMenuId')))
          .thenThrow(Exception('boom'));

      final vm = makeVm();
      final result = await vm.startCollaborativeEditing(m);

      expect(result, isNull);
      expect(vm.hasError, isTrue);
      vm.dispose();
    });
  });

  group('contentTypeName', () {
    test('is "menu" (pinning the subclass override)', () {
      final vm = makeVm();
      expect(vm.contentTypeName, 'menu');
      vm.dispose();
    });
  });

  group('supportsPagination / loadMoreContent', () {
    /// SharedMenuViewModel does not implement real cursor-based pagination —
    /// loadContentWithPagination delegates to loadContentFromRepository.
    /// Callers that call loadMoreContent must discover this at runtime rather
    /// than silently receiving empty or duplicate results. The UnsupportedError
    /// makes the missing implementation loud.
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
    });
  });
}
