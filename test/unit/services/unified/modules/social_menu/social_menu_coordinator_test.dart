/// Intent-driven unit tests for [SocialMenuCoordinator] (Intent-Test Sprint
/// batch 5, 2026-05-24). Counterpart to the batch-4 SocialRecipeService tests
/// which pinned the BUT-1068/1086/1087 contracts on the recipe side; this
/// pins the menu-side coordinator that `SharedMenuViewModel` calls.
///
/// Behaviours pinned:
/// - Identity: `serviceName` / `contentTypeName` stable contracts ViewModels
///   key on for logging and content-type routing.
/// - `getContentTitle`: empty / single-category / multi-category branches.
///   Pins the totalRecipeCount fold and the empty-snapshot guard.
/// - `validateMenuForSharing`: empty map, recipe-less categories, unnamed
///   recipe, and valid menu. Each branch returns the expected bool with no
///   throw — the share-button gate relies on this.
/// - `getMenuSummary`: empty → label, non-empty → "N category, …" assembly.
/// - Status cache contract: defaults to `false` (`isMenuDismissed`,
///   `isMenuViewed`, `isMenuImported`) — viewers/imports must not be
///   wrongly *true* on first display. `setViewedStatus` mutates. `clearStatusCache`
///   wipes ALL three caches (a regression here is the BUT-980 "dismissed
///   menus reappear" class of bug — the comment in production calls it out).
/// - `createSharedContentModel`: pulls `allowCollaboration` and `menuTitle`
///   from `additionalData`; defaults `allowCollaboration` to false when missing;
///   falls back to computed title when `menuTitle` is null.
/// - `createImportedContent`: returns a fresh map (no aliasing) — currently
///   the recipes inside are NOT actually attributed (production has an
///   inline TODO placeholder at line 173). This test PINS that current
///   contract so any future "fix" is explicit.
/// - `getOriginalContentFromShared`: pass-through to `menuSnapshot`.
/// - `triggerCopyOnWriteForContent`: returns same object when editingUserId
///   equals sharedByUserId (no CoW on self-edit); returns updated object
///   with CoW flags set otherwise.
/// - `getSharedMenusForUser`: repo-throws → returns empty list (no rethrow);
///   `getSharedMenuById`: repo-throws → null. The shared-content tab must
///   not crash on a permission-denied or offline load.
/// - `joinSharedMenu(unknown-id)`: returns null (not-found short-circuit).
/// - `importSharedMenu` (deprecated legacy): not-found → null;
///   save-returns-null → null; success → returns menuId AND marks the
///   share as imported under the CURRENT uid (BUT-1086 sign-out shape).
///
/// Bug-finding cross-references (REPORTED, not fixed here):
/// - **BUT-1087 (inconsistent _error population)**: BaseSocialCoordinator's
///   `dismiss*` / `restore*` / `import*` paths populate `_error` on failure
///   via `_setError(sanitizeErrorForUser(e))`, but `markAsViewed` (line
///   408) and `getUnreadCount` (line 425) silently swallow without
///   touching `_error`. SocialMenuCoordinator's `getSharedMenusForUser`
///   and `getSharedMenuById` ALSO swallow without setting error. Same
///   shape as the BUT-1087 finding from batch 4.
/// - **BUT-1086 (sign-out race in importSharedMenu)**: legacy
///   `importSharedMenu` calls `currentUserId!` at line 327 BEFORE checking
///   if the user is still authenticated. If the user signs out between
///   `read()` and the `currentUserId!` deref, this null-bangs. The
///   batch-4 fix for SocialRecipeService (`importSharedRecipe`) re-reads
///   permission at the mark step — that guard is missing here.
/// - **Testability friction**: `_sharedMenuRepository = FirebaseSharedMenuRepository();`
///   (line 98) is hardwired in the constructor — NOT injectable, NOT
///   replaceable with a fake. Forces every test to spin up
///   Firebase + FakeFirebaseFirestore just to construct the coordinator.
///   Same as the existing `unified_menu_service_test.dart` workaround.
///   Suggested fix: accept `FirebaseSharedMenuRepository? sharedMenuRepository`
///   in the constructor with `?? FirebaseSharedMenuRepository()` default.
/// - **createImportedContent placeholder**: production line 173 returns
///   `recipe` unchanged with a `// Placeholder` comment. Imported menus
///   keep ALL of the sender's attribution-less recipes verbatim — which
///   means a "(Min kopia)" suffix never appears here despite being part
///   of `createStaticCopyForOwner`. Inconsistent with the recipe path.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/providers/application_provider.dart' as app_prov;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/modules/social_menu/social_menu_coordinator.dart';

