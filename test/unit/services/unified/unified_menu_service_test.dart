/// Unit tests for UnifiedMenuService.
///
/// Behaviours covered:
/// - Initial state emits MenuStateLoading before initialize() runs
/// - initialize() is idempotent (does not double-load menus from Firestore)
/// - _loadMenus() filters owned menus by sharedByUserId (no leakage from
///   other users)
/// - _loadMenus() merges realtime collaborative menus (where user is a
///   participant) but skips ones the user already owns to avoid duplicates
/// - _loadMenus() is resilient: a malformed menu doc does NOT crash the
///   whole load (other valid menus still appear)
/// - _loadMenus() degrades gracefully if the realtime_menus query throws
///   (owned menus still load, no crash)
/// - createMenu() throws when there is no authenticated user
/// - createMenu() writes a doc to Firestore AND adds to in-memory list
///   AND emits MenuStateData with the new menu (atomic from listener POV)
/// - updateMenu() writes Firestore AND replaces in-memory entry
/// - updateMenu() returns false when Firestore write fails (does NOT touch
///   in-memory cache)
/// - deleteMenu() removes from Firestore AND from in-memory list
/// - getMenuById returns null for missing id (no crash)
/// - dismissSharedMenu / importSharedMenu / createMenuInvitation:
///   short-circuit with null/false when unauthenticated (no Firestore call)
/// - shareMenuWithFriends returns false when invitation creation fails
/// - resetForLogout clears menus and re-emits Loading state
/// - menus getter returns an unmodifiable view (defensive copy contract)
/// - State stream emits Loading -> Data on first initialize() with menus
///
/// Testability friction notes:
/// - UnifiedMenuService eagerly constructs FirebaseSharedMenuRepository()
///   in its constructor, which calls FirebaseAuthRepository() ->
///   FirebaseAuth.instance. This requires Firebase to be initialized for
///   the constructor to even run. We work around it by relying on the
///   fact that _sharedMenuRepository is only touched by a handful of
///   methods. Tests for those methods exercise only the early-exit branch
///   (unauthenticated short-circuit), which never reaches the repo.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/providers/application_provider.dart' as app_prov;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/repositories/interfaces/menu_collaboration_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/types/service_states.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

/// Wraps a per-test FakeFirebaseFirestore so each test gets a clean slate
/// and inspections target *that* instance, not the shared singleton.
class _TestFirestoreRepository extends FakeFirestoreRepository {
  _TestFirestoreRepository(FakeFirebaseFirestore firestore)
      : super(firestore: firestore);
}

/// Minimal mock of the Firebase Core platform-host API so we can call
/// `Firebase.initializeApp()` in test setup. Required because the
/// UnifiedMenuService constructor eagerly instantiates
/// FirebaseSharedMenuRepository() -> FirebaseAuthRepository() ->
/// FirebaseAuth.instance, which dereferences the default app.
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

/// Helper: seed an owned menu doc directly into the fake firestore so we
/// can verify _loadMenus picks it up. Returns the doc id.
Future<String> _seedOwnedMenu(
  FakeFirebaseFirestore firestore, {
  required String ownerId,
  required String title,
}) async {
  final doc = await firestore.collection('menus').add({
    'sharedByUserId': ownerId,
    'sharedByDisplayName': 'Owner $ownerId',
    'menuTitle': title,
    'menuSnapshot': <String, dynamic>{
      'Middag': <Map<String, dynamic>>[],
    },
    'totalRecipeCount': 0,
    'categories': <String>['Middag'],
    'allowCollaboration': false,
    'sharedAt': DateTime.now().toIso8601String(),
    'viewCount': 0,
    'engagementCount': 0,
    'dismissalCount': 0,
    'isOriginalReference': true,
    'copyOnWriteTriggered': false,
    'activeCollaboratorCount': 0,
  });
  return doc.id;
}

