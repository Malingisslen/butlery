// test/unit/services/unified/operations/friends_management_operations_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/unified/operations/friends_management_operations.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_request.dart';
import '../../../../test_support/base_unit_test.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FriendsManagementOperations', () {
    late MockUnifiedFriendsService mockParentService;
    late FriendsManagementOperations managementOperations;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      
      // Register fallback values for mocktail
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
      // Create mocks
      mockParentService = MockUnifiedFriendsService();
      
      // Configure mock state using configuration methods
      mockParentService.setFriendsState(
        friends: [],
        incomingRequests: [],
        outgoingRequests: [],
        isInitialized: true,
      );
      
      // Stub methods that aren't implemented in the mock
      when(() => mockParentService.currentUserId).thenReturn('current_user');
      when(() => mockParentService.currentUserDisplayName).thenReturn('Current User');
      when(() => mockParentService.friendsList).thenReturn([]);
      when(() => mockParentService.friendRequests).thenReturn([]);
      when(() => mockParentService.blockedUsers).thenReturn({});
      when(() => mockParentService.notifyListenersInternal()).thenReturn(null);
      
      // Create operations instance
      managementOperations = FriendsManagementOperations(mockParentService);
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('Core Functionality', () {
      test('should initialize with parent service', () {
        // Assert
        expect(managementOperations, isNotNull);
        expect(managementOperations.serviceName, equals('FriendsManagementOperations'));
      });
      
      test('should check if user is blocked', () {
        // Arrange
        when(() => mockParentService.blockedUsers).thenReturn({'blocked_user_123'});
        
        // Act & Assert
        expect(managementOperations.isBlocked('blocked_user_123'), isTrue);
        expect(managementOperations.isBlocked('not_blocked_user'), isFalse);
      });
      
      test('should get friend statistics', () {
        // Arrange
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
        
        when(() => mockParentService.friendsList).thenReturn([friend1, friend2]);
        when(() => mockParentService.incomingRequests).thenReturn([pendingRequest]);
        when(() => mockParentService.outgoingRequests).thenReturn([]);
        when(() => mockParentService.blockedUsers).thenReturn({'blocked_1', 'blocked_2', 'blocked_3'});
        
        // Act
        final stats = managementOperations.getFriendStats();
        
        // Assert
        expect(stats['totalFriends'], equals(2));
        expect(stats['pendingRequests'], equals(1));
        expect(stats['outgoingRequests'], equals(0));
        expect(stats['blockedUsers'], equals(3));
      });
    });
    
    group('Friend Removal', () {
      test('should remove friend successfully', () async {
        // Arrange
        final friend = UserProfile(
          uid: 'friend_123',
          email: 'friend@example.com',
          displayName: 'Test Friend',
          joinedAt: DateTime.now(),
          lastActiveAt: DateTime.now(),
        );
        
        when(() => mockParentService.friendsList).thenReturn([friend]);
        when(() => mockParentService.removeFriendInternal('friend_123'))
            .thenReturn(null);
        when(() => mockParentService.removeFriendFromFirebase('friend_123'))
            .thenAnswer((_) async => {});
        
        // Act
        final success = await managementOperations.removeFriend('friend_123');
        
        // Assert
        expect(success, isTrue);
        verify(() => mockParentService.removeFriendInternal('friend_123')).called(1);
        verify(() => mockParentService.removeFriendFromFirebase('friend_123')).called(1);
      });
      
      test('should not remove non-existent friend', () async {
        // Arrange
        when(() => mockParentService.friendsList).thenReturn([]);
        
        // Act
        final success = await managementOperations.removeFriend('not_a_friend');
        
        // Assert
        expect(success, isFalse);
        verifyNever(() => mockParentService.removeFriendInternal(any()));
        verifyNever(() => mockParentService.removeFriendFromFirebase(any()));
      });
    });
    
    group('User Blocking', () {
      test('should block user successfully', () async {
        // Arrange
        when(() => mockParentService.friendsList).thenReturn([]);
        when(() => mockParentService.outgoingRequests).thenReturn([]);
        when(() => mockParentService.addBlockedUserInternal('user_to_block'))
            .thenReturn(null);
        when(() => mockParentService.syncBlockedUsers())
            .thenAnswer((_) async => {});
        
        // Act
        final success = await managementOperations.blockUser('user_to_block');
        
        // Assert
        expect(success, isTrue);
        verify(() => mockParentService.addBlockedUserInternal('user_to_block')).called(1);
        verify(() => mockParentService.syncBlockedUsers()).called(1);
      });
      
      test('should unblock user successfully', () async {
        // Arrange
        when(() => mockParentService.blockedUsers).thenReturn({'blocked_user'});
        when(() => mockParentService.removeBlockedUserInternal('blocked_user'))
            .thenReturn(null);
        when(() => mockParentService.syncBlockedUsers())
            .thenAnswer((_) async => {});
        
        // Act
        final success = await managementOperations.unblockUser('blocked_user');
        
        // Assert
        expect(success, isTrue);
        verify(() => mockParentService.removeBlockedUserInternal('blocked_user')).called(1);
        verify(() => mockParentService.syncBlockedUsers()).called(1);
      });
    });
    
    // TODO: Add more comprehensive tests for:
    // - Friend request sending (needs proper service mocking)
    // - Friend request acceptance/rejection (needs proper service mocking)
    // - User discovery features
    // - Error handling scenarios
  });
}

// Mock classes for testing
// Using MockUnifiedFriendsService from production_mocks.dart