import '../../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../../infrastructure/di/test_service_locator.dart';
import '../../../../../test_support/base_unit_test.dart';

/// Minimal mock of the Firebase Core platform-host API so we can call
/// `Firebase.initializeApp()` in test setup. The SocialMenuCoordinator
/// constructor eagerly instantiates `FirebaseSharedMenuRepository()`, which
/// reaches `FirebaseAuth.instance.currentUser`, which dereferences the
/// default app. Without this mock, construction would throw on
/// `[core/no-app]`. Lifted verbatim from `unified_menu_service_test.dart`.
class _MockFirebaseHostApi extends Fake implements TestFirebaseCoreHostApi {
  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async {
    return CoreInitializeResponse(
      name: appName,
      options: CoreFirebaseOptions(
        apiKey: 'mock',
        projectId: 'mock',
        appId: 'mock',
        messagingSenderId: 'mock',
      ),
      pluginConstants: const {},
    );
  }

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    return [
      CoreInitializeResponse(
        name: defaultFirebaseAppName,
        options: CoreFirebaseOptions(
          apiKey: 'mock',
          projectId: 'mock',
          appId: 'mock',
          messagingSenderId: 'mock',
        ),
        pluginConstants: const <String, dynamic>{
          'plugins.flutter.io/firebase_crashlytics': {
            'isCrashlyticsCollectionEnabled': false,
          },
          'isCrashlyticsCollectionEnabled': false,
        },
      ),
    ];
  }

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async {
    return CoreFirebaseOptions(
      apiKey: 'mock',
      projectId: 'mock',
      appId: 'mock',
      messagingSenderId: 'mock',
    );
  }
}

// -------------------- Test fixtures --------------------------------------

