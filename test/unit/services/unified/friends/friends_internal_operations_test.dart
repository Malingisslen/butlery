/// Intent-driven unit tests for [FriendsInternalOperations].
///
/// Behaviours covered:
/// - Privacy boundary: non-owners cannot route through the full-doc-write
///   `saveCategory` path; they must be downgraded to `addSelfToCategory`
///   (privilege-escalation guard).
/// - Auth gate: sync/delete are silent no-ops when the current user is null
///   (must not throw to callers).
/// - Type guards: non-FriendCategory / non-GroupInvitationStatus inputs are
///   silently ignored, never propagated as Firestore writes.
/// - Firestore assertion-error recovery: verify + retry semantics succeed
///   only when the saved doc actually matches the intended state.
/// - Idempotency: re-adding a friend to a category that already contains
///   them does not duplicate the entry, and never calls `updateCategory`.
/// - Invitation lifecycle: `cancelled` deletes the doc (rule-safe sender
///   path); accept/reject UPDATE with the status string and a `respondedAt`
///   timestamp.
/// - Filtering: received group invitations expose only `pending` items.
/// - DisplayName: gracefully reports `'Unknown'` when UserService throws or
///   has no profile.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/friends/friends_internal_operations.dart';
import 'package:butlery/services/unified/friends/friends_state_manager.dart';
import 'package:butlery/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../test_support/base_unit_test.dart';

// ===========================================================================
// Local mocks: Mock = stubbable with when(); Fake = real-ish in-memory impl.
// ===========================================================================

class _MockFriendCategoryRepository extends Mock
    implements FriendCategoryRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockUser extends Mock implements User {
  _MockUser(this._uid);
  final String _uid;
  @override
  String get uid => _uid;
}

class _MockFriendsRepository extends Mock implements FriendsRepository {}

class _MockUserService extends Mock implements UserService {}

/// Fake state manager: avoids ChangeNotifier wiring. We stub the seven
/// surfaces FriendsInternalOperations actually reads, and capture all
/// `addCategory` / `updateCategory` / `removeCategory` calls so we can
/// assert on them without mocktail noise.
class _FakeStateManager extends Fake implements FriendsStateManager {
  List<UserProfile> _friends = const [];
  List<FriendCategory> _categories = const [];
  List<GroupInvitation> _sentInvitations = const [];
  List<GroupInvitation> _receivedInvitations = const [];

  final List<FriendCategory> addedCategories = [];
  final List<({String id, FriendCategory category})> updatedCategories = [];
  final List<String> removedCategories = [];
  final List<GroupInvitation> addedSentInvitations = [];
  final List<({String id, GroupInvitation invitation})> updatedSentInvitations =
      [];
  final List<({String id, GroupInvitation invitation})>
      updatedReceivedInvitations = [];

  void seedFriends(List<UserProfile> friends) => _friends = friends;
  void seedCategories(List<FriendCategory> cats) => _categories = cats;
  void seedSentInvitations(List<GroupInvitation> invs) =>
      _sentInvitations = invs;
  void seedReceivedInvitations(List<GroupInvitation> invs) =>
      _receivedInvitations = invs;

  @override
  List<UserProfile> get friends => _friends;
  @override
  List<FriendCategory> get categories => _categories;
  @override
  List<GroupInvitation> get sentInvitations => _sentInvitations;
  @override
  List<GroupInvitation> get receivedInvitations => _receivedInvitations;

  @override
  FriendCategory? getCategoryById(String categoryId) =>
      _categories.where((c) => c.id == categoryId).firstOrNull;

  @override
  void addCategory(FriendCategory category) => addedCategories.add(category);

  @override
  void updateCategory(String categoryId, FriendCategory category) =>
      updatedCategories.add((id: categoryId, category: category));

  @override
  void removeCategory(String categoryId) => removedCategories.add(categoryId);

  @override
  void addSentInvitation(GroupInvitation invitation) =>
      addedSentInvitations.add(invitation);

  @override
  void updateSentInvitation(String id, GroupInvitation invitation) =>
      updatedSentInvitations.add((id: id, invitation: invitation));

  @override
  void updateReceivedInvitation(String id, GroupInvitation invitation) =>
      updatedReceivedInvitations.add((id: id, invitation: invitation));
}

