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
import 'package:butlery/core/providers/application_provider.dart' as production;
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

class _MockFirebaseBlockRepository extends Mock
    implements FirebaseBlockRepository {}

class _MockFriendRelationshipRepository extends Mock
    implements FriendRelationshipRepository {}

void main() {
  group('FriendsManagementOperations', () {
    late MockUnifiedFriendsService mockParentService;
    late _MockFriendRelationshipRepository mockRelationshipRepo;
    late FakeFirebaseFirestore fakeFirestore;
    late FriendsManagementOperations managementOperations;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();

      registerFallbackValue(UserProfile(
        uid: 'test',
        email: 'test@example.com',
        displayName: 'Test User',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      ));
      registerFallbackValue(FriendRequest(
        id: 'test',
        fromUserId: 'test',
        toUserId: 'test',
        sentAt: DateTime.now(),
      ));
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Production ServiceLocator bridge: the FriendsManagementOperations
      // constructor calls ServiceLocator.get<UserService>() (line 78 of prod).
      // MockDIContainer delegates to GetIt.instance which TestServiceLocator
      // already populated with mocks.
      production.ServiceLocator.reset();
      production.ServiceLocator.initialize(MockDIContainer());

      // executeServiceOperation requires auth: configure MockAuthRepository
      final authRepo =
          TestServiceLocator.get<AuthRepository>() as MockAuthRepository;
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
        expect(managementOperations.serviceName,
            equals('FriendsManagementOperations'));
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
        when(() => mockParentService.removeFriendInternal('friend_123'))
            .thenReturn(null);
        when(() => mockRelationshipRepo.removeMutualFriends(any(), any()))
            .thenAnswer((_) async {});

        final success = await managementOperations.removeFriend('friend_123');

        expect(success, isTrue);
        verify(() => mockParentService.removeFriendInternal('friend_123'))
            .called(1);
        verify(() => mockRelationshipRepo.removeMutualFriends(
            'current_user', 'friend_123')).called(1);
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
        when(() => mockParentService.removeOutgoingRequestInternal('req_1'))
            .thenReturn(null);
        when(() => mockParentService.updateFriendRequestStatus(any()))
            .thenAnswer((_) async {});

        final success = await managementOperations.cancelFriendRequest('req_1');

        expect(success, isTrue);
        verify(() => mockParentService.removeOutgoingRequestInternal('req_1'))
            .called(1);
        verify(() => mockParentService.updateFriendRequestStatus(any()))
            .called(1);
      });

      test('should return false when request not found', () async {
        mockParentService.setFriendsState(
          outgoingRequests: [],
          isInitialized: true,
        );

        final success =
            await managementOperations.cancelFriendRequest('nonexistent');

        expect(success, isFalse);
      });
    });

    group('Block User Cascade', () {
      late _MockFirebaseBlockRepository mockBlockRepo;

      setUp(() {
        mockBlockRepo = _MockFirebaseBlockRepository();
        TestServiceLocator.registerMock<FirebaseBlockRepository>(mockBlockRepo);
        when(() => mockBlockRepo.blockUser(any())).thenAnswer((_) async {});
      });

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
        when(() => mockParentService.removeIncomingRequestInternal('inc_req_1'))
            .thenReturn(null);
        when(() => mockParentService.updateFriendRequestStatus(any()))
            .thenAnswer((_) async {});

        final success = await managementOperations.blockUser('blocked_person');

        expect(success, isTrue);
        verify(() =>
                mockParentService.removeIncomingRequestInternal('inc_req_1'))
            .called(1);
        verify(() => mockParentService.updateFriendRequestStatus(any()))
            .called(1);
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
        when(() => mockParentService.removeOutgoingRequestInternal('out_req_1'))
            .thenReturn(null);
        when(() => mockParentService.updateFriendRequestStatus(any()))
            .thenAnswer((_) async {});

        final success = await managementOperations.blockUser('blocked_person');

        expect(success, isTrue);
        verify(() =>
                mockParentService.removeOutgoingRequestInternal('out_req_1'))
            .called(1);
        verify(() => mockBlockRepo.blockUser('blocked_person')).called(1);
      });

      test('should block user with no prior relationship', () async {
        mockParentService.setFriendsState(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
          isInitialized: true,
        );

        final success = await managementOperations.blockUser('stranger');

        expect(success, isTrue);
        verify(() => mockBlockRepo.blockUser('stranger')).called(1);
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
