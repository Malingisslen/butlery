// test/unit/services/unified/operations/friends_management_operations_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_relationship_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/analytics/trackers/social_events_tracker.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

class _MockFirebaseBlockRepository extends Mock
    implements FirebaseBlockRepository {}

class _MockFriendRelationshipRepository extends Mock
    implements FriendRelationshipRepository {}

/// Records rather than swallows: the shared MockSocialEventsTracker is a
/// no-op fake, so with it a repoint of logUserBlocked to logUserUnblocked
/// ships green.
class _RecordingSocialTracker extends Fake implements SocialEventsTracker {
  final blocked = <String>[];
  final unblocked = <String>[];

  @override
  Future<void> logUserBlocked({required String blockedUserId}) async =>
      blocked.add(blockedUserId);

  @override
  Future<void> logUserUnblocked({required String unblockedUserId}) async =>
      unblocked.add(unblockedUserId);
}

/// A tracker whose calls THROW, for BUT-2069's question: can telemetry decide
/// what the user is told? It records the attempt first, so a test can tell
/// "the call never happened" apart from "the call happened and blew up".
class _ThrowingSocialTracker extends Fake implements SocialEventsTracker {
  final attempts = <String>[];

  @override
  Future<void> logUserBlocked({required String blockedUserId}) async {
    attempts.add(blockedUserId);
    throw Exception('analytics backend down');
  }

  @override
  Future<void> logUserUnblocked({required String unblockedUserId}) async {
    attempts.add(unblockedUserId);
    throw Exception('analytics backend down');
  }
}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