FriendCategory _cat({
  required String id,
  required String ownerId,
  String name = 'Family',
  List<String> memberIds = const [],
}) {
  return FriendCategory(
    id: id,
    ownerId: ownerId,
    name: name,
    friendUserIds: memberIds,
  );
}

UserProfile _profile(String uid, String displayName) {
  final now = DateTime.utc(2026, 1, 1);
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: '$uid@test.se',
    joinedAt: now,
    lastActiveAt: now,
  );
}

GroupInvitation _inv({
  required String id,
  String fromUserId = 'u-from',
  String toUserId = 'u-to',
  GroupInvitationStatus status = GroupInvitationStatus.pending,
}) {
  return GroupInvitation(
    id: id,
    groupId: 'g-1',
    groupName: 'Mat',
    groupEmoji: '🍕',
    fromUserId: fromUserId,
    fromUserName: 'Sender',
    toUserId: toUserId,
    status: status,
  );
}

void main() {
  // Used by mocktail's any() matchers on model arguments.
  setUpAll(() {
    registerFallbackValue(_cat(id: 'fallback-cat', ownerId: 'fallback-owner'));
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockFriendCategoryRepository categoryRepo;
  late _MockAuthRepository authRepo;
  late _FakeStateManager stateManager;
  late FriendsInternalOperations ops;
  late _MockFriendsRepository friendsRepo;
  late _MockUserService userService;
  late FakePermissionService permissionService;

  const currentUserId = 'me-uid';

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();

    // Defaults — individual groups override via registerMock when they
    // need to stub or verify on these.
    friendsRepo = _MockFriendsRepository();
    userService = _MockUserService();

    // PermissionService is auto-registered as FakePermissionService by
    // TestServiceLocator — reuse it and seed the current user (used by
    // createInvitationLinkInternal via DeepLinkService).
    permissionService =
        TestServiceLocator.get<PermissionService>() as FakePermissionService;
    permissionService.setPermissionState(
      currentUserId: currentUserId,
      isAuthenticated: true,
    );

    categoryRepo = _MockFriendCategoryRepository();
    authRepo = _MockAuthRepository();
    stateManager = _FakeStateManager();

    // Default: authenticated as `me-uid` with a real User stub.
    when(() => authRepo.currentUser).thenReturn(_MockUser(currentUserId));

    ops = FriendsInternalOperations(
      categoryRepository: categoryRepo,
      authRepository: authRepo,
    );
    ops.setStateManager(stateManager);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  // -------------------------------------------------------------------------
  // State-manager passthroughs
  // -------------------------------------------------------------------------

  group('state-manager passthroughs', () {
    /// Proves the read getters reflect the state manager — if a refactor
    /// silently dropped one, this test fails immediately.
    test('friendsInternal mirrors state manager friends list', () {
      final friend = _profile('f1', 'Anna');
      stateManager.seedFriends([friend]);

      expect(ops.friendsInternal, hasLength(1));
      expect(ops.friendsInternal.single.uid, 'f1');
    });

    /// Proves getCategoryByIdInternal returns the matching category and
    /// null (not throw, not first-element) when missing.
    test('getCategoryByIdInternal returns null for unknown id', () {
      stateManager.seedCategories([_cat(id: 'c1', ownerId: currentUserId)]);

      expect(ops.getCategoryByIdInternal('c1')?.id, 'c1');
      expect(ops.getCategoryByIdInternal('does-not-exist'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Type-guard contracts — non-FriendCategory inputs must be silently dropped.
  // -------------------------------------------------------------------------

  group('type-guarded mutators', () {
    /// Proves addCategoryInternal silently ignores wrong types — if the
    /// guard were `if (category is! FriendCategory) throw`, this would
    /// fail; if the guard were `is FriendCategory ? add : add` (broken),
    /// addedCategories would contain the bad value.
    test('addCategoryInternal ignores non-FriendCategory input', () {
      ops.addCategoryInternal('not-a-category');
      ops.addCategoryInternal(42);
      ops.addCategoryInternal(null);
      expect(stateManager.addedCategories, isEmpty);
    });

    test('addCategoryInternal forwards real FriendCategory to state', () {
      final c = _cat(id: 'c1', ownerId: currentUserId);
      ops.addCategoryInternal(c);
      expect(stateManager.addedCategories, [c]);
    });

    test('updateCategoryInternal ignores non-FriendCategory input', () {
      ops.updateCategoryInternal('c1', {'name': 'foo'});
      expect(stateManager.updatedCategories, isEmpty);
    });

    test('removeCategoryInternal always delegates by id', () {
      ops.removeCategoryInternal('c1');
      expect(stateManager.removedCategories, ['c1']);
    });
  });

  // -------------------------------------------------------------------------
  // syncCategoryToFirebaseInternal — PRIVACY / PRIVILEGE-ESCALATION GUARD
  // -------------------------------------------------------------------------

  group('syncCategoryToFirebaseInternal — owner routing', () {
    /// Proves the OWNER path: when current user owns the category, the
    /// full-doc-write saveCategory is invoked. Catches a bug where a
    /// refactor flipped the equality (then non-owners would full-write).
    test('owner path calls saveCategory with full document', () async {
      final c = _cat(id: 'c1', ownerId: currentUserId);
      when(() => categoryRepo.saveCategory(any(), any()))
          .thenAnswer((_) async {});

      await ops.syncCategoryToFirebaseInternal(c);

      verify(() => categoryRepo.saveCategory(currentUserId, c)).called(1);
      verifyNever(() => categoryRepo.addSelfToCategory(any(), any()));
    });

    /// CRITICAL PRIVACY TEST: a non-owner trying to sync MUST be downgraded
    /// to addSelfToCategory (members-only field update). If the routing
    /// were flipped, a member could overwrite the entire category doc —
    /// rename it, remove other members, even claim ownership client-side.
    test('non-owner path calls addSelfToCategory, never saveCategory',
        () async {
      final c = _cat(
        id: 'c1',
        ownerId: 'someone-else',
        memberIds: [currentUserId],
      );
      when(() => categoryRepo.addSelfToCategory(any(), any()))
          .thenAnswer((_) async {});

      await ops.syncCategoryToFirebaseInternal(c);

      verify(() => categoryRepo.addSelfToCategory('someone-else', 'c1'))
          .called(1);
      verifyNever(() => categoryRepo.saveCategory(any(), any()));
    });

    /// Proves the unauthenticated short-circuit returns silently (no
    /// exception bubbling to UI, no repository write attempted).
    test('returns silently when no current user', () async {
      when(() => authRepo.currentUser).thenReturn(null);
      final c = _cat(id: 'c1', ownerId: currentUserId);

      await ops.syncCategoryToFirebaseInternal(c);

      verifyNever(() => categoryRepo.saveCategory(any(), any()));
      verifyNever(() => categoryRepo.addSelfToCategory(any(), any()));
    });

    /// Proves the type guard: a stray Map or null cannot trigger a write.
    test('non-FriendCategory input does not call any repository method',
        () async {
      await ops.syncCategoryToFirebaseInternal({'fake': true});
      await ops.syncCategoryToFirebaseInternal(null);

      verifyNever(() => categoryRepo.saveCategory(any(), any()));
      verifyNever(() => categoryRepo.addSelfToCategory(any(), any()));
    });

    /// Proves real errors (non-assertion-error) propagate to the caller —
    /// callers rely on rethrow to surface failures, e.g. for retry UI.
    test('rethrows generic exceptions to caller', () async {
      final c = _cat(id: 'c1', ownerId: currentUserId);
      when(() => categoryRepo.saveCategory(any(), any()))
          .thenThrow(StateError('boom'));

      expect(
        () => ops.syncCategoryToFirebaseInternal(c),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('syncCategoryToFirebaseInternal — assertion-error recovery', () {
    /// Proves the BUG-016 recovery path: when Firestore throws an
    /// "INTERNAL ASSERTION" error but the doc was actually saved
    /// (verified by re-fetch + name match + member-count match), the
    /// method swallows the error and returns success.
    test('verified-saved doc swallows assertion error', () async {
      final c = _cat(
        id: 'c1',
        ownerId: currentUserId,
        name: 'Family',
        memberIds: ['f1', 'f2'],
      );
      var saveCalls = 0;
      when(() => categoryRepo.saveCategory(any(), any())).thenAnswer((_) async {
        saveCalls++;
        throw Exception('FIRESTORE INTERNAL ASSERTION FAILED ID=ca9');
      });
      when(() => categoryRepo.getCategory(any(), any()))
          .thenAnswer((_) async => c); // saved doc matches.

      await ops.syncCategoryToFirebaseInternal(c); // must NOT throw.

      expect(saveCalls, 1);
      verify(() => categoryRepo.getCategory(currentUserId, 'c1')).called(1);
    });

    /// Proves the member-count mismatch path: assertion error + verified
    /// doc with WRONG member count must trigger a retry save. This guards
    /// against the bug where a partial write would be silently accepted.
    test('member-count mismatch on verify triggers retry save', () async {
      final intended = _cat(
        id: 'c1',
        ownerId: currentUserId,
        name: 'Family',
        memberIds: ['f1', 'f2', 'f3'], // 3 members
      );
      final actuallySaved = _cat(
        id: 'c1',
        ownerId: currentUserId,
        name: 'Family',
        memberIds: ['f1'], // only 1 → mismatch
      );

      var saveCalls = 0;
      when(() => categoryRepo.saveCategory(any(), any())).thenAnswer((_) async {
        saveCalls++;
        if (saveCalls == 1) {
          throw Exception('Unexpected state in Firestore SDK');
        }
        // Retry succeeds.
      });
      when(() => categoryRepo.getCategory(any(), any()))
          .thenAnswer((_) async => actuallySaved);

      await ops.syncCategoryToFirebaseInternal(intended);

      expect(saveCalls, 2, reason: 'retry must run when counts mismatch');
    });
  });

  // -------------------------------------------------------------------------
  // deleteCategoryFromFirebaseInternal
  // -------------------------------------------------------------------------

  group('deleteCategoryFromFirebaseInternal', () {
    /// Proves delete is scoped to the current user's collection — never
    /// the category's stored ownerId. Caller can't pass an ownerId arg
    /// here, so this also guards against a refactor that adds one.
    test('deletes using current user id as scope', () async {
      when(() => categoryRepo.deleteCategory(any(), any()))
          .thenAnswer((_) async {});

      await ops.deleteCategoryFromFirebaseInternal('c1');

      verify(() => categoryRepo.deleteCategory(currentUserId, 'c1')).called(1);
    });

    test('returns silently when not authenticated', () async {
      when(() => authRepo.currentUser).thenReturn(null);

      await ops.deleteCategoryFromFirebaseInternal('c1');

      verifyNever(() => categoryRepo.deleteCategory(any(), any()));
    });

    test('rethrows on delete failure', () async {
      when(() => categoryRepo.deleteCategory(any(), any()))
          .thenThrow(StateError('denied'));

      expect(
        () => ops.deleteCategoryFromFirebaseInternal('c1'),
        throwsA(isA<StateError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // addFriendToCategoryInternal — IDEMPOTENCY
  // -------------------------------------------------------------------------

  group('addFriendToCategoryInternal', () {
    /// Proves the missing-category guard. If this were absent, a typo'd
    /// categoryId would crash production with an NPE on `category!.copyWith`.
    test('no-op when category not found', () {
      // No categories seeded.
      ops.addFriendToCategoryInternal('f1', 'missing-cat');

      expect(stateManager.updatedCategories, isEmpty);
    });

    /// IDEMPOTENCY: adding a friend who is already in the category must
    /// NOT enqueue an update. Otherwise we double-write and burn Firestore
    /// quota every time the UI re-renders.
    test('idempotent: friend already in category causes no update', () {
      final c = _cat(
        id: 'c1',
        ownerId: currentUserId,
        memberIds: ['f1', 'f2'],
      );
      stateManager.seedCategories([c]);

      ops.addFriendToCategoryInternal('f1', 'c1');

      expect(stateManager.updatedCategories, isEmpty);
    });

    /// Proves a new friend is appended (not replacing the list) and that
    /// updatedAt advances. We use a fixed clock to make the timestamp
    /// assertion deterministic.
    test('appends new friend, preserves existing members, bumps updatedAt', () {
      final now = DateTime.utc(2026, 5, 27, 12, 0, 0);
      final c = _cat(
        id: 'c1',
        ownerId: currentUserId,
        memberIds: ['f1'],
      );
      stateManager.seedCategories([c]);

      withClock(Clock.fixed(now), () {
        ops.addFriendToCategoryInternal('f2', 'c1');
      });

      expect(stateManager.updatedCategories, hasLength(1));
      final updated = stateManager.updatedCategories.single.category;
      expect(updated.friendUserIds, ['f1', 'f2']);
      expect(updated.updatedAt, now);
      expect(updated.id, 'c1', reason: 'id must be preserved');
      expect(updated.ownerId, currentUserId,
          reason: 'ownerId must be preserved — cannot be silently rewritten');
    });
  });

  // -------------------------------------------------------------------------
  // Invitation lifecycle
  // -------------------------------------------------------------------------

  group('updateInvitationStatusInternal', () {
    setUp(() {
      // Production code grabs FriendsRepository through the production
      // ServiceLocator. Replace the auto-registered mock so we can verify.
      friendsRepo = _MockFriendsRepository();
      TestServiceLocator.registerMock<FriendsRepository>(friendsRepo);
    });

    /// CONTRACT: a `cancelled` status (sender cancels their own invite)
    /// must DELETE the doc. Firestore rules block sender-side updates,
    /// so a refactor flipping this to `updateInvitation` would silently
    /// fail with permission denied in production.
    test('cancelled status DELETES invitation (rule-safe sender path)',
        () async {
      when(() => friendsRepo.deleteInvitation(any())).thenAnswer((_) async {});

      await ops.updateInvitationStatusInternal(
          'inv-1', GroupInvitationStatus.cancelled);

      verify(() => friendsRepo.deleteInvitation('inv-1')).called(1);
      verifyNever(() => friendsRepo.updateInvitation(any(), any()));
    });

    /// CONTRACT: accepted / rejected go through UPDATE with the status
    /// string (e.g. "accepted", not "GroupInvitationStatus.accepted") and
    /// a respondedAt timestamp. Wire-format must stay stable for clients.
    test('accepted status UPDATES with normalised string + respondedAt',
        () async {
      Map<String, dynamic>? captured;
      when(() => friendsRepo.updateInvitation(any(), any())).thenAnswer((inv) {
        captured = inv.positionalArguments[1] as Map<String, dynamic>;
        return Future.value();
      });
      final now = DateTime.utc(2026, 5, 27, 12, 0, 0);

      await withClock(Clock.fixed(now), () async {
        await ops.updateInvitationStatusInternal(
            'inv-1', GroupInvitationStatus.accepted);
      });

      verify(() => friendsRepo.updateInvitation('inv-1', any())).called(1);
      expect(captured, isNotNull);
      expect(captured!['status'], 'accepted',
          reason: 'enum value, not enum-name with class prefix');
      expect(captured!['respondedAt'], now);
      verifyNever(() => friendsRepo.deleteInvitation(any()));
    });

    test('rejected status UPDATES with "rejected" string', () async {
      Map<String, dynamic>? captured;
      when(() => friendsRepo.updateInvitation(any(), any())).thenAnswer((inv) {
        captured = inv.positionalArguments[1] as Map<String, dynamic>;
        return Future.value();
      });

      await ops.updateInvitationStatusInternal(
          'inv-1', GroupInvitationStatus.rejected);

      expect(captured!['status'], 'rejected');
    });

    /// Type guard: a stray String status must NOT propagate as a Firestore
    /// write. This is a privacy guard too — wrong-typed status could be
    /// crafted from external input.
    test('non-GroupInvitationStatus input is a no-op', () async {
      await ops.updateInvitationStatusInternal('inv-1', 'accepted'); // String!
      await ops.updateInvitationStatusInternal('inv-1', 42);

      verifyNever(() => friendsRepo.updateInvitation(any(), any()));
      verifyNever(() => friendsRepo.deleteInvitation(any()));
    });

    test('rethrows on repository failure', () async {
      when(() => friendsRepo.updateInvitation(any(), any()))
          .thenThrow(StateError('boom'));

      expect(
        () => ops.updateInvitationStatusInternal(
            'inv-1', GroupInvitationStatus.accepted),
        throwsA(isA<StateError>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // getReceivedGroupInvitationsInternal — FILTERING CONTRACT
  // -------------------------------------------------------------------------

  group('getReceivedGroupInvitationsInternal', () {
    /// Proves the pending-only filter. If a refactor flipped the predicate
    /// (`!= pending` or removed it), accepted/expired invites would
    /// resurface in the UI and let users "accept again".
    test('returns only pending invitations from received list', () {
      stateManager.seedReceivedInvitations([
        _inv(id: 'i1', status: GroupInvitationStatus.pending),
        _inv(id: 'i2', status: GroupInvitationStatus.accepted),
        _inv(id: 'i3', status: GroupInvitationStatus.rejected),
        _inv(id: 'i4', status: GroupInvitationStatus.expired),
        _inv(id: 'i5', status: GroupInvitationStatus.cancelled),
        _inv(id: 'i6', status: GroupInvitationStatus.pending),
      ]);

      final result = ops.getReceivedGroupInvitationsInternal(currentUserId);

      expect(result.map((i) => i.id).toList(), ['i1', 'i6']);
    });

    test('returns empty list when no invitations seeded', () {
      stateManager.seedReceivedInvitations(const []);
      expect(ops.getReceivedGroupInvitationsInternal(currentUserId), isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Sent-invitation tracking
  // -------------------------------------------------------------------------

  group('sent-invitation tracking', () {
    test('addSentInvitationInternal delegates only for GroupInvitation type',
        () {
      ops.addSentInvitationInternal('not-an-invitation');
      ops.addSentInvitationInternal(null);
      expect(stateManager.addedSentInvitations, isEmpty);

      final inv = _inv(id: 'i1');
      ops.addSentInvitationInternal(inv);
      expect(stateManager.addedSentInvitations, [inv]);
    });

    test('getSentInvitationByIdInternal returns null when missing', () {
      stateManager.seedSentInvitations([_inv(id: 'i1')]);

      expect((ops.getSentInvitationByIdInternal('i1') as GroupInvitation).id,
          'i1');
      expect(ops.getSentInvitationByIdInternal('missing'), isNull);
    });

    /// Proves the dual-write: updating an invitation hits BOTH the sent
    /// AND the received lists. This handles the case where the same
    /// invitation appears in both lists (rare, but happens on local
    /// optimistic updates).
    test('updateSentInvitationInternal updates both sent and received lists',
        () {
      final inv = _inv(id: 'i1', status: GroupInvitationStatus.accepted);

      ops.updateSentInvitationInternal('i1', inv);

      expect(stateManager.updatedSentInvitations, hasLength(1));
      expect(stateManager.updatedReceivedInvitations, hasLength(1));
    });

    test('updateSentInvitationInternal ignores wrong type', () {
      ops.updateSentInvitationInternal('i1', {'status': 'accepted'});

      expect(stateManager.updatedSentInvitations, isEmpty);
      expect(stateManager.updatedReceivedInvitations, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Stub email/SMS — always false until real impl ships
  // -------------------------------------------------------------------------

  group('stub channels', () {
    /// Pins the "not implemented" contract so a caller showing
    /// "invitation sent" UI never lies to the user.
    test('sendEmailInvitationInternal always returns false', () async {
      final result = await ops.sendEmailInvitationInternal(
          email: 'x@y.se', invitation: _inv(id: 'i1'));
      expect(result, isFalse);
    });

    test('sendSMSInvitationInternal always returns false', () async {
      final result = await ops.sendSMSInvitationInternal(
          phoneNumber: '+46700000000', invitation: _inv(id: 'i1'));
      expect(result, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // getCurrentUserDisplayNameInternal
  // -------------------------------------------------------------------------

  group('getCurrentUserDisplayNameInternal', () {
    setUp(() {
      TestServiceLocator.registerMock<UserService>(userService);
    });

    test('returns displayName from UserService profile', () {
      when(() => userService.currentUserProfile).thenReturn(
        _profile(currentUserId, 'Anna'),
      );

      expect(ops.getCurrentUserDisplayNameInternal(), 'Anna');
    });

    /// Proves the null-safe fallback when no profile is loaded. UI would
    /// otherwise render "null" or crash on `.displayName`.
    test('returns "Unknown" when profile is null', () {
      when(() => userService.currentUserProfile).thenReturn(null);

      expect(ops.getCurrentUserDisplayNameInternal(), 'Unknown');
    });

    /// Proves the catch-all guard. A thrown UserService (e.g. ServiceLocator
    /// not initialised) must not crash a chat header / notification badge.
    test('returns "Unknown" when UserService throws', () {
      when(() => userService.currentUserProfile)
          .thenThrow(StateError('not init'));

      expect(ops.getCurrentUserDisplayNameInternal(), 'Unknown');
    });
  });
}
