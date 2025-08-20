import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/friends_operations.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart' as app_provider;

import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/builders/user_builder.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

// Mock classes
class MockUnifiedFriendsService extends Mock implements UnifiedFriendsService {
  String? _currentUserId = 'test-user-123';
  List<UserProfile> _friendsList = [];
  List<FriendRequest> _friendRequests = [];
  Set<String> _blockedUsers = {};
  
  void setServiceState({
    String? userId,
    List<UserProfile>? friends,
    List<FriendRequest>? requests,
    Set<String>? blockedUsers,
  }) {
    if (userId != null) _currentUserId = userId;
    if (friends != null) _friendsList = friends;
    if (requests != null) _friendRequests = requests;
    if (blockedUsers != null) _blockedUsers = blockedUsers;
  }
  
  @override
  String? get currentUserId => _currentUserId;
  
  @override
  List<UserProfile> get friendsList => _friendsList;
  
  @override
  List<FriendRequest> get friendRequests => _friendRequests;
  
  @override
  List<FriendRequest> get incomingRequests => _friendRequests
      .where((r) => r.toUserId == _currentUserId && r.status == FriendRequestStatus.pending)
      .toList();
  
  @override
  List<FriendRequest> get outgoingRequests => _friendRequests
      .where((r) => r.fromUserId == _currentUserId && r.status == FriendRequestStatus.pending)
      .toList();
  
  @override
  Set<String> get blockedUsers => _blockedUsers;
  
  @override
  void notifyListenersInternal() {
    // Mock implementation
  }
}

class MockFriendsManagementOperations extends Mock implements FriendsManagementOperations {}

