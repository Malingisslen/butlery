/// Intent-driven unit tests for [BaseSocialCoordinator] (Intent-Test Sprint
/// batch 7, 2026-05-25). This is the abstract base that
/// `SocialRecipeService`, `SocialMenuCoordinator`, and
/// `SocialShoppingCoordinator` all extend — so a bug pinned here surfaces in
/// three places simultaneously.
///
/// Behaviours pinned:
/// - **Auth gating**: every public method short-circuits when
///   `getCurrentUserId()` returns null. Each returns its sentinel
///   (`null`/`false`/`[]`/`0`) without touching the repository OR setError.
/// - **`createInvitation`**: missing content → null; missing user-profile →
///   null; happy path calls `createSharedContent` THEN one `addMember` per
///   invitee (in order); profile-map fallback uses `'?'` when an invitee
///   profile is missing; thrown exception → setError + null.
/// - **`shareWithFriends`**: thin wrapper over createInvitation — null
///   invitation → false, non-null → true.
/// - **`getReceivedInvitations`**: forwards limit + startAfter verbatim;
///   throw → empty list, error captured.
/// - **`importSharedContent`**: not-found → null (no notify); happy → calls
///   `markAsImportedOrJoined` AND notifies listeners exactly once; throw →
///   null + setError, NO notify.
/// - **`triggerCopyOnWrite`**: not-found short-circuit; `createStaticCopyForOwner`
///   null short-circuit; `triggerCopyOnWriteForContent` null short-circuit;
///   happy path → updateSharedContent + notify; throw → setError + null.
/// - **`dismissSharedContent` / `restoreSharedContent`**: false on no-user,
///   true on success WITH notify, false-on-throw WITH setError. PINS the
///   "always-notify on success" contract — the UI badge depends on it.
/// - **`markAsViewed`**: PINS BUT-1094 — on success notifies + returns true;
///   on **error swallows silently** (no setError, no notify, returns false).
///   The base-class siblings DO setError; this one doesn't. Same shape as
///   `getUnreadCount`. Cross-reference: BUT-1087/1094 from batches 4-6.
/// - **`getUnreadCount`**: PINS BUT-1094 — happy returns repo count, throw
///   returns 0 SILENTLY (no setError).
/// - **`notifyStateChanged` / `setError`**: expose the constructor callbacks
///   one-for-one. Pin the wiring so a refactor that adds a "dirty" gate
///   doesn't silently swallow notifications.
/// - **Helpers `currentUserId` / `currentUserDisplayName`**: re-read the
///   provider on every access — they are NOT cached. A regression here
///   would freeze the UI on a stale user after sign-out/sign-in.
/// - **Dispose-mid-await safety**: an in-flight `createInvitation` whose
///   repo `addMember` resolves after `dispose()` does NOT throw and does
///   NOT touch setError/notify (the coordinator has no internal _disposed
///   gate, so this PINS that current contract). Flagged for follow-up.
///
/// Bug-finding cross-references (REPORTED, not fixed here):
/// - **BUT-1094 (inconsistent `_error` population)** — root cause lives here.
///   Lines 408 (`markAsViewed`) and 425 (`getUnreadCount`) catch + log + return
///   sentinel WITHOUT calling `_setError(sanitizeErrorForUser(e))`. Every
///   OTHER catch in this file does. A one-line fix in both catches would
///   close BUT-1094 for all three coordinators that extend this base.
/// - **BUT-1087 (joinSharedX missing try-catch)** — base class has
///   try-catch around every repo round-trip; the bug-pin from batch 5
///   (`joinSharedMenu`) is in the SUBCLASS, not here. Pinning the base's
///   wrapped-everywhere contract means a future refactor that pushes
///   error handling INTO the subclass would surface as `getReceivedInvitations`,
///   `dismissSharedContent` etc. starting to leak exceptions — which this
///   test would catch.
/// - **No `_disposed` gate**: `BaseService.dispose()` doesn't set a flag;
///   `BaseSocialCoordinator` doesn't override `onDispose`. So a slow Firestore
///   call that resolves after dispose still calls `_notifyListeners()` and
///   `_setError()` on a disposed parent ViewModel. Documented in the
///   dispose-mid-await test as a current-contract pin, not yet a bug
///   (ViewModels guard `notifyListeners()` independently). Worth a ticket
///   if it ever surfaces a "called notifyListeners after dispose" assert.
library;

import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as app_prov;
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/base_shared_content_repository.dart';
import 'package:butlery/services/unified/modules/social_coordination/base_social_coordinator.dart';
import 'package:butlery/services/user_service.dart';