void main() {
  group('FriendsManagementOperations', () {
    late MockUnifiedFriendsService mockParentService;
    late _MockFriendRelationshipRepository mockRelationshipRepo;
    late FakeFirebaseFirestore fakeFirestore;
    late FriendsManagementOperations managementOperations;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();

      registerFallbackValue(
        UserProfile(
          uid: 'test',
          email: 'test@example.com',
          displayName: 'Test User',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        ),
      );
      registerFallbackValue(
        FriendRequest(
          id: 'test',
          fromUserId: 'test',
          toUserId: 'test',
          sentAt: DateTime.now(),
        ),
      );
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Production ServiceLocator bridge: the FriendsManagementOperations
      // constructor calls ServiceLocator.get<UserService>().
      // MockDIContainer delegates to GetIt.instance which TestServiceLocator
      // already populated with mocks.
      production.ServiceLocator.reset();
      production.ServiceLocator.initialize(MockDIContainer());

      // executeServiceOperation requires auth: configure FakeAuthRepository
      final authRepo =
          TestServiceLocator.get<AuthRepository>() as FakeAuthRepository;
      authRepo.setAuthState(userId: 'current_user', isAuthenticated: true);

      mockParentService = MockUnifiedFriendsService();
      mockRelationshipRepo = _MockFriendRelationshipRepository();
      fakeFirestore = FakeFirebaseFirestore();

      mockParentService.setFriendsState(
        friends: [],
        incomingRequests: [],
        outgoingRequests: [],
        isInitialized: true,
      );

      managementOperations = FriendsManagementOperations(
        getCurrentUserId: () => 'current_user',
        getCurrentUserDisplayName: () => 'Test User',
        getFriends: () => mockParentService.friends,
        getIncomingRequests: () => mockParentService.incomingRequests,
        getOutgoingRequests: () => mockParentService.outgoingRequests,
        getBlockedUsers: () => <String>{},
        getFirestore: () => fakeFirestore,
        relationshipRepository: mockRelationshipRepo,
        addOutgoingRequestInternal:
            mockParentService.addOutgoingRequestInternal,
        removeOutgoingRequestInternal:
            mockParentService.removeOutgoingRequestInternal,
        removeIncomingRequestInternal:
            mockParentService.removeIncomingRequestInternal,
        addFriendInternal: mockParentService.addFriendInternal,
        removeFriendInternal: mockParentService.removeFriendInternal,
        syncFriendRequestToFirebase:
            mockParentService.syncFriendRequestToFirebase,
        updateFriendRequestStatus: mockParentService.updateFriendRequestStatus,
        refresh: () => mockParentService.refresh(),
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Core Functionality', () {
      test('should initialize with parent service', () {
        expect(managementOperations, isNotNull);
        expect(
          managementOperations.serviceName,
          equals('FriendsManagementOperations'),
        );
      });

      test('should get friend statistics', () {
        final friend1 = UserProfile(
          uid: 'friend_1',
          email: 'friend1@example.com',
          displayName: 'Friend 1',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        final friend2 = UserProfile(
          uid: 'friend_2',
          email: 'friend2@example.com',
          displayName: 'Friend 2',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );

        final pendingRequest = FriendRequest(
          id: 'request_1',
          fromUserId: 'sender',
          toUserId: 'current_user',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );

        mockParentService.setFriendsState(
          friends: [friend1, friend2],
          incomingRequests: [pendingRequest],
          outgoingRequests: [],
        );

        final stats = managementOperations.getFriendStats();

        expect(stats['totalFriends'], equals(2));
        expect(stats['incomingRequests'], equals(1));
        expect(stats['outgoingRequests'], equals(0));
        // blockedUsers comes from the getBlockedUsers callback (empty set)
        expect(stats['blockedUsers'], equals(0));
      });
    });

    group('Friend Removal', () {
      test('should remove friend successfully', () async {
        final friend = UserProfile(
          uid: 'friend_123',
          email: 'friend@example.com',
          displayName: 'Test Friend',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );

        mockParentService.setFriendsState(
          friends: [friend],
        );
        when(
          () => mockParentService.removeFriendInternal('friend_123'),
        ).thenReturn(null);
        when(
          () => mockRelationshipRepo.removeMutualFriends(any(), any()),
        ).thenAnswer((_) async {});

        final success = await managementOperations.removeFriend('friend_123');

        expect(success, isTrue);
        verify(
          () => mockParentService.removeFriendInternal('friend_123'),
        ).called(1);
        verify(
          () => mockRelationshipRepo.removeMutualFriends(
            'current_user',
            'friend_123',
          ),
        ).called(1);
      });

      test('should not remove non-existent friend', () async {
        mockParentService.setFriendsState(
          friends: [],
        );

        final success = await managementOperations.removeFriend('not_a_friend');

        expect(success, isFalse);
      });
    });

    group('Cancel Friend Request', () {
      test('should cancel outgoing request and update Firebase', () async {
        final request = FriendRequest(
          id: 'req_1',
          fromUserId: 'current_user',
          toUserId: 'recipient',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );

        mockParentService.setFriendsState(
          outgoingRequests: [request],
          isInitialized: true,
        );
        when(
          () => mockParentService.removeOutgoingRequestInternal('req_1'),
        ).thenReturn(null);
        when(
          () => mockParentService.updateFriendRequestStatus(any()),
        ).thenAnswer((_) async {});

        final success = await managementOperations.cancelFriendRequest('req_1');

        expect(success, isTrue);
        verify(
          () => mockParentService.removeOutgoingRequestInternal('req_1'),
        ).called(1);
        verify(
          () => mockParentService.updateFriendRequestStatus(any()),
        ).called(1);
      });

      test('should return false when request not found', () async {
        mockParentService.setFriendsState(
          outgoingRequests: [],
          isInitialized: true,
        );

        final success = await managementOperations.cancelFriendRequest(
          'nonexistent',
        );

        expect(success, isFalse);
      });
    });

    group('Block User Cascade', () {
      late _MockFirebaseBlockRepository mockBlockRepo;
      late _RecordingSocialTracker socialTracker;

      setUp(() {
        mockBlockRepo = _MockFirebaseBlockRepository();
        TestServiceLocator.registerMock<FirebaseBlockRepository>(mockBlockRepo);
        when(() => mockBlockRepo.blockUser(any())).thenAnswer((_) async {});
        when(() => mockBlockRepo.unblockUser(any())).thenAnswer((_) async {});

        socialTracker = _RecordingSocialTracker();
        final analytics = _MockAnalyticsService();
        when(() => analytics.social).thenReturn(socialTracker);
        TestServiceLocator.registerMock<AnalyticsService>(analytics);
      });

      // The analytics used to sit on FriendsViewModel, so every caller that
      // skipped it — the settings screen, and blockUsers/unblockUsers here —
      // recorded nothing. These two pin the emission at the layer every caller
      // passes through, and pin WHICH event, which a no-op tracker cannot.
      test(
        'a block records exactly one blocked event, and no unblock',
        () async {
          mockParentService.setFriendsState(
            friends: [],
            incomingRequests: [],
            outgoingRequests: [],
            isInitialized: true,
          );

          expect(
            (await managementOperations.blockUser(
              'blocked_person',
            )).blockLanded,
            isTrue,
          );

          // The analytics call is `unawaited` since BUT-2022, so drain the
          // microtask queue rather than relying on `Future.sync` running the
          // closure synchronously — true today, and not a property this
          // assertion should rest on.
          await Future<void>.delayed(Duration.zero);
          expect(socialTracker.blocked, ['blocked_person']);
          expect(socialTracker.unblocked, isEmpty);
        },
      );

      test(
        'an unblock records exactly one unblocked event, and no block',
        () async {
          expect(
            await managementOperations.unblockUser('blocked_person'),
            isTrue,
          );

          // BUT-2069 made this call `unawaited` too, so drain the microtask
          // queue the way the block twin above does rather than resting on
          // `Future.sync` running the closure synchronously.
          await Future<void>.delayed(Duration.zero);
          expect(socialTracker.unblocked, ['blocked_person']);
          expect(socialTracker.blocked, isEmpty);
        },
      );

      test('should clean up incoming requests from blocked user', () async {
        final incomingRequest = FriendRequest(
          id: 'inc_req_1',
          fromUserId: 'blocked_person',
          toUserId: 'current_user',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );

        mockParentService.setFriendsState(
          friends: [],
          incomingRequests: [incomingRequest],
          outgoingRequests: [],
          isInitialized: true,
        );
        when(
          () => mockParentService.removeIncomingRequestInternal('inc_req_1'),
        ).thenReturn(null);
        when(
          () => mockParentService.updateFriendRequestStatus(any()),
        ).thenAnswer((_) async {});

        final outcome = await managementOperations.blockUser('blocked_person');

        expect(outcome, equals(BlockOutcome.blocked));
        verify(
          () => mockParentService.removeIncomingRequestInternal('inc_req_1'),
        ).called(1);
        verify(
          () => mockParentService.updateFriendRequestStatus(any()),
        ).called(1);
        verify(() => mockBlockRepo.blockUser('blocked_person')).called(1);
      });

      test('should clean up outgoing requests to blocked user', () async {
        final outgoingRequest = FriendRequest(
          id: 'out_req_1',
          fromUserId: 'current_user',
          toUserId: 'blocked_person',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );

        mockParentService.setFriendsState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [outgoingRequest],
          isInitialized: true,
        );
        when(
          () => mockParentService.removeOutgoingRequestInternal('out_req_1'),
        ).thenReturn(null);
        when(
          () => mockParentService.updateFriendRequestStatus(any()),
        ).thenAnswer((_) async {});

        final outcome = await managementOperations.blockUser('blocked_person');

        expect(outcome, equals(BlockOutcome.blocked));
        verify(
          () => mockParentService.removeOutgoingRequestInternal('out_req_1'),
        ).called(1);
        verify(() => mockBlockRepo.blockUser('blocked_person')).called(1);
      });

      test('should block user with no prior relationship', () async {
        mockParentService.setFriendsState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
          isInitialized: true,
        );

        final outcome = await managementOperations.blockUser('stranger');

        expect(outcome, equals(BlockOutcome.blocked));
        verify(() => mockBlockRepo.blockUser('stranger')).called(1);
      });

      test('blockUsers counts a partial block as a block', () async {
        // The count means "protections now in force", not "everything went
        // perfectly". Narrowing it to `== BlockOutcome.blocked` undercounts
        // a bulk block — the people ARE blocked.
        // Both must be FRIENDS, or the cleanup never runs and both blocks
        // come back clean — which is how the first version of this test
        // passed under the very mutant it exists to catch.
        UserProfile friend(String uid) => UserProfile(
          uid: uid,
          email: '$uid@example.com',
          displayName: uid,
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        mockParentService.setFriendsState(
          friends: [friend('a'), friend('b')],
          incomingRequests: [],
          outgoingRequests: [],
          isInitialized: true,
        );
        when(
          () => mockParentService.removeFriendInternal(any()),
        ).thenReturn(null);
        when(
          () => mockRelationshipRepo.removeMutualFriends(any(), any()),
        ).thenThrow(Exception('cleanup failed'));

        // Premise: each block lands but its cleanup does not.
        expect(
          await managementOperations.blockUser('a'),
          equals(BlockOutcome.blockedWithCleanupIssues),
        );

        final count = await managementOperations.blockUsers(['a', 'b']);

        expect(count, 2);
      });

      // BUT-2022. Before this, the friendship and both directions of pending
      // requests were destroyed BEFORE the block row was attempted — so a
      // failure in the write returned false and the user was told "kunde inte
      // blockera" while the irreversible part had already happened.
      group('block ordering and partial outcomes (BUT-2022)', () {
        setUp(() {
          mockParentService.setFriendsState(
            friends: [],
            incomingRequests: [],
            outgoingRequests: [],
            isInitialized: true,
          );
        });

        test('the block row is written BEFORE any teardown', () async {
          final friend = UserProfile(
            uid: 'blocked_person',
            email: 'b@example.com',
            displayName: 'Blocked',
            joinedAt: DateTime.now(),
            lastActiveAt: DateTime.now(),
          );
          mockParentService.setFriendsState(
            friends: [friend],
            incomingRequests: [],
            outgoingRequests: [],
            isInitialized: true,
          );
          when(
            () => mockParentService.removeFriendInternal('blocked_person'),
          ).thenReturn(null);
          when(
            () => mockRelationshipRepo.removeMutualFriends(any(), any()),
          ).thenAnswer((_) async {});

          await managementOperations.blockUser('blocked_person');

          // Order, not counts: a call-count assertion passes whichever way
          // round these run, and the order IS the fix.
          verifyInOrder([
            () => mockBlockRepo.blockUser('blocked_person'),
            () => mockRelationshipRepo.removeMutualFriends(any(), any()),
          ]);
        });

        test(
          'a failed block row reports failed and tears nothing down',
          () async {
            final friend = UserProfile(
              uid: 'blocked_person',
              email: 'b@example.com',
              displayName: 'Blocked',
              joinedAt: DateTime.now(),
              lastActiveAt: DateTime.now(),
            );
            mockParentService.setFriendsState(
              friends: [friend],
              incomingRequests: [],
              outgoingRequests: [],
              isInitialized: true,
            );
            when(
              () => mockBlockRepo.blockUser(any()),
            ).thenThrow(Exception('network'));

            final outcome = await managementOperations.blockUser(
              'blocked_person',
            );

            expect(outcome, equals(BlockOutcome.failed));
            expect(outcome.blockLanded, isFalse);
            // The point of the reorder: the friendship survives a failed block.
            verifyNever(
              () => mockRelationshipRepo.removeMutualFriends(any(), any()),
            );
            verifyNever(
              () => mockParentService.updateFriendRequestStatus(any()),
            );
          },
        );

        test(
          'a failed friendship cleanup still reports the block as standing',
          () async {
            final friend = UserProfile(
              uid: 'blocked_person',
              email: 'b@example.com',
              displayName: 'Blocked',
              joinedAt: DateTime.now(),
              lastActiveAt: DateTime.now(),
            );
            mockParentService.setFriendsState(
              friends: [friend],
              incomingRequests: [],
              outgoingRequests: [],
              isInitialized: true,
            );
            // removeFriend swallows this and answers false rather than throwing,
            // which is precisely the return value the old code discarded.
            when(
              () => mockRelationshipRepo.removeMutualFriends(any(), any()),
            ).thenThrow(Exception('permission denied'));

            final outcome = await managementOperations.blockUser(
              'blocked_person',
            );

            expect(outcome, equals(BlockOutcome.blockedWithCleanupIssues));
            expect(
              outcome.blockLanded,
              isTrue,
              reason:
                  'the person IS blocked; reporting failure here is the defect',
            );
            verify(() => mockBlockRepo.blockUser('blocked_person')).called(1);
          },
        );

        test(
          'a failed request cleanup still reports the block as standing',
          () async {
            final incoming = FriendRequest(
              id: 'inc_req_1',
              fromUserId: 'blocked_person',
              toUserId: 'current_user',
              status: FriendRequestStatus.pending,
              sentAt: DateTime.now(),
            );
            mockParentService.setFriendsState(
              friends: [],
              incomingRequests: [incoming],
              outgoingRequests: [],
              isInitialized: true,
            );
            when(
              () => mockParentService.removeIncomingRequestInternal(any()),
            ).thenReturn(null);
            when(
              () => mockParentService.updateFriendRequestStatus(any()),
            ).thenThrow(Exception('offline'));

            final outcome = await managementOperations.blockUser(
              'blocked_person',
            );

            expect(outcome, equals(BlockOutcome.blockedWithCleanupIssues));
            verify(() => mockBlockRepo.blockUser('blocked_person')).called(1);
          },
        );
      });

      // BUT-2069: the mirror of the rule above, on the unblock side. The
      // outcome must answer one question — is the blocks row gone — and
      // nothing that happens after the row is deleted may change the answer.
      group('telemetry never decides the unblock outcome (BUT-2069)', () {
        late _ThrowingSocialTracker throwingTracker;

        setUp(() {
          throwingTracker = _ThrowingSocialTracker();
          final analytics = _MockAnalyticsService();
          when(() => analytics.social).thenReturn(throwingTracker);
          TestServiceLocator.registerMock<AnalyticsService>(analytics);
        });

        test(
          'a throwing analytics call still reports the unblock as done',
          () async {
            final result = await managementOperations.unblockUser(
              'blocked_person',
            );

            expect(
              result,
              isTrue,
              reason:
                  'the blocks row is deleted; telling the user it failed is the '
                  'defect — they see the person still listed as blocked',
            );
            verify(() => mockBlockRepo.unblockUser('blocked_person')).called(1);
            // The call was reached and blew up, so a green result here is the
            // failure being contained rather than the call being skipped.
            await Future<void>.delayed(Duration.zero);
            expect(throwingTracker.attempts, ['blocked_person']);
          },
        );

        test('a failed blocks-row delete still reports failure', () async {
          when(
            () => mockBlockRepo.unblockUser(any()),
          ).thenThrow(Exception('permission denied'));

          expect(
            await managementOperations.unblockUser('blocked_person'),
            isFalse,
            reason:
                'the row still stands, so the person is still blocked — this '
                'is the one case that must answer false',
          );
        });

        test(
          'unblockUsers counts the row deletes, not the telemetry',
          () async {
            expect(
              await managementOperations.unblockUsers(['a', 'b']),
              2,
              reason:
                  'the bulk loop reads unblockUser, so a telemetry outage must '
                  'not undercount unblocks that landed',
            );
          },
        );

        test(
          'a throwing analytics call still reports the BLOCK as standing',
          () async {
            mockParentService.setFriendsState(
              friends: [],
              incomingRequests: [],
              outgoingRequests: [],
              isInitialized: true,
            );

            final outcome = await managementOperations.blockUser(
              'blocked_person',
            );

            expect(outcome.blockLanded, isTrue);
            await Future<void>.delayed(Duration.zero);
            expect(throwingTracker.attempts, ['blocked_person']);
          },
        );
      });
    });

    group('Search', () {
      test('searchFriends filters by display name case-insensitively', () {
        final alice = UserProfile(
          uid: 'alice',
          email: 'alice@example.com',
          displayName: 'Alice Andersson',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        final bob = UserProfile(
          uid: 'bob',
          email: 'bob@example.com',
          displayName: 'Bob Berggren',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );

        mockParentService.setFriendsState(
          friends: [alice, bob],
          isInitialized: true,
        );

        final results = managementOperations.searchFriends('alice');

        expect(results, hasLength(1));
        expect(results.first.uid, equals('alice'));
      });

      test('searchFriends returns empty for no match', () {
        final alice = UserProfile(
          uid: 'alice',
          email: 'alice@example.com',
          displayName: 'Alice',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );

        mockParentService.setFriendsState(
          friends: [alice],
          isInitialized: true,
        );

        final results = managementOperations.searchFriends('zzzz');

        expect(results, isEmpty);
      });
    });
  });
}
