/// Unit tests for FirebaseFriendsRepository
/// 
/// Tests the friends repository facade that coordinates social relationship
/// management through four specialized sub-repositories.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/models/friend_request.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import '../../infrastructure/helpers/_base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseFriendsRepository', () {
    late FirebaseFriendsRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepository;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Setup fake Firestore and mock auth
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepository = MockAuthRepository();
      
      // Configure auth state
      mockAuthRepository.setAuthState(userId: 'test_user_123');
      
      // Create repository with dependency injection
      repository = FirebaseFriendsRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('Friend Requests', () {
      test('should send friend request to another user', () async {
        // Arrange
        const fromUserId = 'test_user_123';
        const toUserId = 'target_user_456';
        const message = 'Let\'s be friends!';
        
        // Act
        final success = await repository.sendFriendRequest(
          toUserId,
          message: message,
        );
        
        // Assert
        expect(success, isTrue);
        
        // Verify in Firestore
        final requests = await fakeFirestore
            .collection('friend_requests')
            .where('fromUserId', isEqualTo: fromUserId)
            .where('toUserId', isEqualTo: toUserId)
            .get();
        
        expect(requests.docs.length, equals(1));
        final requestData = requests.docs.first.data();
        expect(requestData['message'], equals(message));
        expect(requestData['status'], equals('pending'));
      });
      
      test('should not send duplicate friend request', () async {
        // Arrange
        const fromUserId = 'test_user_123';
        const toUserId = 'target_user_456';
        
        // Create existing request
        await fakeFirestore.collection('friend_requests').add({
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'status': 'pending',
          'sentAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        final success = await repository.sendFriendRequest(toUserId);
        
        // Assert
        expect(success, isFalse);
      });
      
      test('should accept friend request', () async {
        // Arrange
        const fromUserId = 'sender_user';
        const toUserId = 'test_user_123';
        
        // Create user profile documents (required for friendsCount updates)
        await fakeFirestore.collection('public_profiles').doc(fromUserId).set({
          'friendsCount': 0,
          'email': 'sender@test.com',
        });
        await fakeFirestore.collection('public_profiles').doc(toUserId).set({
          'friendsCount': 0,
          'email': 'test@test.com',
        });
        
        // Create pending request
        final docRef = await fakeFirestore.collection('friend_requests').add({
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'status': 'pending',
          'sentAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        final success = await repository.acceptFriendRequest(docRef.id);
        
        // Assert
        expect(success, isTrue);
        
        // Verify request is accepted
        final doc = await docRef.get();
        expect(doc.data()?['status'], equals('accepted'));
        
        // Verify mutual friendship created
        final user1Friends = await fakeFirestore
            .collection('users')
            .doc(fromUserId)
            .collection('friends')
            .doc(toUserId)
            .get();
        expect(user1Friends.exists, isTrue);
        
        final user2Friends = await fakeFirestore
            .collection('users')
            .doc(toUserId)
            .collection('friends')
            .doc(fromUserId)
            .get();
        expect(user2Friends.exists, isTrue);
      });
      
      test('should reject friend request', () async {
        // Arrange
        const fromUserId = 'sender_user';
        const toUserId = 'test_user_123';
        
        // Create pending request
        final docRef = await fakeFirestore.collection('friend_requests').add({
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'status': 'pending',
          'sentAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        final success = await repository.rejectFriendRequest(docRef.id);
        
        // Assert
        expect(success, isTrue);
        
        // Verify request is rejected
        final doc = await docRef.get();
        expect(doc.data()?['status'], equals('rejected'));
      });
      
      test('should cancel sent friend request', () async {
        // Arrange
        const fromUserId = 'test_user_123';
        const toUserId = 'target_user';
        
        // Create pending request from current user
        final docRef = await fakeFirestore.collection('friend_requests').add({
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'status': 'pending',
          'sentAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        final success = await repository.cancelFriendRequest(docRef.id);
        
        // Assert
        expect(success, isTrue);
        
        // Verify request is cancelled
        final doc = await docRef.get();
        expect(doc.data()?['status'], equals('cancelled'));
      });
      
      test('should get incoming friend requests', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Create multiple incoming requests
        for (int i = 0; i < 3; i++) {
          await fakeFirestore.collection('friend_requests').add({
            'fromUserId': 'sender_$i',
            'toUserId': userId,
            'status': 'pending',
            'message': 'Request $i',
            'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(Duration(hours: i)),
            ),
          });
        }
        
        // Create some non-pending requests (should not be included)
        await fakeFirestore.collection('friend_requests').add({
          'fromUserId': 'sender_old',
          'toUserId': userId,
          'status': 'accepted',
          'sentAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        final requests = await repository.getIncomingRequests();
        
        // Assert
        expect(requests.length, equals(3));
        expect(requests.every((r) => r.status == FriendRequestStatus.pending), isTrue);
        expect(requests.every((r) => r.toUserId == userId), isTrue);
      });
      
      test('should get sent friend requests', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Create multiple sent requests
        for (int i = 0; i < 2; i++) {
          await fakeFirestore.collection('friend_requests').add({
            'fromUserId': userId,
            'toUserId': 'target_$i',
            'status': 'pending',
            'message': 'Request $i',
            'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(Duration(hours: i)),
            ),
          });
        }
        
        // Act
        final requests = await repository.getSentRequests();
        
        // Assert
        expect(requests.length, equals(2));
        expect(requests.every((r) => r.fromUserId == userId), isTrue);
      });
      
      test('should check if request exists between users', () async {
        // Arrange
        const fromUserId = 'user_a';
        const toUserId = 'user_b';
        
        // Create a pending request
        await fakeFirestore.collection('friend_requests').add({
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'status': 'pending',
          'sentAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        final exists = await repository.requestExists(fromUserId, toUserId);
        final reverseExists = await repository.requestExists(toUserId, fromUserId);
        
        // Assert
        expect(exists, isTrue);
        expect(reverseExists, isFalse);
      });
    });
    
    group('Friend Relationships', () {
      test('should add mutual friends', () async {
        // Arrange
        const userId1 = 'test_user_123';
        const userId2 = 'friend_user_456';
        
        // Create user profile documents (required for friendsCount updates)
        await fakeFirestore.collection('public_profiles').doc(userId1).set({
          'friendsCount': 0,
          'email': 'user1@test.com',
        });
        await fakeFirestore.collection('public_profiles').doc(userId2).set({
          'friendsCount': 0,
          'email': 'user2@test.com',
        });
        
        // Act
        await repository.addMutualFriends(userId1, userId2);
        
        // Assert
        // Check user1 has user2 as friend
        final user1Friend = await fakeFirestore
            .collection('users')
            .doc(userId1)
            .collection('friends')
            .doc(userId2)
            .get();
        expect(user1Friend.exists, isTrue);
        
        // Check user2 has user1 as friend
        final user2Friend = await fakeFirestore
            .collection('users')
            .doc(userId2)
            .collection('friends')
            .doc(userId1)
            .get();
        expect(user2Friend.exists, isTrue);
      });
      
      test('should remove mutual friends', () async {
        // Arrange
        const userId1 = 'test_user_123';
        const userId2 = 'friend_user_456';
        
        // Create user profile documents
        await fakeFirestore.collection('public_profiles').doc(userId1).set({
          'friendsCount': 0,
          'email': 'user1@test.com',
        });
        await fakeFirestore.collection('public_profiles').doc(userId2).set({
          'friendsCount': 0,
          'email': 'user2@test.com',
        });
        
        // First add them as friends
        await repository.addMutualFriends(userId1, userId2);
        
        // Act
        await repository.removeMutualFriends(userId1, userId2);
        
        // Assert
        final user1Friend = await fakeFirestore
            .collection('users')
            .doc(userId1)
            .collection('friends')
            .doc(userId2)
            .get();
        expect(user1Friend.exists, isFalse);
        
        final user2Friend = await fakeFirestore
            .collection('users')
            .doc(userId2)
            .collection('friends')
            .doc(userId1)
            .get();
        expect(user2Friend.exists, isFalse);
      });
      
      test('should check if two users are friends', () async {
        // Arrange
        const userId1 = 'test_user_123';
        const userId2 = 'friend_user_456';
        
        // Create user profile documents
        await fakeFirestore.collection('public_profiles').doc(userId1).set({
          'friendsCount': 0,
          'email': 'user1@test.com',
        });
        await fakeFirestore.collection('public_profiles').doc(userId2).set({
          'friendsCount': 0,
          'email': 'user2@test.com',
        });
        
        // Add them as friends
        await repository.addMutualFriends(userId1, userId2);
        
        // Act
        final areFriends = await repository.areFriends(userId1, userId2);
        final reverseCheck = await repository.areFriends(userId2, userId1);
        
        // Assert
        expect(areFriends, isTrue);
        expect(reverseCheck, isTrue);
      });
      
      test('should fetch friend IDs for user', () async {
        // Arrange
        const userId = 'test_user_123';
        final friendIds = ['friend_1', 'friend_2', 'friend_3'];
        
        // Add friends
        for (final friendId in friendIds) {
          await fakeFirestore
              .collection('users')
              .doc(userId)
              .collection('friends')
              .doc(friendId)
              .set({
            'addedAt': FieldValue.serverTimestamp(),
          });
        }
        
        // Act
        final fetchedIds = await repository.fetchFriendIds(userId);
        
        // Assert
        expect(fetchedIds.length, equals(3));
        expect(fetchedIds, containsAll(friendIds));
      });
      
      test('should remove friend', () async {
        // Arrange
        const userId = 'test_user_123';
        const friendId = 'friend_to_remove';
        
        // Create user profile documents
        await fakeFirestore.collection('public_profiles').doc(userId).set({
          'friendsCount': 0,
          'email': 'user@test.com',
        });
        await fakeFirestore.collection('public_profiles').doc(friendId).set({
          'friendsCount': 0,
          'email': 'friend@test.com',
        });
        
        // Add as friends first
        await repository.addMutualFriends(userId, friendId);
        
        // Act
        final success = await repository.removeFriend(friendId);
        
        // Assert
        expect(success, isTrue);
        
        // Verify both sides removed
        final areFriends = await repository.areFriends(userId, friendId);
        expect(areFriends, isFalse);
      });
    });
    
    group('Friend Categories', () {
      test('should save new category for user', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Create user profile document
        await fakeFirestore.collection('public_profiles').doc(userId).set({
          'email': 'user@test.com',
        });
        
        final category = FriendCategory(
          id: 'family_category',
          ownerId: userId,
          name: 'Family',
          friendUserIds: ['friend_1', 'friend_2'],
          isDefault: false,
          createdAt: DateTime.now(),
        );
        
        // Act
        await repository.saveCategory(userId, category);
        
        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('friendCategories')
            .doc(category.id)
            .get();
        
        expect(doc.exists, isTrue);
        expect(doc.data()?['name'], equals('Family'));
        expect(doc.data()?['friendUserIds'], equals(['friend_1', 'friend_2']));
      });
      
      test('should update existing category', () async {
        // Arrange
        const userId = 'test_user_123';
        const categoryId = 'test_category';
        
        // Create user profile document
        await fakeFirestore.collection('public_profiles').doc(userId).set({
          'email': 'user@test.com',
        });
        
        // Create initial category
        await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('friendCategories')
            .doc(categoryId)
            .set({
          'ownerId': userId,
          'name': 'Old Name',
          'friendUserIds': ['friend_1'],
          'isDefault': false,
        });
        
        // Act
        await repository.updateCategory(userId, categoryId, {
          'name': 'New Name',
          'friendUserIds': ['friend_1', 'friend_2', 'friend_3'],
        });
        
        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('friendCategories')
            .doc(categoryId)
            .get();
        
        expect(doc.data()?['name'], equals('New Name'));
        expect(doc.data()?['friendUserIds'], equals(['friend_1', 'friend_2', 'friend_3']));
      });
      
      test('should delete category', () async {
        // Arrange
        const userId = 'test_user_123';
        const categoryId = 'category_to_delete';
        
        // Create user profile document
        await fakeFirestore.collection('public_profiles').doc(userId).set({
          'email': 'user@test.com',
        });
        
        // Create category
        await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('friendCategories')
            .doc(categoryId)
            .set({
          'ownerId': userId,
          'name': 'To Delete',
          'friendUserIds': [],
        });
        
        // Act
        await repository.deleteCategory(userId, categoryId);
        
        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('friendCategories')
            .doc(categoryId)
            .get();
        
        expect(doc.exists, isFalse);
      });
      
      test('should fetch all categories for user', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Create user profile document
        await fakeFirestore.collection('public_profiles').doc(userId).set({
          'email': 'user@test.com',
        });
        
        // Create multiple categories
        for (int i = 0; i < 3; i++) {
          await fakeFirestore
              .collection('users')
              .doc(userId)
              .collection('friendCategories')
              .add({
            'ownerId': userId,
            'name': 'Category $i',
            'friendUserIds': [],
            'isDefault': i == 0,
            'createdAt': Timestamp.fromDate(
              DateTime.now().subtract(Duration(hours: i)),
            ),
          });
        }
        
        // Act
        final categories = await repository.fetchCategories(userId);
        
        // Assert
        expect(categories.length, equals(3));
        expect(categories.where((c) => c.isDefault).length, equals(1));
      });
      
      test('should update category members only', () async {
        // Arrange
        const userId = 'test_user_123';
        const categoryId = 'test_category';
        
        // Create user profile document first
        await fakeFirestore.collection('public_profiles').doc(userId).set({
          'email': 'user@test.com',
        });
        
        // Create category
        await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('friendCategories')
            .doc(categoryId)
            .set({
          'ownerId': userId,
          'name': 'Keep Name',
          'friendUserIds': ['old_friend'],
          'isDefault': true,
        });
        
        // Act
        await repository.updateCategoryMembers(
          userId,
          categoryId,
          ['new_friend_1', 'new_friend_2'],
        );
        
        // Assert
        final doc = await fakeFirestore
            .collection('users')
            .doc(userId)
            .collection('friendCategories')
            .doc(categoryId)
            .get();
        
        expect(doc.data()?['name'], equals('Keep Name')); // Name unchanged
        expect(doc.data()?['isDefault'], isTrue); // Default unchanged
        expect(doc.data()?['friendUserIds'], equals(['new_friend_1', 'new_friend_2']));
      });
    });
    
    group('Group Invitations', () {
      test('should save new group invitation', () async {
        // Arrange
        final invitation = GroupInvitation(
          id: 'invite_123',
          groupId: 'group_456',
          groupName: 'Recipe Lovers',
          groupEmoji: '🍳',
          fromUserId: 'test_user_123',  // Must be current user for permission check
          fromUserName: 'Test User',
          toUserId: 'target_user_456',
          status: GroupInvitationStatus.pending,
          sentAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        );
        
        // Act
        await repository.saveInvitation(invitation);
        
        // Assert
        final doc = await fakeFirestore
            .collection('group_invitations')
            .doc(invitation.id)
            .get();
        
        expect(doc.exists, isTrue);
        expect(doc.data()?['groupId'], equals('group_456'));
        expect(doc.data()?['toUserId'], equals('target_user_456'));
        expect(doc.data()?['status'], equals('pending'));
      });
      
      test('should update invitation status', () async {
        // Arrange
        const invitationId = 'invite_123';
        
        // Create invitation with all required fields
        await fakeFirestore.collection('group_invitations').doc(invitationId).set({
          'groupId': 'group_456',
          'groupName': 'Test Group',
          'groupEmoji': '🍳',
          'fromUserId': 'sender_123',
          'fromUserName': 'Sender Name',
          'toUserId': 'test_user_123',
          'status': 'pending',
          'sentAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
        });
        
        // Act
        await repository.updateInvitation(invitationId, {
          'status': 'accepted',
          'respondedAt': FieldValue.serverTimestamp(),
        });
        
        // Assert
        final doc = await fakeFirestore
            .collection('group_invitations')
            .doc(invitationId)
            .get();
        
        expect(doc.data()?['status'], equals('accepted'));
        expect(doc.data()?['respondedAt'], isNotNull);
      });
      
      test('should check for pending invitation', () async {
        // Arrange
        const groupId = 'group_123';
        const toUserId = 'user_456';
        
        // Create pending invitation
        await fakeFirestore.collection('group_invitations').add({
          'groupId': groupId,
          'toUserId': toUserId,
          'status': 'pending',
          'sentAt': FieldValue.serverTimestamp(),
        });
        
        // Act
        final hasPending = await repository.hasPendingInvitation(groupId, toUserId);
        
        // Assert
        expect(hasPending, isTrue);
      });
      
      test('should stream received invitations', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Create invitations
        await fakeFirestore.collection('group_invitations').add({
          'groupId': 'group_1',
          'groupName': 'Group 1',
          'toUserId': userId,
          'groupEmoji': '🍳',
          'fromUserId': 'inviter_1',
          'fromUserName': 'Inviter 1',
          'status': 'pending',
          'sentAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
        });
        
        // Act
        final stream = repository.receivedInvitationsStream(userId);
        
        // Assert
        final invitations = await stream.first;
        expect(invitations.length, equals(1));
        expect(invitations.first.toUserId, equals(userId));
      });
    });
  });
}