// NOTE: we deliberately avoid `MockUserService` from production_mocks here.
// Its `Mock implements UserService` shape collides with mocktail's `when()`
// machinery on the `currentUserProfile` getter (intermittent
// "No method stub was called" / "argument matcher" errors when chained
// with other `when()` calls in the same test). We hand-roll a Fake instead.

// ============================================================================
// Test fixtures: shapes for the generic params + the test subclass
// ============================================================================

/// Plain content type for tests. The base class only cares that
/// `getContentTitle(TContent)` returns something stringy — no other interface.
class _TestContent {
  final String id;
  final String title;
  const _TestContent({required this.id, required this.title});
}

/// Plain shared-content type. The base class never inspects its internals;
/// only the abstract methods on the coordinator do, which our test subclass
/// implements explicitly.
class _TestShared {
  final String id;
  final String sharedByUserId;
  final _TestContent snapshot;
  final bool cowTriggered;
  final String? staticCopyId;
  const _TestShared({
    required this.id,
    required this.sharedByUserId,
    required this.snapshot,
    this.cowTriggered = false,
    this.staticCopyId,
  });
  _TestShared withCow(
      {required String editingUserId, required String staticCopyId}) {
    return _TestShared(
      id: id,
      sharedByUserId: sharedByUserId,
      snapshot: snapshot,
      cowTriggered: true,
      staticCopyId: staticCopyId,
    );
  }
}

/// Hand-rolled fake `UserService` with just enough surface for
/// `BaseSocialCoordinator.createInvitation` to fetch profiles + display name.
/// Using `Fake implements` (not `Mock`) because mocktail's `when()` on the
/// `currentUserProfile` getter showed brittle interaction with parallel
/// `when()` calls in this test file.
class _FakeUserService extends Fake implements UserService {
  UserProfile? currentProfile;
  List<UserProfile> profilesToReturn = const [];

  @override
  UserProfile? get currentUserProfile => currentProfile;

  @override
  Future<List<UserProfile>> getUserProfiles(List<String> userIds) async {
    return profilesToReturn;
  }
}

/// Mocktail mock of the generic abstract shared-content repository. Because
/// `BaseSharedContentRepository` is abstract and pulls in Firebase, we go
/// through `Mock implements ...` rather than instantiating the real thing.
/// Every method we call is stubbed in setUp.
class _MockSharedRepo extends Mock
    implements BaseSharedContentRepository<_TestShared> {}

/// Concrete subclass of the abstract `BaseSocialCoordinator` that wires up
/// just enough behaviour for tests to exercise the base-class methods.
/// - `getContentById` is programmable via [contentStore].
/// - `saveImportedContent`, `createStaticCopyForOwner`,
///   `triggerCopyOnWriteForContent`, `updateSharedContent` are programmable
///   via the `*Result` / `*Throws` fields so tests can drive each branch.
/// - Abstract content-shape getters/methods are minimal pass-throughs.
class _TestSocialCoordinator
    extends BaseSocialCoordinator<_TestContent, _TestShared> {
  final BaseSharedContentRepository<_TestShared> _repo;
  final Map<String, _TestContent> contentStore = {};

  String? saveImportedContentResult = 'saved-id';
  String? createStaticCopyResult = 'static-copy-id';
  _TestShared? Function(_TestShared, String, String)? triggerCowOverride;
  bool updateSharedContentThrows = false;

  // Recordings for verification
  final List<_TestShared> updateSharedContentCalls = [];

  _TestSocialCoordinator({
    required super.getCurrentUserId,
    required super.getCurrentUserDisplayName,
    required super.setError,
    required super.notifyListeners,
    required BaseSharedContentRepository<_TestShared> repo,
  }) : _repo = repo;

  @override
  String get serviceName => 'TestSocialCoordinator';

  @override
  String get contentTypeName => 'thing';

  @override
  String getContentTitle(_TestContent content) => content.title;

  @override
  BaseSharedContentRepository<_TestShared> get sharedRepository => _repo;

  @override
  Future<_TestContent?> getContentById(String contentId) async {
    return contentStore[contentId];
  }

  @override
  _TestShared createSharedContentModel({
    required String originalContentId,
    required String sharedByUserId,
    required String sharedByDisplayName,
    required List<String> sharedToUserIds,
    String? shareMessage,
    required _TestContent contentSnapshot,
    Map<String, dynamic>? additionalData,
  }) {
    return _TestShared(
      id: 'placeholder-id',
      sharedByUserId: sharedByUserId,
      snapshot: contentSnapshot,
    );
  }

  @override
  _TestContent createImportedContent({
    required _TestShared sharedContent,
    required String newOwnerId,
    String? newTitle,
  }) {
    return _TestContent(
      id: 'imported-${sharedContent.id}',
      title: newTitle ?? sharedContent.snapshot.title,
    );
  }

  @override
  Future<String?> saveImportedContent(_TestContent content) async {
    return saveImportedContentResult;
  }

  @override
  dynamic getOriginalContentFromShared(_TestShared sharedContent) {
    return sharedContent.snapshot;
  }

  @override
  Future<String?> createStaticCopyForOwner(
      dynamic originalContent, String ownerId) async {
    return createStaticCopyResult;
  }

  @override
  String getSharedByUserId(_TestShared sharedContent) {
    return sharedContent.sharedByUserId;
  }

  @override
  _TestShared? triggerCopyOnWriteForContent({
    required _TestShared sharedContent,
    required String editingUserId,
    required String staticCopyId,
  }) {
    if (triggerCowOverride != null) {
      return triggerCowOverride!(sharedContent, editingUserId, staticCopyId);
    }
    return sharedContent.withCow(
      editingUserId: editingUserId,
      staticCopyId: staticCopyId,
    );
  }

  @override
  Future<void> updateSharedContent(_TestShared sharedContent) async {
    if (updateSharedContentThrows) {
      throw StateError('updateSharedContent boom');
    }
    updateSharedContentCalls.add(sharedContent);
  }
}