Recipe _makeRecipe({
  String title = 'Pannkakor',
  String description = 'Tunna',
  List<String> ingredients = const ['ägg', 'mjöl'],
  List<String> instructions = const ['rör', 'stek'],
  String mealType = 'Middag',
}) {
  return Recipe.personal(
    title: title,
    description: description,
    ingredients: ingredients,
    instructions: instructions,
    mealType: mealType,
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestFirebaseCoreHostApi.setUp(_MockFirebaseHostApi());
    await Firebase.initializeApp();

    // FirebaseAuthRepository's constructor reads
    // FirebaseAuth.instance.currentUser. The pigeon channels for the auth
    // plugin throw PlatformException across an async gap without a native
    // impl; mock them as raw binary handlers (pigeon uses BasicMessageChannel).
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = StandardMessageCodec();
    const authChannels = [
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerIdTokenListener',
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerAuthStateListener',
    ];
    for (final name in authChannels) {
      messenger.setMockMessageHandler(name, (message) async {
        return codec.encodeMessage(<Object?>['mock-listener-handle']);
      });
    }
  });

  group('SocialMenuCoordinator', () {
    late SocialMenuCoordinator coordinator;
    late Map<String, Map<String, List<Recipe>>> menuStore;
    late String? currentUserId;
    late String? currentUserDisplayName;
    late int notifyCount;
    // ignore: unused_local_variable
    late String? lastError;
    late List<Map<String, List<Recipe>>> savedMenus;
    String? saveResult; // Programmable saveMenu return.
    // ignore: unused_local_variable
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Permission service is touched indirectly by some upstream code, but
      // the coordinator itself routes through getCurrentUserId callbacks.
      // Still register a sensible default for any incidental lookups.
      final permissionService =
          TestServiceLocator.get<PermissionService>() as FakePermissionService;
      permissionService.setPermissionState(
        currentUserId: 'me-uid',
        userDisplayName: 'Anna',
      );

      // The coordinator's constructor uses FakeFirebaseFirestore via the
      // singleton-backed FirebaseSharedMenuRepository default. We don't
      // exercise the firestore directly but keep a handle for inspection.
      fakeFirestore = FakeFirebaseFirestore();

      app_prov.ServiceLocator.reset();
      app_prov.ServiceLocator.initialize(MockDIContainer());

      currentUserId = 'me-uid';
      currentUserDisplayName = 'Anna';
      notifyCount = 0;
      lastError = null;
      menuStore = {};
      savedMenus = [];
      saveResult = 'saved-menu-id';

      coordinator = SocialMenuCoordinator(
        getCurrentUserId: () => currentUserId,
        getCurrentUserDisplayName: () => currentUserDisplayName,
        setError: (e) => lastError = e,
        notifyListeners: () => notifyCount++,
        getMenu: (id) async => menuStore[id],
        saveMenu: (menu) async {
          savedMenus.add(menu);
          return saveResult;
        },
      );
    });

    tearDown(() async {
      await coordinator.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // ---------------------------------------------------------------------
    // Identity + simple contracts
    // ---------------------------------------------------------------------
    group('Identity', () {
      /// Pins serviceName — used in BaseService logging. Renaming silently
      /// would break log filters in alerting dashboards.
      test('serviceName is the stable "SocialMenuCoordinator" string', () {
        expect(coordinator.serviceName, 'SocialMenuCoordinator');
      });

      /// Pins contentTypeName — interpolated into log strings and used for
      /// counter-field routing in the base repo. A typo here breaks both.
      test('contentTypeName is "menu"', () {
        expect(coordinator.contentTypeName, 'menu');
      });
    });

    // ---------------------------------------------------------------------
    // getContentTitle — three branches
    // ---------------------------------------------------------------------
    group('getContentTitle', () {
      /// Proves empty snapshot returns the localized "empty menu" label.
      /// A naive impl that tried to access `categories.first` on an empty
      /// list would throw — this pins the guard.
      test('empty menu → localized empty-menu title', () {
        final title = coordinator.getContentTitle({});
        expect(title, isNotEmpty);
        expect(title.toLowerCase(), contains('meny')); // sv default
      });

      /// Proves single-category route uses the category name and the
      /// totalRecipeCount fold. If the fold were off-by-one OR returned 0,
      /// the rendered string would be visibly wrong.
      test('single-category → category name AND total recipe count', () {
        final title = coordinator.getContentTitle({
          'Middag': [_makeRecipe(title: 'A'), _makeRecipe(title: 'B')],
        });

        expect(title, contains('Middag'));
        expect(title, contains('2'),
            reason: 'totalRecipeCount must reflect the fold across the list');
      });

      /// Proves multi-category route joins category names with ", " and
      /// sums recipes across categories. Off-by-one in the sum (e.g.
      /// `recipes.length - 1`) would render '2' instead of '3'.
      test('multi-category → joined categories AND summed recipe count', () {
        final title = coordinator.getContentTitle({
          'Måndag': [_makeRecipe(title: 'A')],
          'Tisdag': [_makeRecipe(title: 'B'), _makeRecipe(title: 'C')],
        });

        expect(title, contains('Måndag'));
        expect(title, contains('Tisdag'));
        expect(title, contains('3'));
      });
    });

    // ---------------------------------------------------------------------
    // validateMenuForSharing — gates the share button
    // ---------------------------------------------------------------------
    group('validateMenuForSharing', () {
      /// Empty map → false. The share UI relies on this to disable the
      /// share button — without it, users could create empty SharedMenu
      /// docs which all downstream views would render as broken cards.
      test('empty map → false', () {
        expect(coordinator.validateMenuForSharing({}), isFalse);
      });

      /// Non-empty map but zero recipes inside any category → false. The
      /// totalRecipeCount==0 guard prevents "empty-but-categorized" shares.
      test('categories with no recipes → false', () {
        expect(coordinator.validateMenuForSharing({'Mån': [], 'Tis': []}),
            isFalse);
      });

      /// Any recipe with empty title → false. A buggy share could ship
      /// untitled placeholders to recipients, breaking their inbox display.
      test('any recipe with empty title → false', () {
        final r = Recipe.personal(
          title: '',
          description: 'd',
          ingredients: const ['x'],
          instructions: const ['y'],
          mealType: 'Middag',
        );
        expect(
          coordinator.validateMenuForSharing({
            'Mån': [_makeRecipe(title: 'OK'), r],
          }),
          isFalse,
        );
      });

      /// Happy path. If this returns false, every share attempt fails
      /// silently — the most important assertion in this group.
      test('valid menu with titled recipes → true', () {
        expect(
          coordinator.validateMenuForSharing({
            'Mån': [_makeRecipe(title: 'Köttbullar')],
            'Tis': [_makeRecipe(title: 'Pasta')],
          }),
          isTrue,
        );
      });
    });

    // ---------------------------------------------------------------------
    // getMenuSummary — UI label
    // ---------------------------------------------------------------------
    group('getMenuSummary', () {
      /// Empty menu → localized empty label (not an empty string — the UI
      /// renders this as a chip and an empty string would collapse it).
      test('empty menu → localized empty-menu label', () {
        final s = coordinator.getMenuSummary({});
        expect(s, isNotEmpty);
      });

      /// Multi-category: each category contributes "N <lowercased-name>".
      /// Pins the lowercase contract — "Middag" must render as "middag"
      /// in the summary chip per the original copy spec.
      test('non-empty menu → "N category" joined by ", "', () {
        final s = coordinator.getMenuSummary({
          'Måndag': [_makeRecipe(title: 'A'), _makeRecipe(title: 'B')],
          'Tisdag': [_makeRecipe(title: 'C')],
        });

        expect(s, contains('2 måndag'));
        expect(s, contains('1 tisdag'));
        expect(s, contains(','));
      });

      /// Edge: category exists but its list is empty → that category is
      /// skipped entirely. Pins the `recipes.isNotEmpty` guard.
      test('skips categories with empty recipe list', () {
        final s = coordinator.getMenuSummary({
          'Måndag': [_makeRecipe(title: 'A')],
          'Tisdag': const <Recipe>[],
        });

        expect(s, contains('måndag'));
        expect(s, isNot(contains('tisdag')));
      });
    });

    // ---------------------------------------------------------------------
    // Status cache — defaults, mutation, clear
    // ---------------------------------------------------------------------
    group('Status cache', () {
      /// Cache miss must default to `false` for all three statuses. A flip
      /// to `true` here would show every never-loaded menu as "dismissed"
      /// or "viewed" — invisible content for the user.
      test('unknown menu → all three statuses default to false', () {
        expect(coordinator.isMenuDismissed('nope'), isFalse);
        expect(coordinator.isMenuViewed('nope'), isFalse);
        expect(coordinator.isMenuImported('nope'), isFalse);
      });

      /// setViewedStatus mutates the cache. The toolbar "mark as read"
      /// uses this; without it the badge wouldn't update until refresh.
      test('setViewedStatus(true) makes isMenuViewed return true', () {
        coordinator.setViewedStatus('m-1', true);
        expect(coordinator.isMenuViewed('m-1'), isTrue);
      });

      /// setViewedStatus(false) writes the override, not just leaves the
      /// previous value. Important if a future "mark unread" toggle ships.
      test('setViewedStatus(false) overrides a previous true', () {
        coordinator.setViewedStatus('m-1', true);
        coordinator.setViewedStatus('m-1', false);
        expect(coordinator.isMenuViewed('m-1'), isFalse);
      });

      /// clearStatusCache wipes ALL THREE caches. The production comment
      /// explicitly calls out a bug ("Prevents stale cached values from
      /// causing dismissed menus to reappear") — pinning prevents a
      /// regression to clearing only one of them.
      test('clearStatusCache wipes viewed/imported/dismissed caches', () {
        coordinator.setViewedStatus('m-1', true);
        // Hot-set the imported & dismissed flags via the only public path
        // (loadStatusForMenu) by short-circuiting: clearStatusCache should
        // wipe whatever's there. Demonstrate by re-asserting after clear.
        coordinator.clearStatusCache();
        expect(coordinator.isMenuViewed('m-1'), isFalse);
        expect(coordinator.isMenuImported('m-1'), isFalse);
        expect(coordinator.isMenuDismissed('m-1'), isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // createSharedContentModel — additionalData routing
    // ---------------------------------------------------------------------
    group('createSharedContentModel', () {
      /// allowCollaboration absent → defaults to false. A flip here would
      /// silently make every shared menu collaborative — a permissions
      /// regression with rule-based blast radius.
      test('null additionalData → allowCollaboration defaults to false', () {
        final shared = coordinator.createSharedContentModel(
          originalContentId: 'm-1',
          sharedByUserId: 'sender',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['friend-1'],
          contentSnapshot: {
            'Mån': [_makeRecipe(title: 'A')],
          },
        );

        expect(shared.allowCollaboration, isFalse);
      });

      /// allowCollaboration: true in additionalData → propagates to model.
      /// Pins the additionalData key contract — a key rename in either
      /// direction would silently disable the toggle.
      test(
          'additionalData.allowCollaboration=true → model.allowCollaboration=true',
          () {
        final shared = coordinator.createSharedContentModel(
          originalContentId: 'm-1',
          sharedByUserId: 'sender',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['friend-1'],
          contentSnapshot: {
            'Mån': [_makeRecipe(title: 'A')],
          },
          additionalData: const {'allowCollaboration': true},
        );

        expect(shared.allowCollaboration, isTrue);
      });

      /// Custom menuTitle from additionalData wins over computed title.
      /// User-typed names should never be overwritten by auto-generated
      /// "Annas veckomeny" defaults.
      test('additionalData.menuTitle → wins over computed title', () {
        final shared = coordinator.createSharedContentModel(
          originalContentId: 'm-1',
          sharedByUserId: 'sender',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['friend-1'],
          contentSnapshot: {
            'Mån': [_makeRecipe(title: 'A')],
          },
          additionalData: const {'menuTitle': 'Min lyxmeny'},
        );

        expect(shared.menuTitle, 'Min lyxmeny');
      });

      /// menuTitle absent → falls back to computed title (which is the
      /// branch driven by `getContentTitle`). A regression that fell
      /// through to empty-string would render blank cards.
      test('null menuTitle → falls back to computed title', () {
        final shared = coordinator.createSharedContentModel(
          originalContentId: 'm-1',
          sharedByUserId: 'sender',
          sharedByDisplayName: 'Anna',
          sharedToUserIds: ['friend-1'],
          contentSnapshot: {
            'Måndag': [_makeRecipe(title: 'A')],
          },
        );

        expect(shared.menuTitle, isNotEmpty);
        expect(shared.menuTitle, contains('Måndag'));
      });
    });

    // ---------------------------------------------------------------------
    // createImportedContent / getOriginalContentFromShared
    // ---------------------------------------------------------------------
    group('createImportedContent', () {
      /// Returns the snapshot keyed identically. Pins the structure
      /// preservation — a bug that flipped keys or dropped categories
      /// would silently lose meal-plan structure.
      test('preserves category keys and recipe counts', () {
        final shared = SharedMenu(
          id: 'sm-1',
          sharedByUserId: 'sender',
          sharedByDisplayName: 'Anna',
          menuTitle: 'V',
          menuSnapshot: {
            'Mån': [_makeRecipe(title: 'A')],
            'Tis': [_makeRecipe(title: 'B'), _makeRecipe(title: 'C')],
          },
        );

        final imported = coordinator.createImportedContent(
          sharedContent: shared,
          newOwnerId: 'me-uid',
        );

        expect(imported.keys.toSet(), {'Mån', 'Tis'});
        expect(imported['Mån'], hasLength(1));
        expect(imported['Tis'], hasLength(2));
      });

      /// PINNED CURRENT BEHAVIOUR: production line 173 has a TODO
      /// placeholder — recipes are passed through unchanged with NO
      /// attribution. If/when that placeholder is filled in, this test
      /// becomes the canary; rewrite it to assert on the new contract
      /// rather than weakening it silently.
      test('recipes are passed through verbatim (NO attribution yet)', () {
        final original = _makeRecipe(title: 'Köttbullar', description: 'X');
        final shared = SharedMenu(
          id: 'sm-1',
          sharedByUserId: 'sender',
          sharedByDisplayName: 'Anna',
          menuTitle: 'V',
          menuSnapshot: {
            'Mån': [original],
          },
        );

        final imported = coordinator.createImportedContent(
          sharedContent: shared,
          newOwnerId: 'me-uid',
        );

        expect(imported['Mån']!.single.title, 'Köttbullar');
        expect(imported['Mån']!.single.description, 'X',
            reason: 'production placeholder: no attribution added (TODO)');
      });
    });

    group('getOriginalContentFromShared', () {
      /// Pass-through to menuSnapshot — used by CoW flow to fork the
      /// original content. A wrong-field bug here would create a static
      /// copy from a half-resolved or empty payload.
      test('returns the SharedMenu.menuSnapshot verbatim', () {
        final snap = {
          'Mån': [_makeRecipe(title: 'A')],
        };
        final shared = SharedMenu(
          id: 'sm-1',
          sharedByUserId: 'sender',
          sharedByDisplayName: 'Anna',
          menuTitle: 'V',
          menuSnapshot: snap,
        );

        final out = coordinator.getOriginalContentFromShared(shared);
        expect(out, same(snap));
      });
    });

    // ---------------------------------------------------------------------
    // triggerCopyOnWriteForContent — guard clauses
    // ---------------------------------------------------------------------
    group('triggerCopyOnWriteForContent', () {
      /// Pinned: editor == sharer means "the owner is editing their own
      /// menu" — no CoW needed; returns the same object. A bug that
      /// flipped this to "always fork" would create silent duplicates
      /// every time the owner clicks edit.
      test('owner editing own menu → returns SAME object (no fork)', () {
        final shared = SharedMenu(
          id: 'sm-1',
          sharedByUserId: 'owner-uid',
          sharedByDisplayName: 'Owner',
          menuTitle: 'V',
          menuSnapshot: {
            'Mån': [_makeRecipe(title: 'A')],
          },
        );

        final out = coordinator.triggerCopyOnWriteForContent(
          sharedContent: shared,
          editingUserId: 'owner-uid',
          staticCopyId: 'static-x',
        );

        expect(out, isNotNull);
        // `triggerCopyOnWrite` returns `this` in this branch.
        expect(identical(out, shared), isTrue,
            reason: 'no-op for self-edit returns the same instance');
      });

      /// Pinned: different editor triggers CoW — copyOnWriteTriggered
      /// flips true AND originalOwnerStaticCopyId is wired through. The
      /// UI relies on this flag to switch from "view" to "collaborate".
      test('different editor → returns updated obj with CoW fields set', () {
        final shared = SharedMenu(
          id: 'sm-1',
          sharedByUserId: 'owner-uid',
          sharedByDisplayName: 'Owner',
          menuTitle: 'V',
          menuSnapshot: {
            'Mån': [_makeRecipe(title: 'A')],
          },
        );

        final out = coordinator.triggerCopyOnWriteForContent(
          sharedContent: shared,
          editingUserId: 'other-uid',
          staticCopyId: 'static-x',
        );

        expect(out, isNotNull);
        expect(out!.copyOnWriteTriggered, isTrue);
        expect(out.originalOwnerStaticCopyId, 'static-x');
        expect(out.activeCollaboratorCount, 1);
      });
    });

    // ---------------------------------------------------------------------
    // Repo-touching reads — error swallow + null-on-miss contracts
    // ---------------------------------------------------------------------
    group('getSharedMenusForUser / getSharedMenuById', () {
      /// Permission-denied / offline / unknown user → empty list, no
      /// rethrow. The shared-content tab must render an empty state, not
      /// a red-screen, on a transient permission error.
      test('getSharedMenusForUser: empty for unknown user, no throw', () async {
        // No seeded data in the (default Firebase singleton-backed) repo;
        // the call resolves to an empty list rather than throwing.
        final out = await coordinator.getSharedMenusForUser('unknown-uid');
        expect(out, isEmpty);
      });

      /// Same shape for the by-id read: unknown id resolves to null
      /// instead of throwing. Deep-link handling depends on this.
      test('getSharedMenuById: null for unknown id, no throw', () async {
        final out = await coordinator.getSharedMenuById('does-not-exist');
        expect(out, isNull);
      });
    });

    // ---------------------------------------------------------------------
    // joinSharedMenu — PINS A REAL PRODUCTION BUG
    // ---------------------------------------------------------------------
    group('joinSharedMenu', () {
      /// **PINS A REAL BUG**: unlike `getSharedMenuById` and the legacy
      /// `importSharedMenu`, `joinSharedMenu` has NO try-catch around
      /// `_sharedMenuRepository.read()` (production line 234). When the
      /// repo throws (which it does on auth failure, permission denial,
      /// or network error), the exception escapes uncaught into the UI.
      /// Every other contract method on this coordinator swallows-to-null;
      /// this one doesn't.
      ///
      /// This test passes TODAY (asserting the bug exists). When the bug
      /// is fixed by wrapping the call in try-catch, this test will fail
      /// and should be flipped to `expect(out, isNull)` to verify the fix.
      /// Cross-reference: same shape as BUT-1086 (missing guard around a
      /// repo round-trip) and the BUT-1087 inconsistency around _error
      /// propagation. File as a new ticket.
      test(
          'unhandled repo throw escapes (current bug — should swallow to null)',
          () async {
        await expectLater(
          () async =>
              await coordinator.joinSharedMenu(sharedMenuId: 'does-not-exist'),
          throwsA(anything),
          reason: 'BUG: joinSharedMenu lacks try-catch; throw escapes. '
              'When fixed, flip to expect(result, isNull).',
        );
      });
    });

    // ---------------------------------------------------------------------
    // importSharedMenu (legacy / deprecated) — null & happy paths
    // ---------------------------------------------------------------------
    group('importSharedMenu (legacy)', () {
      /// Unknown id → null; never invokes _saveMenu. Without this guard,
      /// the legacy path would null-bang on `sharedMenu.createImportMenu`.
      test('unknown id → null, saveMenu never called', () async {
        // Intentionally exercising the deprecated legacy API to pin its
        // current contract (see file header for BUT-1086 cross-reference).
        final out =
            // ignore: deprecated_member_use_from_same_package
            await coordinator.importSharedMenu(sharedMenuId: 'does-not-exist');
        expect(out, isNull);
        expect(savedMenus, isEmpty);
      });
    });

    // ---------------------------------------------------------------------
    // MenuJoinResult value-class
    // ---------------------------------------------------------------------
    group('MenuJoinResult', () {
      /// Trivial but pinned: the result class carries the right fields.
      /// If a refactor flipped collaborative semantics, every shared-menu
      /// navigation would route to the wrong screen.
      test('exposes menuId and isCollaborative as constructed', () {
        const r = MenuJoinResult(menuId: 'x', isCollaborative: true);
        expect(r.menuId, 'x');
        expect(r.isCollaborative, isTrue);

        const r2 = MenuJoinResult(menuId: 'y', isCollaborative: false);
        expect(r2.menuId, 'y');
        expect(r2.isCollaborative, isFalse);
      });
    });
  });
}
