import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/moderation/content_filter_service.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/viewmodels/social_recipe/social_comments_manager.dart';
import 'package:butlery/services/user_service.dart' as user_svc;

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/firestore_singleton.dart';
import '../../infrastructure/mocks/production_mocks.dart';

import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;
import 'package:butlery/core/di/di_container.dart';

void main() {
  group('Block Enforcement', () {
    late UnifiedFriendsService friendsService;
    late FakeFirestoreRepository mockFirestoreRepo;
    late MockFirebaseAuthRepository mockAuthRepo;
    late FakePermissionService mockPermissionService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      final productionContainer = DIContainer();
      prod_locator.ServiceLocator.initialize(productionContainer);

      mockFirestoreRepo = FakeFirestoreRepository();
      mockAuthRepo = MockFirebaseAuthRepository();
      // Auth state mirrors the permission service; FirebaseBlockRepository
      // (registered below) calls requireCurrentUserId() on every write.
      mockAuthRepo.setAuthState(userId: 'test-user-id');
      // UnifiedFriendsService.initialize() subscribes to authStateChanges;
      // empty stream is enough — no actual auth events are needed for the
      // block-enforcement assertions.
      when(
        () => mockAuthRepo.authStateChanges(),
      ).thenAnswer((_) => const Stream<User?>.empty());
      mockPermissionService = FakePermissionService();

      mockPermissionService.setPermissionState(
        currentUserId: 'test-user-id',
        defaultHasPermission: true,
      );

      final mockUserService = MockUserService();
      mockUserService.setUserState(
        currentUser: UserProfile(
          uid: 'test-user-id',
          email: 'test@example.com',
          displayName: 'Test User',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      );

      TestServiceLocator.registerMock<PermissionService>(mockPermissionService);
      TestServiceLocator.registerMock<user_svc.UserService>(mockUserService);
      // BaseService.executeServiceOperation runs an _isAuthenticated()
      // pre-flight check that resolves AuthRepository from the global
      // ServiceLocator. Register the same mock under the interface type
      // so FriendsManagementOperations.removeFriend doesn't short-circuit
      // before touching the relationship repository.
      TestServiceLocator.registerMock<AuthRepository>(mockAuthRepo);

      // UnifiedFriendsService._initializeModules() resolves FirebaseBlockRepository
      // from ServiceLocator. Register one wired to the same FakeFirebaseFirestore
      // that FakeFirestoreRepository falls through to (FirestoreSingleton.instance)
      // so the block repo, the friends repo, and the test all see one Firestore.
      TestServiceLocator.registerMock<FirebaseBlockRepository>(
        FirebaseBlockRepository(
          firestore: FirestoreSingleton.instance,
          authRepository: mockAuthRepo,
        ),
      );

      friendsService = UnifiedFriendsService(
        firestoreRepository: mockFirestoreRepo,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    test('sendFriendRequest rejects when target is blocked', () async {
      await friendsService.initialize();

      // Seed the blocked-users state via the internal helper —
      // blockedUsers is exposed as Set.unmodifiable so direct .add throws.
      friendsService.addBlockedUserInternal('blocked-target');

      // Attempt to send friend request to blocked user
      final result = await friendsService.management.sendFriendRequest(
        'blocked-target',
      );

      // Should fail because target is blocked
      expect(result, isFalse);

      // Verify no outgoing request was created
      expect(friendsService.outgoingRequests, isEmpty);
    });

    // BUT-2070: un-skipped 2026-09-10. The stated reason (fake_cloud_firestore
    // vs FieldValue.increment) was closed by `installFakeFieldValuePlatform()`
    // in BaseTest.setup(); what actually kept it red was the fixture's
    // half-logged-in auth double, fixed below.
    //
    // What this measures: block -> friendship-removal -> blocked-set, end to
    // end through the real service and the real repository. It does NOT
    // discriminate BUT-2022's write ORDER — block-first and cleanup-first
    // reach the same end state on the happy path, and this test would have
    // passed against the old code. The order is pinned where the two write
    // paths diverge, on the FAILING block:
    // `friends_management_operations_test.dart`, group
    // 'block ordering and partial outcomes (BUT-2022)'.
    test(
      'blockUser removes existing friendship AND adds to blocked list',
      () async {
        // setUp leaves `currentUser` null while `currentUserId` answers, which
        // is enough for every write on this path but NOT for
        // UnifiedFriendsService.initialize(): it only starts the state manager
        // when `currentUser != null`, and the state manager is what subscribes
        // to `watchBlockedUserIds()`. Without that subscription nothing ever
        // populates `blockedUsers`, because `blockUser` does not touch the
        // in-memory set itself.
        mockAuthRepo.setAuthState(
          user: FakeUser(uid: 'test-user-id'),
          userId: 'test-user-id',
        );

        // Seed the mutual friendship at users/<a>/friends/<b> BEFORE
        // initialize(), so the friends list comes from the repository the way
        // production builds it. Seeding the in-memory list instead
        // (`addFriendInternal`) is wiped by the friends stream the moment the
        // state manager is running.
        await mockFirestoreRepo.firestore
            .collection('users')
            .doc('test-user-id')
            .collection('friends')
            .doc('friend-to-block')
            .set({'friendId': 'friend-to-block'});
        await mockFirestoreRepo.firestore
            .collection('users')
            .doc('friend-to-block')
            .collection('friends')
            .doc('test-user-id')
            .set({'friendId': 'test-user-id'});
        await mockFirestoreRepo.firestore
            .collection('users')
            .doc('friend-to-block')
            .set({
              'uid': 'friend-to-block',
              'displayName': 'Friend To Block',
              'email': 'friend@example.com',
            });

        // Public profiles carry friendsCount: 1 so the FieldValue.increment(-1)
        // inside removeMutualFriends commits without "document not found".
        await mockFirestoreRepo.firestore
            .collection('public_profiles')
            .doc('test-user-id')
            .set({'displayName': 'Test User', 'friendsCount': 1});
        await mockFirestoreRepo.firestore
            .collection('public_profiles')
            .doc('friend-to-block')
            .set({'displayName': 'Friend To Block', 'friendsCount': 1});

        await friendsService.initialize();

        // Both halves start in the state the assertions below must leave:
        // friend present, not blocked. Without these two the post-assertions
        // pass for free.
        expect(
          friendsService.friends.any((f) => f.uid == 'friend-to-block'),
          isTrue,
        );
        expect(
          friendsService.blockedUsers.contains('friend-to-block'),
          isFalse,
        );

        // Block the user
        final result = await friendsService.management.blockUser(
          'friend-to-block',
        );

        expect(result.blockLanded, isTrue);

        // Verify friendship was removed
        expect(
          friendsService.friends.any((f) => f.uid == 'friend-to-block'),
          isFalse,
        );

        // Verify user was added to blocked list
        expect(friendsService.blockedUsers.contains('friend-to-block'), isTrue);
      },
    );

    // BUT-2070: this case used to construct a SocialCommentsManager, never
    // call it, and then assert on a `where(...)` it re-implemented inline —
    // green whatever the production filter did. It now drives the real
    // manager through `refreshComments`, the public entry point that runs
    // `_filterBlockedUsers` over what the recipe service returned.
    //
    // The recipe service is a LOCAL mocktail double, not
    // `MockUnifiedRecipeService`: that one's `.social` is a hard-wired fake
    // whose `getComments` returns `[]` unconditionally, so the filter would
    // run over an empty list and pass for free — the same vacuity in a new
    // costume. Same reason the sibling suite
    // `social_comments_manager_test.dart` declares its own doubles.
    group('SocialCommentsManager filters blocked authors', () {
      late _MockRecipeService mockRecipeService;
      late _MockSocialOps mockSocialOps;
      late MockUnifiedFriendsService mockFriendsService;

      List<RecipeComment> fourComments() => [
        RecipeComment(
          id: 'c1',
          recipeId: 'recipe-1',
          authorId: 'normal-user',
          authorDisplayName: 'Normal User',
          text: 'Great recipe!',
        ),
        RecipeComment(
          id: 'c2',
          recipeId: 'recipe-1',
          authorId: 'blocked-user-1',
          authorDisplayName: 'Blocked User 1',
          text: 'Spam comment',
        ),
        RecipeComment(
          id: 'c3',
          recipeId: 'recipe-1',
          authorId: 'another-user',
          authorDisplayName: 'Another User',
          text: 'Nice!',
        ),
        RecipeComment(
          id: 'c4',
          recipeId: 'recipe-1',
          authorId: 'blocked-user-2',
          authorDisplayName: 'Blocked User 2',
          text: 'Another spam',
        ),
      ];

      setUp(() {
        mockRecipeService = _MockRecipeService();
        mockSocialOps = _MockSocialOps();
        when(() => mockRecipeService.social).thenReturn(mockSocialOps);
        when(
          () => mockSocialOps.getComments(recipeId: any(named: 'recipeId')),
        ).thenAnswer((_) async => fourComments());

        mockFriendsService = MockUnifiedFriendsService();
        // Registered BEFORE the manager is built: its constructor resolves the
        // friends service once and keeps the reference.
        TestServiceLocator.registerMock<UnifiedFriendsService>(
          mockFriendsService,
        );
        TestServiceLocator.registerMock<ContentFilterService>(
          MockContentFilterService(),
        );
      });

      test('a blocked author comment does not reach the list', () async {
        mockFriendsService.setFriendsState(
          blockedUsers: {'blocked-user-1', 'blocked-user-2'},
        );
        final manager = SocialCommentsManager(mockRecipeService);
        addTearDown(manager.dispose);

        await manager.refreshComments('recipe-1');

        expect(
          manager.comments.map((c) => c.authorId),
          ['normal-user', 'another-user'],
        );
        expect(manager.commentCount, 2);
      });

      // The control arm. Without it the case above cannot tell filtering from
      // a service that simply returned less.
      test('with nobody blocked, all four pass through', () async {
        mockFriendsService.setFriendsState(blockedUsers: const <String>{});
        final manager = SocialCommentsManager(mockRecipeService);
        addTearDown(manager.dispose);

        await manager.refreshComments('recipe-1');

        expect(manager.comments, hasLength(4));
      });
    });
  });
}

/// Minimal mock for ContentFilterService to avoid interference in comment tests
class MockContentFilterService extends Mock implements ContentFilterService {}

/// Local doubles for the comment-filter group. `MockUnifiedRecipeService`'s
/// `.social` is a hard-wired fake returning `[]`, which would make the filter
/// run over nothing.
class _MockRecipeService extends Mock implements UnifiedRecipeService {}

class _MockSocialOps extends Mock implements SocialRecipeOperations {}