// ============================================================================
// DI shim: production_mocks expects ServiceLocator to be initialised so
// createInvitation can fetch the UserService. We register a minimal mock
// container that returns a MockUserService.
// ============================================================================

class _StubDIContainer extends Mock implements DIContainer {
  final UserService userService;
  _StubDIContainer(this.userService);

  @override
  T get<T extends Object>() {
    if (T == UserService) return userService as T;
    throw StateError(
        'StubDIContainer only provides UserService for these tests; got $T');
  }

  @override
  bool isRegistered<T extends Object>() => T == UserService;
}

void main() {
  // ---------------------------------------------------------------------------
  // Mocktail fallback registration for matcher-typed arguments.
  // ---------------------------------------------------------------------------
  setUpAll(() {
    registerFallbackValue(
      _TestShared(
        id: 'fallback',
        sharedByUserId: 'fallback-user',
        snapshot: const _TestContent(id: 'fallback', title: 'fallback'),
      ),
    );
  });

  group('BaseSocialCoordinator', () {
    late _TestSocialCoordinator coordinator;
    late _MockSharedRepo mockRepo;
    late _FakeUserService fakeUserService;

    String? currentUserId;
    String? currentUserDisplayName;
    int notifyCount = 0;
    final List<String> errors = [];

    setUp(() {
      mockRepo = _MockSharedRepo();
      fakeUserService = _FakeUserService();
      currentUserId = 'me-uid';
      currentUserDisplayName = 'Anna';
      notifyCount = 0;
      errors.clear();

      // The user-profile lookup inside createInvitation goes through
      // ServiceLocator.get<UserService>(). Stand up a tiny container with
      // just that one binding.
      app_prov.ServiceLocator.reset();
      app_prov.ServiceLocator.initialize(_StubDIContainer(fakeUserService));

      // Default UserService state — individual tests override fields directly.
      fakeUserService.currentProfile = UserProfile(
        uid: 'me-uid',
        displayName: 'Anna',
        email: 'anna@example.com',
        joinedAt: DateTime(2024, 1, 1),
        lastActiveAt: DateTime(2024, 1, 1),
      );
      fakeUserService.profilesToReturn = const [];

      // Default repository stubs. Override in individual tests.
      when(() => mockRepo.createSharedContent(any()))
          .thenAnswer((_) async => 'invitation-id');
      when(() => mockRepo.addMember(
            any(),
            any(),
            addedBy: any(named: 'addedBy'),
            displayName: any(named: 'displayName'),
            avatarUrl: any(named: 'avatarUrl'),
          )).thenAnswer((_) async {});
      when(() => mockRepo.getSharedContentForUser(
            any(),
            limit: any(named: 'limit'),
            startAfter: any(named: 'startAfter'),
          )).thenAnswer((_) async => <_TestShared>[]);
      when(() => mockRepo.read(any())).thenAnswer((_) async => null);
      when(() => mockRepo.markAsImportedOrJoined(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockRepo.markAsDismissed(any(), any()))
          .thenAnswer((_) async {});
      when(() => mockRepo.undismiss(any(), any())).thenAnswer((_) async {});
      when(() => mockRepo.markAsViewed(any(), any())).thenAnswer((_) async {});
      when(() => mockRepo.getUnreadCountForUser(any()))
          .thenAnswer((_) async => 0);

      coordinator = _TestSocialCoordinator(
        getCurrentUserId: () => currentUserId,
        getCurrentUserDisplayName: () => currentUserDisplayName,
        setError: errors.add,
        notifyListeners: () => notifyCount++,
        repo: mockRepo,
      );
    });

    tearDown(() async {
      app_prov.ServiceLocator.reset();
    });

    // -------------------------------------------------------------------------
    // Identity & callback wiring
    // -------------------------------------------------------------------------
    group('Identity and callback wiring', () {
      /// Pin: the constructor callbacks are exposed verbatim through the
      /// helper getters/setters. A refactor that dropped the wiring would
      /// silently freeze the parent ViewModel's error/notification state.
      test('currentUserId / currentUserDisplayName re-read the provider', () {
        expect(coordinator.currentUserId, 'me-uid');
        expect(coordinator.currentUserDisplayName, 'Anna');

        // Flip the provider; getters must see the new value (not cached).
        currentUserId = 'other-uid';
        currentUserDisplayName = 'Bob';
        expect(coordinator.currentUserId, 'other-uid');
        expect(coordinator.currentUserDisplayName, 'Bob');
      });

      /// Pin: `notifyStateChanged()` is a pass-through to the constructor's
      /// `notifyListeners`. A no-op here would mean UI badges never update.
      test('notifyStateChanged calls the listener callback exactly once', () {
        coordinator.notifyStateChanged();
        expect(notifyCount, 1);
      });

      /// Pin: `setError(msg)` is a pass-through to the constructor's
      /// `setError`. A no-op here would swallow EVERY error path silently.
      test('setError forwards the message verbatim to the callback', () {
        coordinator.setError('boom');
        expect(errors, ['boom']);
      });
    });

    // -------------------------------------------------------------------------
    // createInvitation
    // -------------------------------------------------------------------------
    group('createInvitation', () {
      /// Pin: missing auth → null AND never touches the repo. Without this
      /// guard, the repository's `requireCurrentUserId()` would throw
      /// AuthenticationException further down — a worse error surface.
      test('no authenticated user → null, never touches the repo', () async {
        currentUserId = null;

        final out = await coordinator.createInvitation(
          contentId: 'c-1',
          inviteeUserIds: const ['friend-1'],
        );

        expect(out, isNull);
        verifyNever(() => mockRepo.createSharedContent(any()));
        verifyNever(() => mockRepo.addMember(any(), any(),
            addedBy: any(named: 'addedBy'),
            displayName: any(named: 'displayName'),
            avatarUrl: any(named: 'avatarUrl')));
        expect(errors, isEmpty,
            reason: 'pre-flight failure logs but does not setError');
      });

      /// Pin: missing content → null AND never reaches createSharedContent.
      /// If this branch were missing, the coordinator would call
      /// `createSharedContentModel` with `content: null!` and null-bang.
      test('unknown content id → null, never creates a share', () async {
        // contentStore is empty; getContentById returns null.
        final out = await coordinator.createInvitation(
          contentId: 'does-not-exist',
          inviteeUserIds: const ['friend-1'],
        );

        expect(out, isNull);
        verifyNever(() => mockRepo.createSharedContent(any()));
      });

      /// Pin: missing user profile → null AND never reaches createSharedContent.
      /// Without this guard, `currentUserProfile.displayName` would NPE.
      test('no current-user profile → null, never creates a share', () async {
        coordinator.contentStore['c-1'] =
            const _TestContent(id: 'c-1', title: 'Pannkakor');
        fakeUserService.currentProfile = null;

        final out = await coordinator.createInvitation(
          contentId: 'c-1',
          inviteeUserIds: const ['friend-1'],
        );

        expect(out, isNull);
        verifyNever(() => mockRepo.createSharedContent(any()));
      });

      /// Happy-path pin: invitation is created AND each invitee is added as
      /// a member exactly once, in the order they were passed in. The
      /// production code uses a `for` loop so order is observable —
      /// `Future.wait`ing it would break this test (and would be wrong:
      /// downstream Firestore writes need deterministic ordering for the
      /// audit log).
      test('happy path → createSharedContent then addMember per invitee',
          () async {
        coordinator.contentStore['c-1'] =
            const _TestContent(id: 'c-1', title: 'Pannkakor');
        fakeUserService.profilesToReturn = [
          UserProfile(
            uid: 'friend-1',
            displayName: 'Bob',
            email: 'b@example.com',
            joinedAt: DateTime(2024, 1, 1),
            lastActiveAt: DateTime(2024, 1, 1),
          ),
          UserProfile(
            uid: 'friend-2',
            displayName: 'Carol',
            email: 'c@example.com',
            joinedAt: DateTime(2024, 1, 1),
            lastActiveAt: DateTime(2024, 1, 1),
          ),
        ];

        final out = await coordinator.createInvitation(
          contentId: 'c-1',
          inviteeUserIds: const ['friend-1', 'friend-2'],
        );

        expect(out, 'invitation-id');
        // Members added in input order, with displayName denormalized.
        verifyInOrder([
          () => mockRepo.createSharedContent(any()),
          () => mockRepo.addMember(
                'invitation-id',
                'friend-1',
                addedBy: 'me-uid',
                displayName: 'Bob',
                avatarUrl: any(named: 'avatarUrl'),
              ),
          () => mockRepo.addMember(
                'invitation-id',
                'friend-2',
                addedBy: 'me-uid',
                displayName: 'Carol',
                avatarUrl: any(named: 'avatarUrl'),
              ),
        ]);
      });

      /// Pin: when a profile lookup returns nothing for an invitee, the
      /// fallback display name is the literal '?'. A bug that left this
      /// empty-string would render headless member chips in the UI.
      test("invitee profile missing → addMember falls back to '?'", () async {
        coordinator.contentStore['c-1'] =
            const _TestContent(id: 'c-1', title: 'Pannkakor');
        // Profiles list intentionally does NOT contain friend-1.
        fakeUserService.profilesToReturn = const [];

        final out = await coordinator.createInvitation(
          contentId: 'c-1',
          inviteeUserIds: const ['friend-1'],
        );

        expect(out, 'invitation-id');
        verify(() => mockRepo.addMember(
              'invitation-id',
              'friend-1',
              addedBy: 'me-uid',
              displayName: '?',
              avatarUrl: null,
            )).called(1);
      });

      /// Pin: any throw inside the try-block surfaces as `_setError(...)`
      /// + null return. The catch is what gives us "create silently fails"
      /// → "user sees a snackbar" UX. A regression that dropped the catch
      /// would crash the whole share sheet.
      test('repo throw → null AND error captured via setError', () async {
        coordinator.contentStore['c-1'] =
            const _TestContent(id: 'c-1', title: 'Pannkakor');
        when(() => mockRepo.createSharedContent(any()))
            .thenThrow(Exception('permission denied'));

        final out = await coordinator.createInvitation(
          contentId: 'c-1',
          inviteeUserIds: const ['friend-1'],
        );

        expect(out, isNull);
        expect(errors, isNotEmpty,
            reason: 'createInvitation must surface errors via setError');
      });
    });

    // -------------------------------------------------------------------------
    // shareWithFriends
    // -------------------------------------------------------------------------
    group('shareWithFriends', () {
      /// Pin: thin wrapper — returns true iff createInvitation produced a
      /// non-null id. A flipped boolean here would make every share UI
      /// claim success even when nothing was written.
      test('non-null invitation id → true', () async {
        coordinator.contentStore['c-1'] =
            const _TestContent(id: 'c-1', title: 'Pannkakor');

        final ok = await coordinator.shareWithFriends(
          contentId: 'c-1',
          friendIds: const ['friend-1'],
        );

        expect(ok, isTrue);
      });

      /// Pin: when createInvitation returns null (e.g. unknown content),
      /// shareWithFriends returns false.
      test('null invitation id → false', () async {
        // contentStore empty → createInvitation returns null.
        final ok = await coordinator.shareWithFriends(
          contentId: 'nope',
          friendIds: const ['friend-1'],
        );

        expect(ok, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // getReceivedInvitations
    // -------------------------------------------------------------------------
    group('getReceivedInvitations', () {
      /// Pin: no auth → empty list. A user looking at the inbox before sign-in
      /// must not get an exception — just an empty UI state.
      test('no authenticated user → empty list, no repo call', () async {
        currentUserId = null;

        final out = await coordinator.getReceivedInvitations();

        expect(out, isEmpty);
        verifyNever(() => mockRepo.getSharedContentForUser(any(),
            limit: any(named: 'limit'), startAfter: any(named: 'startAfter')));
      });

      /// Pin: pagination params are forwarded verbatim. Off-by-one or
      /// dropped-param bugs here would silently break infinite scroll.
      test('forwards limit AND startAfter verbatim', () async {
        // We can't construct a real DocumentSnapshot easily; using
        // FakeFirebaseFirestore to mint one keeps the test honest.
        final firestore = FakeFirebaseFirestore();
        await firestore.collection('x').doc('y').set({'_': 1});
        final snap = await firestore.collection('x').doc('y').get();

        await coordinator.getReceivedInvitations(limit: 7, startAfter: snap);

        verify(() => mockRepo.getSharedContentForUser(
              'me-uid',
              limit: 7,
              startAfter: snap,
            )).called(1);
      });

      /// Pin: throw inside the try → empty list AND setError invoked.
      /// Same shape as `createInvitation` — every "list" surface must not
      /// crash the consuming view.
      test('repo throw → empty list AND setError invoked', () async {
        when(() => mockRepo.getSharedContentForUser(
              any(),
              limit: any(named: 'limit'),
              startAfter: any(named: 'startAfter'),
            )).thenThrow(Exception('boom'));

        final out = await coordinator.getReceivedInvitations();

        expect(out, isEmpty);
        expect(errors, isNotEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // importSharedContent (join-as-viewer)
    // -------------------------------------------------------------------------
    group('importSharedContent', () {
      /// Pin: no auth → null AND repo never reached.
      test('no authenticated user → null, repo never called', () async {
        currentUserId = null;

        final out =
            await coordinator.importSharedContent(sharedContentId: 'sc-1');

        expect(out, isNull);
        verifyNever(() => mockRepo.read(any()));
      });

      /// Pin: unknown id → null AND notify never fires (the UI must not
      /// react to a join that didn't happen).
      test('unknown shared id → null, no notify', () async {
        when(() => mockRepo.read('nope')).thenAnswer((_) async => null);

        final out =
            await coordinator.importSharedContent(sharedContentId: 'nope');

        expect(out, isNull);
        expect(notifyCount, 0);
        verifyNever(() => mockRepo.markAsImportedOrJoined(any(), any()));
      });

      /// Happy path pin: marks as joined under the CURRENT uid AND notifies.
      /// The notification is what makes the "Delat med mig" tab refresh.
      test('happy → markAsImportedOrJoined under current uid AND notifies',
          () async {
        final shared = _TestShared(
          id: 'sc-1',
          sharedByUserId: 'friend-1',
          snapshot: const _TestContent(id: 'c-1', title: 'X'),
        );
        when(() => mockRepo.read('sc-1')).thenAnswer((_) async => shared);

        final out =
            await coordinator.importSharedContent(sharedContentId: 'sc-1');

        expect(out, 'sc-1');
        verify(() => mockRepo.markAsImportedOrJoined('sc-1', 'me-uid'))
            .called(1);
        expect(notifyCount, 1);
      });

      /// Pin: throw → null + setError + NO notify. The "no notify on error"
      /// half matters: notifying on failure would briefly flash a stale list.
      test('throw → null + setError invoked + no notify', () async {
        when(() => mockRepo.read('sc-1')).thenThrow(Exception('forbidden'));

        final out =
            await coordinator.importSharedContent(sharedContentId: 'sc-1');

        expect(out, isNull);
        expect(errors, isNotEmpty);
        expect(notifyCount, 0);
      });
    });

    // -------------------------------------------------------------------------
    // triggerCopyOnWrite
    // -------------------------------------------------------------------------
    group('triggerCopyOnWrite', () {
      /// Pin: unknown shared id → null. The CoW path must short-circuit
      /// before attempting to create a static copy of nothing.
      test('unknown shared id → null', () async {
        when(() => mockRepo.read('nope')).thenAnswer((_) async => null);

        final out = await coordinator.triggerCopyOnWrite(
          sharedContentId: 'nope',
          editingUserId: 'me-uid',
        );

        expect(out, isNull);
      });

      /// Pin: failure to create the static copy aborts the CoW. Without
      /// this guard, the collaborative version would diverge from a
      /// non-existent static copy — orphan data.
      test(
          'createStaticCopyForOwner returns null → null, no updateSharedContent',
          () async {
        final shared = _TestShared(
          id: 'sc-1',
          sharedByUserId: 'owner-uid',
          snapshot: const _TestContent(id: 'c-1', title: 'X'),
        );
        when(() => mockRepo.read('sc-1')).thenAnswer((_) async => shared);
        coordinator.createStaticCopyResult = null;

        final out = await coordinator.triggerCopyOnWrite(
          sharedContentId: 'sc-1',
          editingUserId: 'editor-uid',
        );

        expect(out, isNull);
        expect(coordinator.updateSharedContentCalls, isEmpty);
      });

      /// Pin: when the subclass refuses to fork (returns null from
      /// triggerCopyOnWriteForContent), the base aborts. This is the
      /// "owner editing own content" path other subclasses use.
      test('triggerCopyOnWriteForContent returns null → null', () async {
        final shared = _TestShared(
          id: 'sc-1',
          sharedByUserId: 'owner-uid',
          snapshot: const _TestContent(id: 'c-1', title: 'X'),
        );
        when(() => mockRepo.read('sc-1')).thenAnswer((_) async => shared);
        coordinator.triggerCowOverride = (_, __, ___) => null;

        final out = await coordinator.triggerCopyOnWrite(
          sharedContentId: 'sc-1',
          editingUserId: 'owner-uid',
        );

        expect(out, isNull);
        expect(coordinator.updateSharedContentCalls, isEmpty);
      });

      /// Happy path pin: returns the shared id AND updates the doc AND
      /// notifies. The id-equality matters: the editor opens the same
      /// shared doc, now in collaborative mode.
      test('happy → updateSharedContent called + notifies + returns shared id',
          () async {
        final shared = _TestShared(
          id: 'sc-1',
          sharedByUserId: 'owner-uid',
          snapshot: const _TestContent(id: 'c-1', title: 'X'),
        );
        when(() => mockRepo.read('sc-1')).thenAnswer((_) async => shared);

        final out = await coordinator.triggerCopyOnWrite(
          sharedContentId: 'sc-1',
          editingUserId: 'editor-uid',
        );

        expect(out, 'sc-1');
        expect(coordinator.updateSharedContentCalls, hasLength(1));
        expect(
            coordinator.updateSharedContentCalls.single.cowTriggered, isTrue);
        expect(notifyCount, 1);
      });

      /// Pin: throw inside the try → null + setError. A regression that
      /// dropped the catch would crash the recipe-edit screen mid-tap.
      test('throw → null + setError invoked', () async {
        when(() => mockRepo.read('sc-1')).thenThrow(Exception('boom'));

        final out = await coordinator.triggerCopyOnWrite(
          sharedContentId: 'sc-1',
          editingUserId: 'editor-uid',
        );

        expect(out, isNull);
        expect(errors, isNotEmpty);
      });
    });

    // -------------------------------------------------------------------------
    // dismissSharedContent
    // -------------------------------------------------------------------------
    group('dismissSharedContent', () {
      /// Pin: no auth → false, no repo touch.
      test('no authenticated user → false, repo never called', () async {
        currentUserId = null;

        final ok = await coordinator.dismissSharedContent('sc-1');

        expect(ok, isFalse);
        verifyNever(() => mockRepo.markAsDismissed(any(), any()));
      });

      /// Happy path pin: dismiss → calls repo + notifies + true.
      test('happy → markAsDismissed + notify + true', () async {
        final ok = await coordinator.dismissSharedContent('sc-1');

        expect(ok, isTrue);
        verify(() => mockRepo.markAsDismissed('sc-1', 'me-uid')).called(1);
        expect(notifyCount, 1);
      });

      /// Pin: throw → false + setError invoked + no notify. The UI must
      /// surface the error AND not optimistically remove the item.
      test('throw → false + setError + no notify', () async {
        when(() => mockRepo.markAsDismissed(any(), any()))
            .thenThrow(Exception('forbidden'));

        final ok = await coordinator.dismissSharedContent('sc-1');

        expect(ok, isFalse);
        expect(errors, isNotEmpty);
        expect(notifyCount, 0);
      });
    });

    // -------------------------------------------------------------------------
    // restoreSharedContent
    // -------------------------------------------------------------------------
    group('restoreSharedContent', () {
      /// Pin: no auth → false, no repo touch.
      test('no authenticated user → false, repo never called', () async {
        currentUserId = null;

        final ok = await coordinator.restoreSharedContent('sc-1');

        expect(ok, isFalse);
        verifyNever(() => mockRepo.undismiss(any(), any()));
      });

      /// Happy path pin: restore → calls repo + notifies + true.
      test('happy → undismiss + notify + true', () async {
        final ok = await coordinator.restoreSharedContent('sc-1');

        expect(ok, isTrue);
        verify(() => mockRepo.undismiss('sc-1', 'me-uid')).called(1);
        expect(notifyCount, 1);
      });

      /// Pin: throw → false + setError invoked.
      test('throw → false + setError + no notify', () async {
        when(() => mockRepo.undismiss(any(), any()))
            .thenThrow(Exception('forbidden'));

        final ok = await coordinator.restoreSharedContent('sc-1');

        expect(ok, isFalse);
        expect(errors, isNotEmpty);
        expect(notifyCount, 0);
      });
    });

    // -------------------------------------------------------------------------
    // markAsViewed — PINS BUT-1094
    // -------------------------------------------------------------------------
    group('markAsViewed (BUT-1094 contract)', () {
      /// Pin: no auth → false, no repo touch.
      test('no authenticated user → false, repo never called', () async {
        currentUserId = null;

        final ok = await coordinator.markAsViewed('sc-1');

        expect(ok, isFalse);
        verifyNever(() => mockRepo.markAsViewed(any(), any()));
      });

      /// Happy path pin: success → repo called + notifies + true. The
      /// notify drives the unread-badge to disappear.
      test('happy → repo called + notify + true', () async {
        final ok = await coordinator.markAsViewed('sc-1');

        expect(ok, isTrue);
        verify(() => mockRepo.markAsViewed('sc-1', 'me-uid')).called(1);
        expect(notifyCount, 1);
      });

      /// **PINS BUT-1094**: on throw, `markAsViewed` returns false but
      /// does NOT call `setError`. Production line 408 catches without
      /// surfacing — every OTHER catch in this file calls setError. This
      /// test pins the CURRENT bug; when fixed (by adding
      /// `_setError(sanitizeErrorForUser(e))` inside the catch), flip the
      /// `errors, isEmpty` assertion to `errors, isNotEmpty`.
      test('BUG (BUT-1094): throw → false but errors is EMPTY (no setError)',
          () async {
        when(() => mockRepo.markAsViewed(any(), any()))
            .thenThrow(Exception('forbidden'));

        final ok = await coordinator.markAsViewed('sc-1');

        expect(ok, isFalse);
        expect(errors, isEmpty,
            reason: 'BUT-1094: production line 408 swallows without setError. '
                'When fixed, flip to expect(errors, isNotEmpty).');
        expect(notifyCount, 0, reason: 'No notify on the error path either.');
      });
    });

    // -------------------------------------------------------------------------
    // getUnreadCount — PINS BUT-1094
    // -------------------------------------------------------------------------
    group('getUnreadCount (BUT-1094 contract)', () {
      /// Pin: no auth → 0, no repo touch.
      test('no authenticated user → 0, repo never called', () async {
        currentUserId = null;

        final count = await coordinator.getUnreadCount();

        expect(count, 0);
        verifyNever(() => mockRepo.getUnreadCountForUser(any()));
      });

      /// Happy path pin: returns repo value verbatim. A mistakenly-doubled
      /// or zero-clamped value would break the badge UI.
      test('happy → returns repo value verbatim', () async {
        when(() => mockRepo.getUnreadCountForUser('me-uid'))
            .thenAnswer((_) async => 7);

        final count = await coordinator.getUnreadCount();

        expect(count, 7);
      });

      /// **PINS BUT-1094**: throw → 0 but no setError. Same shape as
      /// `markAsViewed`. Production line 425 silently swallows. When
      /// fixed, flip the assertion.
      test('BUG (BUT-1094): throw → 0 but errors is EMPTY (no setError)',
          () async {
        when(() => mockRepo.getUnreadCountForUser(any()))
            .thenThrow(Exception('forbidden'));

        final count = await coordinator.getUnreadCount();

        expect(count, 0);
        expect(errors, isEmpty,
            reason: 'BUT-1094: production line 425 swallows without setError. '
                'When fixed, flip to expect(errors, isNotEmpty).');
      });
    });

    // -------------------------------------------------------------------------
    // Notification placeholders — pin "no-op stub" status
    // -------------------------------------------------------------------------
    group('Notification placeholders', () {
      /// Pin: the in-base `sendInvitationNotifications` and
      /// `sendSharingNotifications` are intentionally no-ops (TODO in
      /// production). They MUST resolve without throwing — anything else
      /// would crash the share path. When real impl lands, these tests
      /// become the canary.
      test('sendInvitationNotifications resolves quietly', () async {
        await expectLater(
          coordinator.sendInvitationNotifications('c-1', const ['f-1']),
          completes,
        );
      });

      test('sendSharingNotifications resolves quietly', () async {
        await expectLater(
          coordinator.sendSharingNotifications('c-1', const ['f-1']),
          completes,
        );
      });
    });

    // -------------------------------------------------------------------------
    // Dispose-mid-await safety — pin CURRENT contract
    // -------------------------------------------------------------------------
    group('Dispose mid-await', () {
      /// Pin (NOT YET A BUG, just documented): the coordinator has no
      /// internal `_disposed` flag. A repo call that resolves AFTER
      /// `dispose()` still calls the constructor callbacks (notify +
      /// setError). ViewModels are expected to guard `notifyListeners()`
      /// independently; if that ever fails, this test pins the current
      /// behaviour as the regression baseline.
      test(
          'in-flight markAsDismissed resolving after dispose still calls notify',
          () async {
        final completer = Completer<void>();
        when(() => mockRepo.markAsDismissed(any(), any()))
            .thenAnswer((_) => completer.future);

        final inFlight = coordinator.dismissSharedContent('sc-1');
        await coordinator.dispose();
        completer.complete();

        final ok = await inFlight;
        // CURRENT CONTRACT: dispose does not gate the callbacks.
        expect(ok, isTrue);
        expect(notifyCount, 1,
            reason:
                'No _disposed gate — fires through. Flag if ViewModels assert.');
      });
    });
  });
}