void main() {
  group('FriendsOperations', () {
    late FriendsOperations operations;
    late MockUnifiedFriendsService mockParent;
    late MockFriendsManagementOperations mockManagement;
    late MockPermissionService mockPermissionService;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Create mocks
      mockParent = MockUnifiedFriendsService();
      mockManagement = MockFriendsManagementOperations();
      
      // Get the mock permission service from TestServiceLocator
      mockPermissionService = TestServiceLocator.get<PermissionService>() as MockPermissionService;
      mockPermissionService.setPermissionState(
        defaultHasPermission: true,
        currentUserId: 'test-user-123',
      );
      
      // Initialize production ServiceLocator with MockDIContainer
      // which will delegate to TestServiceLocator  
      app_provider.ServiceLocator.reset();
      app_provider.ServiceLocator.initialize(MockDIContainer());
      
      // Setup parent service with management operations
      when(() => mockParent.management).thenReturn(mockManagement);
      
      // Stub async methods
      when(() => mockParent.searchUsers(any())).thenAnswer((_) async => []);
      when(() => mockParent.getFriendsOfUser(any())).thenAnswer((_) async => []);
      when(() => mockParent.getRecentCollaborators()).thenAnswer((_) async => []);
      when(() => mockParent.getRecentShoppingCollaborators()).thenAnswer((_) async => []);
      when(() => mockParent.syncBlockedUsers()).thenAnswer((_) async {});
      
      when(() => mockManagement.sendFriendRequest(any())).thenAnswer((_) async => true);
      when(() => mockManagement.acceptFriendRequest(any())).thenAnswer((_) async => true);
      when(() => mockManagement.rejectFriendRequest(any())).thenAnswer((_) async => true);
      when(() => mockManagement.cancelFriendRequest(any())).thenAnswer((_) async => true);
      when(() => mockManagement.removeFriend(any())).thenAnswer((_) async => true);
      when(() => mockManagement.blockUser(any())).thenAnswer((_) async => true);
      
      // Create operations
      operations = FriendsOperations(mockParent);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Friend Requests', () {
      test('should send friend request successfully', () async {
        // Arrange
        mockParent.setServiceState(userId: 'sender-123');
        
        // Act
        final result = await operations.sendRequest('recipient-123');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockManagement.sendFriendRequest('recipient-123')).called(1);
      });
      
      test('should not send request to self', () async {
        // Arrange
        mockParent.setServiceState(userId: 'user-123');
        
        // Act
        final result = await operations.sendRequest('user-123');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockManagement.sendFriendRequest(any()));
      });
      
      test('should not send request when not authenticated', () async {
        // Arrange
        mockPermissionService.setPermissionState(
          defaultHasPermission: false,
          currentUserId: null,
        );
        
        // Act
        final result = await operations.sendRequest('recipient-123');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockManagement.sendFriendRequest(any()));
      });
      
      test('should not send request to existing friend', () async {
        // Arrange
        final friend = UserBuilder().withId('friend-123').build();
        mockParent.setServiceState(
          userId: 'user-123',
          friends: [friend],
        );
        
        // Act
        final result = await operations.sendRequest('friend-123');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockManagement.sendFriendRequest(any()));
      });
      
      test('should accept incoming friend request', () async {
        // Arrange
        final request = FriendRequest(
          id: 'request-123',
          fromUserId: 'sender-123',
          toUserId: 'test-user-123',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );
        mockParent.setServiceState(
          userId: 'test-user-123',
          requests: [request],
        );
        
        // Act
        final result = await operations.acceptRequest('request-123');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockManagement.acceptFriendRequest('request-123')).called(1);
      });
      
      test('should not accept request not addressed to current user', () async {
        // Arrange
        final request = FriendRequest(
          id: 'request-123',
          fromUserId: 'sender-123',
          toUserId: 'other-user-123',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );
        mockParent.setServiceState(
          userId: 'test-user-123',
          requests: [request],
        );
        
        // Act
        final result = await operations.acceptRequest('request-123');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockManagement.acceptFriendRequest(any()));
      });
      
      test('should decline incoming friend request', () async {
        // Arrange
        final request = FriendRequest(
          id: 'request-123',
          fromUserId: 'sender-123',
          toUserId: 'test-user-123',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );
        mockParent.setServiceState(
          userId: 'test-user-123',
          requests: [request],
        );
        
        // Act
        final result = await operations.declineRequest('request-123');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockManagement.rejectFriendRequest('request-123')).called(1);
      });
      
      test('should cancel outgoing friend request', () async {
        // Arrange
        final request = FriendRequest(
          id: 'request-123',
          fromUserId: 'test-user-123',
          toUserId: 'recipient-123',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );
        mockParent.setServiceState(
          userId: 'test-user-123',
          requests: [request],
        );
        
        // Act
        final result = await operations.cancelRequest('request-123');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockManagement.cancelFriendRequest('request-123')).called(1);
      });
    });
    
    group('Friend Management', () {
      test('should remove friend successfully', () async {
        // Arrange
        final friend = UserBuilder().withId('friend-123').build();
        mockParent.setServiceState(friends: [friend]);
        
        // Act
        final result = await operations.removeFriend('friend-123');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockManagement.removeFriend('friend-123')).called(1);
      });
      
      test('should not remove non-friend', () async {
        // Arrange
        mockParent.setServiceState(friends: []);
        
        // Act
        final result = await operations.removeFriend('not-friend-123');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockManagement.removeFriend(any()));
      });
      
      test('should block user successfully', () async {
        // Arrange
        mockParent.setServiceState(blockedUsers: {});
        
        // Act
        final result = await operations.blockUser('user-to-block');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockManagement.blockUser('user-to-block')).called(1);
      });
      
      test('should remove friend before blocking', () async {
        // Arrange
        final friend = UserBuilder().withId('friend-to-block').build();
        mockParent.setServiceState(friends: [friend]);
        
        // Act
        final result = await operations.blockUser('friend-to-block');
        
        // Assert
        expect(result, isTrue);
        verify(() => mockManagement.removeFriend('friend-to-block')).called(1);
        verify(() => mockManagement.blockUser('friend-to-block')).called(1);
      });
      
      test('should unblock user successfully', () async {
        // Arrange
        mockParent.setServiceState(blockedUsers: {'blocked-user'});
        
        // Act
        final result = await operations.unblockUser('blocked-user');
        
        // Assert
        expect(result, isTrue);
        // The user should be removed from blockedUsers
        expect(mockParent.blockedUsers.contains('blocked-user'), isFalse);
      });
      
      test('should not unblock non-blocked user', () async {
        // Arrange
        mockParent.setServiceState(blockedUsers: {});
        
        // Act
        final result = await operations.unblockUser('not-blocked');
        
        // Assert
        expect(result, isFalse);
        verifyNever(() => mockParent.syncBlockedUsers());
      });
    });
    
    group('User Discovery', () {
      test('should search users successfully', () async {
        // Arrange
        final users = [
          UserBuilder().withId('user-1').withName('Anna').build(),
          UserBuilder().withId('user-2').withName('Anna B').build(),
        ];
        when(() => mockParent.searchUsers('Anna')).thenAnswer((_) async => users);
        mockParent.setServiceState(userId: 'current-user');
        
        // Act
        final results = await operations.searchUsers('Anna');
        
        // Assert
        expect(results, hasLength(2));
        expect(results[0].displayName, equals('Anna'));
        verify(() => mockParent.searchUsers('Anna')).called(1);
      });
      
      test('should filter out current user from search', () async {
        // Arrange
        final users = [
          UserBuilder().withId('current-user').withName('Me').build(),
          UserBuilder().withId('other-user').withName('Other').build(),
        ];
        when(() => mockParent.searchUsers('search')).thenAnswer((_) async => users);
        mockParent.setServiceState(userId: 'current-user');
        
        // Act
        final results = await operations.searchUsers('search');
        
        // Assert
        expect(results, hasLength(1));
        expect(results[0].uid, equals('other-user'));
      });
      
      test('should filter out existing friends from search', () async {
        // Arrange
        final friend = UserBuilder().withId('friend-123').withName('Friend').build();
        final searchResults = [
          friend,
          UserBuilder().withId('not-friend').withName('Stranger').build(),
        ];
        when(() => mockParent.searchUsers('search')).thenAnswer((_) async => searchResults);
        mockParent.setServiceState(friends: [friend]);
        
        // Act
        final results = await operations.searchUsers('search');
        
        // Assert
        expect(results, hasLength(1));
        expect(results[0].uid, equals('not-friend'));
      });
      
      test('should return empty list for short query', () async {
        // Arrange & Act
        final results = await operations.searchUsers('a');
        
        // Assert
        expect(results, isEmpty);
        verifyNever(() => mockParent.searchUsers(any()));
      });
      
      test('should search user by email', () async {
        // Arrange
        final user = UserBuilder()
            .withId('user-123')
            .withEmail('anna@example.com')
            .build();
        when(() => mockParent.searchUsers('anna@example.com'))
            .thenAnswer((_) async => [user]);
        
        // Act
        final result = await operations.searchUserByEmail('anna@example.com');
        
        // Assert
        expect(result, isNotNull);
        expect(result!.email, equals('anna@example.com'));
      });
      
      test('should return null for invalid email format', () async {
        // Arrange & Act
        final result = await operations.searchUserByEmail('not-an-email');
        
        // Assert
        expect(result, isNull);
        verifyNever(() => mockParent.searchUsers(any()));
      });
      
      test('should get suggested friends', () async {
        // Arrange
        final mutualFriend = UserBuilder().withId('mutual-1').build();
        final collaborator = UserBuilder().withId('collab-1').build();
        
        when(() => mockParent.getFriendsOfUser(any()))
            .thenAnswer((_) async => [mutualFriend]);
        when(() => mockParent.getRecentCollaborators())
            .thenAnswer((_) async => [collaborator]);
        
        mockParent.setServiceState(
          userId: 'current-user',
          friends: [UserBuilder().withId('friend-1').build()],
        );
        
        // Act
        final suggestions = await operations.getSuggestedFriends();
        
        // Assert
        expect(suggestions, hasLength(2));
        expect(suggestions.map((u) => u.uid), containsAll(['mutual-1', 'collab-1']));
      });
    });
    
    group('Status Checks', () {
      test('should check if user is friend', () {
        // Arrange
        final friend = UserBuilder().withId('friend-123').build();
        mockParent.setServiceState(friends: [friend]);
        
        // Act & Assert
        expect(operations.isFriend('friend-123'), isTrue);
        expect(operations.isFriend('not-friend'), isFalse);
      });
      
      test('should check pending request to user', () {
        // Arrange
        final request = FriendRequest(
          id: 'req-1',
          fromUserId: 'test-user-123',
          toUserId: 'recipient-123',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );
        mockParent.setServiceState(
          userId: 'test-user-123',
          requests: [request],
        );
        
        // Act & Assert
        expect(operations.hasPendingRequestTo('recipient-123'), isTrue);
        expect(operations.hasPendingRequestTo('other-user'), isFalse);
      });
      
      test('should check pending request from user', () {
        // Arrange
        final request = FriendRequest(
          id: 'req-1',
          fromUserId: 'sender-123',
          toUserId: 'test-user-123',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );
        mockParent.setServiceState(
          userId: 'test-user-123',
          requests: [request],
        );
        
        // Act & Assert
        expect(operations.hasPendingRequestFrom('sender-123'), isTrue);
        expect(operations.hasPendingRequestFrom('other-user'), isFalse);
      });
      
      test('should get correct relationship status', () {
        // Arrange
        final friend = UserBuilder().withId('friend-123').build();
        final requestSent = FriendRequest(
          id: 'req-1',
          fromUserId: 'test-user-123',
          toUserId: 'pending-user',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );
        final requestReceived = FriendRequest(
          id: 'req-2',
          fromUserId: 'sender-user',
          toUserId: 'test-user-123',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );
        
        mockParent.setServiceState(
          userId: 'test-user-123',
          friends: [friend],
          requests: [requestSent, requestReceived],
        );
        
        // Act & Assert
        expect(operations.getRelationshipStatus('test-user-123'), equals(FriendshipStatus.self));
        expect(operations.getRelationshipStatus('friend-123'), equals(FriendshipStatus.friends));
        expect(operations.getRelationshipStatus('pending-user'), equals(FriendshipStatus.requestSent));
        expect(operations.getRelationshipStatus('sender-user'), equals(FriendshipStatus.requestReceived));
        expect(operations.getRelationshipStatus('stranger'), equals(FriendshipStatus.none));
      });
    });
    
    group('Data Access', () {
      test('should get friend by ID', () {
        // Arrange
        final friend = UserBuilder().withId('friend-123').withName('Anna').build();
        mockParent.setServiceState(friends: [friend]);
        
        // Act
        final result = operations.getFriendById('friend-123');
        
        // Assert
        expect(result, isNotNull);
        expect(result!.displayName, equals('Anna'));
      });
      
      test('should return null for non-friend ID', () {
        // Arrange
        mockParent.setServiceState(friends: []);
        
        // Act
        final result = operations.getFriendById('not-friend');
        
        // Assert
        expect(result, isNull);
      });
      
      test('should get all friends', () {
        // Arrange
        final friends = [
          UserBuilder().withId('friend-1').build(),
          UserBuilder().withId('friend-2').build(),
        ];
        mockParent.setServiceState(friends: friends);
        
        // Act
        final result = operations.getAllFriends();
        
        // Assert
        expect(result, hasLength(2));
        expect(result, equals(friends));
      });
      
      test('should get incoming requests', () {
        // Arrange
        final incoming = FriendRequest(
          id: 'req-1',
          fromUserId: 'sender-123',
          toUserId: 'test-user-123',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );
        final outgoing = FriendRequest(
          id: 'req-2',
          fromUserId: 'test-user-123',
          toUserId: 'recipient-123',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );
        mockParent.setServiceState(
          userId: 'test-user-123',
          requests: [incoming, outgoing],
        );
        
        // Act
        final result = operations.getIncomingRequests();
        
        // Assert
        expect(result, hasLength(1));
        expect(result[0].id, equals('req-1'));
      });
      
      test('should get outgoing requests', () {
        // Arrange
        final outgoing = FriendRequest(
          id: 'req-1',
          fromUserId: 'test-user-123',
          toUserId: 'recipient-123',
          status: FriendRequestStatus.pending,
          sentAt: DateTime.now(),
        );
        mockParent.setServiceState(
          userId: 'test-user-123',
          requests: [outgoing],
        );
        
        // Act
        final result = operations.getOutgoingRequests();
        
        // Assert
        expect(result, hasLength(1));
        expect(result[0].id, equals('req-1'));
      });
      
      test('should get friends count', () {
        // Arrange
        final friends = [
          UserBuilder().withId('friend-1').build(),
          UserBuilder().withId('friend-2').build(),
          UserBuilder().withId('friend-3').build(),
        ];
        mockParent.setServiceState(friends: friends);
        
        // Act
        final count = operations.getFriendsCount();
        
        // Assert
        expect(count, equals(3));
      });
      
      test('should get pending requests count', () {
        // Arrange
        final requests = [
          FriendRequest(
            id: 'req-1',
            fromUserId: 'sender-1',
            toUserId: 'test-user-123',
            status: FriendRequestStatus.pending,
            sentAt: DateTime.now(),
          ),
          FriendRequest(
            id: 'req-2',
            fromUserId: 'sender-2',
            toUserId: 'test-user-123',
            status: FriendRequestStatus.pending,
            sentAt: DateTime.now(),
          ),
        ];
        mockParent.setServiceState(
          userId: 'test-user-123',
          requests: requests,
        );
        
        // Act
        final count = operations.getPendingRequestsCount();
        
        // Assert
        expect(count, equals(2));
      });
    });
  });
}