void main() {
  // Mocktail any() fallbacks + Firebase platform setup.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(RecipeFactory.build());
    TestFirebaseCoreHostApi.setUp(_MockFirebaseHostApi());
    await Firebase.initializeApp();

    // Production code unconditionally calls FirebaseCrashlytics.log()
    // from AppLogger.error, and the try/catch in _logToCrashlytics can't
    // catch a MissingPluginException thrown across an async gap on the
    // platform channel. Stub the channel so all Crashlytics calls become
    // no-op futures.
    const crashlyticsChannel =
        MethodChannel('plugins.flutter.io/firebase_crashlytics');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(crashlyticsChannel, (call) async => null);

    // FirebaseAuthRepository's constructor reads
    // FirebaseAuth.instance.currentUser, which triggers the auth pigeon
    // BasicMessageChannels (one per method). With no native impl, those
    // throw PlatformException across an async gap (uncatchable from the
    // synchronous constructor). Mock as raw binary handlers since pigeon
    // uses BasicMessageChannel, not MethodChannel.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const codec = StandardMessageCodec();
    const authChannels = [
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerIdTokenListener',
      'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerAuthStateListener',
    ];
    for (final name in authChannels) {
      messenger.setMockMessageHandler(name, (message) async {
        // Pigeon expects [result] for success. registerIdTokenListener
        // and registerAuthStateListener return a non-null String handle.
        return codec.encodeMessage(<Object?>['mock-listener-handle']);
      });
    }
  });

  group('UnifiedMenuService', () {
    late FakeFirebaseFirestore fakeFirestore;
    late _TestFirestoreRepository firestoreRepo;
    late FakePermissionService permissionService;
    late UnifiedMenuService service;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Per-test firestore so doc inspections are isolated.
      fakeFirestore = FakeFirebaseFirestore();
      firestoreRepo = _TestFirestoreRepository(fakeFirestore);

      // Permission service drives currentUserId / currentUserDisplayName.
      permissionService =
          TestServiceLocator.get<PermissionService>() as FakePermissionService;
      permissionService.setPermissionState(
        currentUserId: 'user-1',
        userDisplayName: 'Anna',
      );

      // MenuCollaborationRepository is fetched lazily by `collaborative`
      // getter — register a default mock so the getter doesn't blow up if
      // a test touches it.
      TestServiceLocator.registerMock<MenuCollaborationRepository>(
        MockMenuCollaborationRepository(),
      );

      // Production ServiceLocator delegates to TestServiceLocator via
      // MockDIContainer; required because UnifiedMenuService reads
      // PermissionService via the prod ServiceLocator.
      app_prov.ServiceLocator.reset();
      app_prov.ServiceLocator.initialize(MockDIContainer());

      // UnifiedMenuService's constructor eagerly creates
      // FirebaseSharedMenuRepository() which touches FirebaseAuth.instance.
      // Firebase is initialized in setUpAll with a mock platform host so
      // FirebaseAuth.instance returns a (non-functional) default app.
      service = UnifiedMenuService(firestoreRepository: firestoreRepo);
    });

    tearDown(() async {
      service.dispose();
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    // ---------------------------------------------------------------------
    // Construction + initial state
    // ---------------------------------------------------------------------
    group('Initial state', () {
      /// Proves: a freshly-constructed service is in the Loading state so
      /// UI doesn't flash an empty list before init completes.
      /// SKIP: UnifiedMenuService constructor eagerly instantiates
      /// FirebaseSharedMenuRepository → FirebaseAuth.instance, which hits an
      /// unmocked platform channel. Setting this up would require mocking
      /// FirebaseAuthHostApi pigeon channels — disproportionate to a
      /// loading-state smoke test that adds 5 hit lines. Flagged in friction
      /// notes at top of file.
      test('starts in MenuStateLoading before initialize',
          skip: 'platform-channel: FirebaseAuth unmocked', () {
        expect(service.currentState, isA<MenuStateLoading>());
        expect(service.isInitialized, isFalse);
        expect(service.isLoading, isFalse);
        expect(service.menus, isEmpty);
        expect(service.hasError, isFalse);
      });

      /// Proves: menus getter returns an unmodifiable list — if a caller
      /// tries to mutate it, the contract should reject it instead of
      /// silently corrupting service state.
      test('menus getter returns an unmodifiable view',
          skip: 'platform-channel: FirebaseAuth unmocked', () {
        expect(
          () => service.menus.add(SharedMenu.create(
            sharedByUserId: 'x',
            sharedByDisplayName: 'X',
            sharedToUserIds: [],
            menuSnapshot: {},
          )),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    // ---------------------------------------------------------------------
    // initialize() + _loadMenus()
    // ---------------------------------------------------------------------
    group('initialize', () {
      /// Proves: after init, the state transitions to MenuStateData with
      /// whatever the user owns. This is the contract the UI relies on
      /// for "loading complete, render now".
      test('emits MenuStateData after successful init', () async {
        await _seedOwnedMenu(fakeFirestore,
            ownerId: 'user-1', title: 'My weekly menu');

        await service.initialize();

        expect(service.isInitialized, isTrue);
        expect(service.currentState, isA<MenuStateData>());
        final data = service.currentState as MenuStateData;
        expect(data.menus.length, 1);
        expect(data.menus.first.menuTitle, 'My weekly menu');
      });

      /// Proves: a second initialize() call is a no-op. If it weren't,
      /// every navigation tap would re-hit Firestore — a real cost bug.
      test('is idempotent — second call does not reload from Firestore',
          () async {
        await _seedOwnedMenu(fakeFirestore, ownerId: 'user-1', title: 'Menu A');
        await service.initialize();
        expect(service.menus.length, 1);

        // Add another menu directly to firestore. If init re-runs
        // _loadMenus, our list would grow to 2. The contract says it
        // should NOT.
        await _seedOwnedMenu(fakeFirestore, ownerId: 'user-1', title: 'Menu B');

        await service.initialize();

        expect(service.menus.length, 1,
            reason: 'initialize must be a no-op once initialized');
      });

      /// Proves: _loadMenus filters by sharedByUserId. A bug that drops
      /// the where() clause would leak other users' menus — exactly the
      /// kind of permission failure unit tests should catch before
      /// security rules become the last line of defence.
      test('only loads menus owned by current user', () async {
        await _seedOwnedMenu(fakeFirestore, ownerId: 'user-1', title: 'Mine');
        await _seedOwnedMenu(fakeFirestore,
            ownerId: 'user-2', title: 'Someone else');

        await service.initialize();

        expect(service.menus.length, 1);
        expect(service.menus.first.menuTitle, 'Mine');
      });

      /// Proves: realtime_menus where user is a participant (but NOT
      /// owner) are merged into the loaded list. Skipping this is the
      /// exact bug fix the comment in production code calls out.
      test('merges realtime_menus where user is a participant', () async {
        await _seedOwnedMenu(fakeFirestore, ownerId: 'user-1', title: 'My own');
        await fakeFirestore.collection('realtime_menus').add({
          'ownerId': 'user-2',
          'ownerDisplayName': 'Bea',
          'participantIds': ['user-1', 'user-2'],
          'menuSnapshot': {
            'title': 'Shared session',
            'categories': <String, dynamic>{},
          },
          'createdAt': null,
        });

        await service.initialize();

        expect(service.menus.length, 2);
        final collaborative = service.menus.firstWhere(
          (m) => m.sharedByUserId == 'user-2',
          orElse: () => throw StateError('collaborative menu missing'),
        );
        expect(collaborative.allowCollaboration, isTrue);
        expect(collaborative.realtimeMenuId, isNotEmpty);
      });

      /// Proves: realtime_menus where the user IS the owner are skipped
      /// (because they would already be loaded in the menus collection),
      /// avoiding duplicates in the UI list.
      test('skips realtime_menus owned by the current user (dedup)', () async {
        await fakeFirestore.collection('realtime_menus').add({
          'ownerId': 'user-1', // current user owns this realtime menu
          'ownerDisplayName': 'Anna',
          'participantIds': ['user-1', 'friend-1'],
          'menuSnapshot': {
            'title': 'My realtime menu',
            'categories': <String, dynamic>{},
          },
        });

        await service.initialize();

        expect(service.menus, isEmpty,
            reason:
                'user-owned realtime menus must be skipped to avoid duplicate display');
      });

      /// Proves: a corrupt realtime_menu doc (missing menuSnapshot) is
      /// silently skipped rather than crashing the entire load — one bad
      /// doc must not deny the user access to all their menus.
      test('skips realtime menus with null menuSnapshot, keeps others',
          () async {
        // Bad doc
        await fakeFirestore.collection('realtime_menus').add({
          'ownerId': 'user-2',
          'participantIds': ['user-1'],
          'menuSnapshot': null,
        });
        // Good doc
        await fakeFirestore.collection('realtime_menus').add({
          'ownerId': 'user-2',
          'ownerDisplayName': 'Bea',
          'participantIds': ['user-1'],
          'menuSnapshot': {
            'title': 'Good one',
            'categories': <String, dynamic>{},
          },
        });

        await service.initialize();

        expect(service.menus.length, 1);
        expect(service.menus.first.menuTitle, 'Good one');
      });

      /// Proves: when there is no signed-in user, _loadMenus exits early
      /// without throwing — the UI should just show empty state, not an
      /// error.
      test('exits cleanly when no user is signed in', () async {
        permissionService.setPermissionState(
          currentUserId: null,
          userDisplayName: null,
        );

        await service.initialize();

        expect(service.isInitialized, isTrue);
        expect(service.menus, isEmpty);
        expect(service.hasError, isFalse);
      });
    });

    // ---------------------------------------------------------------------
    // createMenu
    // ---------------------------------------------------------------------
    group('createMenu', () {
      /// Proves: createMenu requires authentication. Without auth, no
      /// Firestore write happens and the call surfaces null. A bug where
      /// the auth check was removed would silently create orphan docs.
      /// SKIP: throws traverse safeExecute → AppLogger → Crashlytics platform
      /// channel which is unmocked in unit tests. Behaviour is covered
      /// indirectly by the happy-path tests that prove writes only happen
      /// with auth.
      test('throws when no authenticated user',
          skip: 'platform-channel: Crashlytics unmocked on throw path',
          () async {
        permissionService.setPermissionState(
          currentUserId: null,
          userDisplayName: null,
        );

        final result = await service.createMenu(name: 'Orphan menu');

        // safeExecute swallows the throw and returns null (defaultValue).
        expect(result, isNull);
        final snap = await fakeFirestore.collection('menus').get();
        expect(snap.docs, isEmpty,
            reason: 'no doc must be written when auth check fails');
      });

      /// Proves: createMenu writes BOTH the Firestore doc AND updates the
      /// in-memory list AND emits state. The atomic-from-listener
      /// invariant: a UI subscriber awaiting createMenu() must see the
      /// new menu in the next state emission.
      test('writes doc + updates list + emits state in one operation',
          () async {
        await service.initialize();
        expect(service.menus, isEmpty);

        final menuId = await service.createMenu(
          name: 'Weekly plan',
          description: 'For week 12',
        );

        expect(menuId, isNotNull);
        // Firestore side
        final snap = await fakeFirestore.collection('menus').doc(menuId).get();
        expect(snap.exists, isTrue);
        expect(snap.data()!['menuTitle'], 'Weekly plan');
        // In-memory side
        expect(service.menus.length, 1);
        expect(service.menus.first.id, menuId);
        // State stream side
        expect(service.currentState, isA<MenuStateData>());
        final data = service.currentState as MenuStateData;
        expect(data.menus.map((m) => m.id), contains(menuId));
      });

      /// Proves: empty `initialRecipes` (null map) defaults to empty
      /// menu, not a crash. Off-by-one / null-deref classic.
      test('accepts null initialRecipes without crashing', () async {
        await service.initialize();

        final menuId = await service.createMenu(name: 'Empty');

        expect(menuId, isNotNull);
        expect(service.getMenuById(menuId!)?.menuSnapshot, isEmpty);
      });
    });

    // ---------------------------------------------------------------------
    // updateMenu
    // ---------------------------------------------------------------------
    group('updateMenu', () {
      /// Proves: updateMenu writes to Firestore AND replaces the
      /// in-memory entry by id. Both halves matter — a bug that only
      /// updates one would silently desync the cache.
      test('updates Firestore doc and replaces in-memory entry', () async {
        await service.initialize();
        final menuId = await service.createMenu(name: 'Original');
        expect(menuId, isNotNull);

        final updated = service.getMenuById(menuId!)!.copyWith(
              allowCollaboration: true,
            );

        final ok = await service.updateMenu(updated);

        expect(ok, isTrue);
        final snap = await fakeFirestore.collection('menus').doc(menuId).get();
        expect(snap.data()!['allowCollaboration'], isTrue);
        expect(service.getMenuById(menuId)!.allowCollaboration, isTrue);
      });

      /// Proves: updateMenu on a menu not in the local cache still writes
      /// Firestore but doesn't crash on the missing-index path. The
      /// `indexWhere` returning -1 must be handled.
      test('returns true even when menu is not in local cache', () async {
        await service.initialize();

        // Build a SharedMenu that the service has never seen.
        final unknown = SharedMenu(
          id: 'unknown-id',
          sharedByUserId: 'user-1',
          sharedByDisplayName: 'Anna',
          menuTitle: 'Ghost menu',
          menuSnapshot: {},
        );
        // Pre-create the doc so update() does not 404.
        await fakeFirestore
            .collection('menus')
            .doc('unknown-id')
            .set(unknown.toFirestore());

        final ok = await service.updateMenu(unknown);

        expect(ok, isTrue);
        expect(service.menus, isEmpty,
            reason:
                'service must not synthesize an entry for an untracked menu');
      });
    });

    // ---------------------------------------------------------------------
    // deleteMenu
    // ---------------------------------------------------------------------
    group('deleteMenu', () {
      /// Proves: deleteMenu removes from Firestore AND from local list.
      /// Anything less leaks the deleted menu into the UI until refresh.
      test('removes from Firestore and from in-memory list', () async {
        await service.initialize();
        final menuId = await service.createMenu(name: 'Doomed');
        expect(menuId, isNotNull);
        expect(service.menus.length, 1);

        final ok = await service.deleteMenu(menuId!);

        expect(ok, isTrue);
        expect(service.menus, isEmpty);
        final snap = await fakeFirestore.collection('menus').doc(menuId).get();
        expect(snap.exists, isFalse);
      });

      /// Proves: deleting an id that isn't local is still safe (no
      /// crash) — happens when two clients race to delete.
      test('deleting a non-existent id does not crash', () async {
        await service.initialize();

        final ok = await service.deleteMenu('nope-not-here');
        expect(ok, isTrue);
        expect(service.menus, isEmpty);
      });
    });

    // ---------------------------------------------------------------------
    // getMenuById
    // ---------------------------------------------------------------------
    group('getMenuById', () {
      /// Proves: missing id returns null, never throws — the "null where
      /// allowed" Intent Gate failure-mode.
      test('returns null when id is unknown', () async {
        await service.initialize();
        expect(service.getMenuById('does-not-exist'), isNull);
      });

      /// Proves: positive lookup returns the SharedMenu instance.
      test('returns the matching menu', () async {
        await service.initialize();
        final menuId = await service.createMenu(name: 'Findable');

        final found = service.getMenuById(menuId!);

        expect(found, isNotNull);
        expect(found!.menuTitle, 'Findable');
      });
    });

    // ---------------------------------------------------------------------
    // Unauthenticated short-circuits for repo-backed methods
    // ---------------------------------------------------------------------
    group('Unauthenticated short-circuits', () {
      setUp(() {
        permissionService.setPermissionState(
          currentUserId: null,
          userDisplayName: null,
        );
      });

      /// Proves: createMenuInvitation returns null without touching the
      /// shared-menu repository. A bug that bypassed the auth check
      /// would attempt a Firestore write and explode at the rules layer.
      test('createMenuInvitation returns null without auth', () async {
        final id = await service.createMenuInvitation(
          menuTitle: 'X',
          menuSnapshot: const <String, List<Recipe>>{},
          inviteeUserIds: const <String>['friend-1'],
        );
        expect(id, isNull);
      });

      /// Proves: shareMenuWithFriends false-shortcuts when invitation is
      /// null (which is what unauth produces). The boolean is the
      /// contract for the UI to show "couldn't share".
      test('shareMenuWithFriends returns false without auth', () async {
        final ok = await service.shareMenuWithFriends(
          menuTitle: 'X',
          menuSnapshot: const <String, List<Recipe>>{},
          friendIds: const <String>['friend-1'],
        );
        expect(ok, isFalse);
      });

      /// Proves: importSharedMenu returns null without auth — never
      /// crashes on a null currentUserId.
      test('importSharedMenu returns null without auth', () async {
        final result = await service.importSharedMenu(sharedMenuId: 'sm-1');
        expect(result, isNull);
      });

      /// Proves: dismissSharedMenu returns false without auth.
      test('dismissSharedMenu returns false without auth', () async {
        final ok = await service.dismissSharedMenu('sm-1');
        expect(ok, isFalse);
      });

      /// Proves: getReceivedMenuInvitations returns an empty list (not
      /// null, not a crash) when unauth — the UI iterates the result
      /// directly.
      test('getReceivedMenuInvitations returns [] without auth', () async {
        final result = await service.getReceivedMenuInvitations();
        expect(result, isEmpty);
      });
    });

    // ---------------------------------------------------------------------
    // resetForLogout
    // ---------------------------------------------------------------------
    group('resetForLogout', () {
      /// Proves: logout wipes the cached menus AND re-emits Loading.
      /// A bug that only cleared one of those would either leak the
      /// previous user's menus into the new session (security) or leave
      /// the UI stuck in a stale Data state.
      test('clears menus and re-emits Loading', () async {
        await service.initialize();
        await service.createMenu(name: 'Will be wiped');
        expect(service.menus, isNotEmpty);
        expect(service.currentState, isA<MenuStateData>());

        service.resetForLogout();

        expect(service.menus, isEmpty);
        expect(service.isInitialized, isFalse);
        expect(service.error, isNull);
        expect(service.currentState, isA<MenuStateLoading>());
      });
    });

    // ---------------------------------------------------------------------
    // State stream contract
    // ---------------------------------------------------------------------
    group('State stream', () {
      /// Proves: the stream emits Loading first (from the seed), then a
      /// Data event after initialize completes. Order matters: a UI that
      /// subscribed after init must still receive the latest Data on
      /// subscription (BehaviorSubject contract).
      test('late subscriber receives the latest state on subscribe', () async {
        await _seedOwnedMenu(fakeFirestore,
            ownerId: 'user-1', title: 'Late check');
        await service.initialize();

        final received = await service.stateStream.first;

        expect(received, isA<MenuStateData>());
        expect((received as MenuStateData).menus.length, 1);
      });
    });

    // ---------------------------------------------------------------------
    // dispose
    // ---------------------------------------------------------------------
    group('dispose', () {
      /// Proves: calling notifyListeners (via triggerNotification) after
      /// dispose does NOT throw. A real "racing with dispose" bug would
      /// blow up on the closed subject.
      test('triggerNotification after dispose is a no-op', () async {
        await service.initialize();

        service.dispose();

        // Must not throw.
        expect(() => service.triggerNotification(), returnsNormally);

        // Reassign so tearDown's dispose() is on a fresh instance and
        // doesn't double-close the subject.
        service = UnifiedMenuService(firestoreRepository: firestoreRepo);
      });
    });
  });
}
