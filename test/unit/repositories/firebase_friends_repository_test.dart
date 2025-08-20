/// Unit tests for FirebaseFriendsRepository
/// 
/// Tests the friends repository facade using mocked Firebase operations
/// to avoid FieldValue type casting issues.
library;

// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local mocks for sealed Firebase classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference<T> extends Mock implements CollectionReference<T> {}
class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}
class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {}
class MockQuery<T> extends Mock implements Query<T> {}
class MockQuerySnapshot<T> extends Mock implements QuerySnapshot<T> {}
class MockQueryDocumentSnapshot<T> extends Mock implements QueryDocumentSnapshot<T> {}
class MockWriteBatch extends Mock implements WriteBatch {}

// Fake classes for any() matching
class FakeFieldValue extends Fake implements FieldValue {}
class FakeFriendCategory extends Fake implements FriendCategory {}
class FakeGroupInvitation extends Fake implements GroupInvitation {}

void main() {
  group('FirebaseFriendsRepository', () {
    late FirebaseFriendsRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockFriendRequestsCollection;
    late MockCollectionReference<Map<String, dynamic>> mockUsersCollection;
    late MockCollectionReference<Map<String, dynamic>> mockPublicProfilesCollection;
    late MockCollectionReference<Map<String, dynamic>> mockGroupInvitationsCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocRef;
    late MockDocumentReference<Map<String, dynamic>> mockUserDocRef;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockWriteBatch mockBatch;
    late MockAuthRepository mockAuthRepository;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(FakeFieldValue());
      registerFallbackValue(DateTime.now());
      registerFallbackValue(<String, dynamic>{});
      registerFallbackValue(FakeFriendCategory());
      registerFallbackValue(FakeGroupInvitation());
    });
    
    setUp(() async {
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockFirestore = MockFirebaseFirestore();
      mockFriendRequestsCollection = MockCollectionReference<Map<String, dynamic>>();
      mockUsersCollection = MockCollectionReference<Map<String, dynamic>>();
      mockPublicProfilesCollection = MockCollectionReference<Map<String, dynamic>>();
      mockGroupInvitationsCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockUserDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockBatch = MockWriteBatch();
      mockAuthRepository = MockAuthRepository();
      
      // Configure auth state
      mockAuthRepository.setAuthState(userId: 'test_user_123');
      
      // Setup Firestore mocks
      when(() => mockFirestore.collection('friend_requests')).thenReturn(mockFriendRequestsCollection);
      when(() => mockFirestore.collection('users')).thenReturn(mockUsersCollection);
      when(() => mockFirestore.collection('public_profiles')).thenReturn(mockPublicProfilesCollection);
      when(() => mockFirestore.collection('group_invitations')).thenReturn(mockGroupInvitationsCollection);
      when(() => mockFriendRequestsCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockFriendRequestsCollection.add(any())).thenAnswer((_) async => mockDocRef);
      // Important: Use 'test_user_123' specifically for user doc reference
      when(() => mockUsersCollection.doc('test_user_123')).thenReturn(mockUserDocRef);
      when(() => mockUsersCollection.doc(any())).thenReturn(mockUserDocRef);
      when(() => mockPublicProfilesCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockGroupInvitationsCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockGroupInvitationsCollection.add(any())).thenAnswer((_) async => mockDocRef);
      when(() => mockDocRef.id).thenReturn('mock_doc_id');
      when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
      when(() => mockDocRef.set(any())).thenAnswer((_) async {});
      when(() => mockDocRef.update(any())).thenAnswer((_) async {});
      when(() => mockDocRef.delete()).thenAnswer((_) async {});
      when(() => mockUserDocRef.set(any(), any())).thenAnswer((_) async {});
      when(() => mockUserDocRef.set(any())).thenAnswer((_) async {});
      when(() => mockUserDocRef.update(any())).thenAnswer((_) async {});
      when(() => mockUserDocRef.collection(any())).thenReturn(mockFriendRequestsCollection);
      
      // Setup mock document snapshot for get operations
      final mockGetSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
      when(() => mockGetSnapshot.id).thenReturn('mock_doc_id');
      when(() => mockGetSnapshot.exists).thenReturn(true);
      when(() => mockGetSnapshot.data()).thenReturn(<String, dynamic>{
        'fromUserId': 'test_user_123',
        'toUserId': 'target_user_456',
        'status': 'pending',
        'sentAt': Timestamp.now(),
      });
      when(() => mockDocRef.get()).thenAnswer((_) async => mockGetSnapshot);
      when(() => mockUserDocRef.get()).thenAnswer((_) async => mockGetSnapshot);
      
      // Setup query mocks
      when(() => mockFriendRequestsCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockFriendRequestsCollection.where(any(), whereIn: any(named: 'whereIn')))
          .thenReturn(mockQuery);
      when(() => mockUsersCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockUsersCollection.where(any(), whereIn: any(named: 'whereIn')))
          .thenReturn(mockQuery);
      when(() => mockPublicProfilesCollection.where(any(), whereIn: any(named: 'whereIn')))
          .thenReturn(mockQuery);
      when(() => mockGroupInvitationsCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockGroupInvitationsCollection.where(any(), isLessThan: any(named: 'isLessThan')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where(any(), whereIn: any(named: 'whereIn')))
          .thenReturn(mockQuery);
      when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
          .thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(() => mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockQuerySnapshot));
      when(() => mockQuerySnapshot.docs).thenReturn([]);
      when(() => mockFirestore.batch()).thenReturn(mockBatch);
      when(() => mockBatch.commit()).thenAnswer((_) async {});
      
      // Create repository with dependency injection
      repository = FirebaseFriendsRepository(
        firestore: mockFirestore,
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
        const toUserId = 'target_user_456';
        const message = 'Let\'s be friends!';
        
        // Mock empty query result (no existing request)
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        
        // Act
        final success = await repository.sendFriendRequest(
          toUserId,
          message: message,
        );
        
        // Assert
        expect(success, isTrue);
        // The repository uses doc().set() not add()
        verify(() => mockDocRef.set(any())).called(1);
      });
      
      test('should not send duplicate friend request', () async {
        // Arrange
        const toUserId = 'target_user_456';
        
        // Mock existing request
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDoc.id).thenReturn('existing_request_id');
        when(() => mockDoc.data()).thenReturn({
          'fromUserId': 'test_user_123',
          'toUserId': toUserId,
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final success = await repository.sendFriendRequest(toUserId);
        
        // Assert
        expect(success, isFalse);
        verifyNever(() => mockFriendRequestsCollection.add(any()));
      });
      
      test('should accept friend request', () async {
        // Arrange
        const requestId = 'request_123';
        
        // Mock the friend request document
        final mockRequestSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockRequestSnapshot.id).thenReturn(requestId);
        when(() => mockRequestSnapshot.exists).thenReturn(true);
        when(() => mockRequestSnapshot.data()).thenReturn({
          'fromUserId': 'sender_456',
          'toUserId': 'test_user_123',
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockRequestSnapshot);
        
        // Mock user documents
        final mockUserSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockUserSnapshot.exists).thenReturn(true);
        when(() => mockUserSnapshot.data()).thenReturn({
          'uid': 'test_user_123',
        });
        when(() => mockUserDocRef.get()).thenAnswer((_) async => mockUserSnapshot);
        
        // Act
        final success = await repository.acceptFriendRequest(requestId);
        
        // Assert
        expect(success, isTrue);
        verify(() => mockDocRef.update(any())).called(1);
        verify(() => mockBatch.commit()).called(1);
      });
      
      test('should reject friend request', () async {
        // Arrange
        const requestId = 'request_123';
        
        // Mock the friend request document
        final mockRequestSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockRequestSnapshot.id).thenReturn(requestId);
        when(() => mockRequestSnapshot.exists).thenReturn(true);
        when(() => mockRequestSnapshot.data()).thenReturn({
          'fromUserId': 'sender_456',
          'toUserId': 'test_user_123',
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockRequestSnapshot);
        
        // Act
        final success = await repository.rejectFriendRequest(requestId);
        
        // Assert
        expect(success, isTrue);
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should cancel sent friend request', () async {
        // Arrange
        const requestId = 'request_123';
        
        // Mock the friend request document
        final mockRequestSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockRequestSnapshot.id).thenReturn(requestId);
        when(() => mockRequestSnapshot.exists).thenReturn(true);
        when(() => mockRequestSnapshot.data()).thenReturn({
          'fromUserId': 'test_user_123',
          'toUserId': 'target_user_456',
          'status': 'pending',
          'sentAt': Timestamp.now(),
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockRequestSnapshot);
        
        // Act
        final success = await repository.cancelFriendRequest(requestId);
        
        // Assert
        expect(success, isTrue);
        // Cancel updates the status, doesn't delete
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should get incoming friend requests', () async {
        // Arrange
        final mockDocs = [
          _createMockQueryDocumentSnapshot({
            'id': 'request_1',
            'fromUserId': 'user_1',
            'toUserId': 'test_user_123',
            'status': 'pending',
            'sentAt': Timestamp.now(),
          }),
          _createMockQueryDocumentSnapshot({
            'id': 'request_2',
            'fromUserId': 'user_2',
            'toUserId': 'test_user_123',
            'status': 'pending',
            'sentAt': Timestamp.now(),
          }),
        ];
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        
        // Act
        final requests = await repository.getIncomingRequests();
        
        // Assert
        expect(requests.length, equals(2));
        expect(requests.every((r) => r.toUserId == 'test_user_123'), isTrue);
      });
      
      test('should get sent friend requests', () async {
        // Arrange
        final mockDocs = [
          _createMockQueryDocumentSnapshot({
            'id': 'request_1',
            'fromUserId': 'test_user_123',
            'toUserId': 'user_1',
            'status': 'pending',
            'sentAt': Timestamp.now(),
          }),
        ];
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        
        // Act
        final requests = await repository.getSentRequests();
        
        // Assert
        expect(requests.length, equals(1));
        expect(requests.first.fromUserId, equals('test_user_123'));
      });
      
      test('should check if request exists between users', () async {
        // Arrange
        const userId1 = 'test_user_123';
        const userId2 = 'target_user_456';
        
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDoc.data()).thenReturn({
          'fromUserId': userId1,
          'toUserId': userId2,
          'status': 'pending',
        });
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final exists = await repository.requestExists(userId1, userId2);
        
        // Assert
        expect(exists, isTrue);
      });
    });
    
    group('Friend Relationships', () {
      test('should check if two users are friends', () async {
        // Arrange
        const userId1 = 'test_user_123';
        const userId2 = 'friend_456';
        
        // Mock user document with friends list
        final mockUserSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockUserSnapshot.exists).thenReturn(true);
        when(() => mockUserSnapshot.data()).thenReturn({
          'friendIds': ['friend_456', 'friend_789'],
        });
        when(() => mockUserDocRef.get()).thenAnswer((_) async => mockUserSnapshot);
        
        // Act
        final areFriends = await repository.areFriends(userId1, userId2);
        
        // Assert
        expect(areFriends, isTrue);
      });
      
      test('should fetch friend ids for user', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Mock the friends subcollection query
        final mockFriendsSubcollection = MockCollectionReference<Map<String, dynamic>>();
        when(() => mockUserDocRef.collection('friends')).thenReturn(mockFriendsSubcollection);
        
        // Setup friend documents in subcollection - the ID of the document is the friend ID
        final mockFriend1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockFriend1.id).thenReturn('friend_1');
        when(() => mockFriend1.data()).thenReturn({'friendId': 'friend_1'});
        when(() => mockFriend1.exists).thenReturn(true);
        
        final mockFriend2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockFriend2.id).thenReturn('friend_2');
        when(() => mockFriend2.data()).thenReturn({'friendId': 'friend_2'});
        when(() => mockFriend2.exists).thenReturn(true);
        
        final mockFriend3 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockFriend3.id).thenReturn('friend_3');
        when(() => mockFriend3.data()).thenReturn({'friendId': 'friend_3'});
        when(() => mockFriend3.exists).thenReturn(true);
        
        final mockFriendsSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => mockFriendsSnapshot.docs).thenReturn([mockFriend1, mockFriend2, mockFriend3]);
        when(() => mockFriendsSubcollection.get()).thenAnswer((_) async => mockFriendsSnapshot);
        
        // Act
        final friendIds = await repository.fetchFriendIds(userId);
        
        // Assert
        expect(friendIds.length, equals(3));
        expect(friendIds, contains('friend_1'));
        expect(friendIds, contains('friend_2'));
        expect(friendIds, contains('friend_3'));
      });
      
      test('should fetch friend profiles', () async {
        // Arrange
        final userIds = ['user_1', 'user_2'];
        
        final mockDocs = [
          _createMockQueryDocumentSnapshot({
            'uid': 'user_1',
            'displayName': 'User One',
            'email': 'user1@example.com',
            'joinedAt': Timestamp.now(),
            'lastActiveAt': Timestamp.now(),
          }),
          _createMockQueryDocumentSnapshot({
            'uid': 'user_2',
            'displayName': 'User Two',
            'email': 'user2@example.com',
            'joinedAt': Timestamp.now(),
            'lastActiveAt': Timestamp.now(),
          }),
        ];
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        
        // Act
        final profiles = await repository.fetchFriendProfiles(userIds);
        
        // Assert
        expect(profiles.length, equals(2));
        expect(profiles[0].displayName, equals('User One'));
        expect(profiles[1].displayName, equals('User Two'));
      });
      
      test('should remove friend', () async {
        // Arrange
        const friendUserId = 'friend_456';
        
        // Mock user documents
        final mockUserSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockUserSnapshot.exists).thenReturn(true);
        when(() => mockUserSnapshot.data()).thenReturn({
          'friendIds': ['friend_456', 'friend_789'],
        });
        when(() => mockUserDocRef.get()).thenAnswer((_) async => mockUserSnapshot);
        
        // Act
        final success = await repository.removeFriend(friendUserId);
        
        // Assert
        expect(success, isTrue);
        verify(() => mockBatch.commit()).called(1);
      });
      
      test('should add mutual friends', () async {
        // Arrange
        const userId1 = 'test_user_123';
        const userId2 = 'new_friend_456';
        
        // Act
        await repository.addMutualFriends(userId1, userId2);
        
        // Assert
        verify(() => mockBatch.commit()).called(1);
      });
      
      test('should remove mutual friends', () async {
        // Arrange
        const userId1 = 'test_user_123';
        const userId2 = 'ex_friend_456';
        
        // Act
        await repository.removeMutualFriends(userId1, userId2);
        
        // Assert
        verify(() => mockBatch.commit()).called(1);
      });
    });
    
    group('Friend Categories', () {
      test('should save friend category', () async {
        // Arrange
        const userId = 'test_user_123';
        final category = FriendCategory(
          id: 'category_1',
          ownerId: userId,
          name: 'Close Friends',
          description: 'My closest friends',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Mock categories subcollection
        final mockCategoriesCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockCategoryDocRef = MockDocumentReference<Map<String, dynamic>>();
        
        // Note: friendCategories is the actual collection name used by the repository
        when(() => mockUserDocRef.collection('friendCategories')).thenReturn(mockCategoriesCollection);
        when(() => mockCategoriesCollection.doc(any())).thenReturn(mockCategoryDocRef);
        when(() => mockCategoryDocRef.set(any())).thenAnswer((_) async {});
        
        // Act
        await repository.saveCategory(userId, category);
        
        // Assert
        verify(() => mockCategoryDocRef.set(any())).called(1);
      });
      
      test('should fetch categories for user', () async {
        // Arrange
        const userId = 'test_user_123';
        
        // Mock categories subcollection
        final mockCategoriesCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockCategoriesSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        
        // Note: friendCategories is the actual collection name used by the repository
        when(() => mockUserDocRef.collection('friendCategories')).thenReturn(mockCategoriesCollection);
        
        final mockDocs = [
          _createMockQueryDocumentSnapshot({
            'id': 'category_1',
            'ownerId': userId,
            'name': 'Family',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          }),
          _createMockQueryDocumentSnapshot({
            'id': 'category_2',
            'ownerId': userId,
            'name': 'Work',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          }),
        ];
        
        when(() => mockCategoriesCollection.get()).thenAnswer((_) async => mockCategoriesSnapshot);
        when(() => mockCategoriesSnapshot.docs).thenReturn(mockDocs);
        
        // Act
        final categories = await repository.fetchCategories(userId);
        
        // Assert
        expect(categories.length, equals(2));
        expect(categories[0].name, equals('Family'));
        expect(categories[1].name, equals('Work'));
      });
      
      test('should update category', () async {
        // Arrange
        const userId = 'test_user_123';
        const categoryId = 'category_1';
        final updateData = {'name': 'Updated Category Name'};
        
        // Mock categories subcollection
        final mockCategoriesCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockCategoryDocRef = MockDocumentReference<Map<String, dynamic>>();
        
        // Note: friendCategories is the actual collection name used by the repository
        when(() => mockUserDocRef.collection('friendCategories')).thenReturn(mockCategoriesCollection);
        when(() => mockCategoriesCollection.doc(categoryId)).thenReturn(mockCategoryDocRef);
        when(() => mockCategoryDocRef.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.updateCategory(userId, categoryId, updateData);
        
        // Assert
        verify(() => mockCategoryDocRef.update(any())).called(1);
      });
      
      test('should delete category', () async {
        // Arrange
        const userId = 'test_user_123';
        const categoryId = 'category_1';
        
        // Mock categories subcollection
        final mockCategoriesCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockCategoryDocRef = MockDocumentReference<Map<String, dynamic>>();
        
        // Note: friendCategories is the actual collection name used by the repository
        when(() => mockUserDocRef.collection('friendCategories')).thenReturn(mockCategoriesCollection);
        when(() => mockCategoriesCollection.doc(categoryId)).thenReturn(mockCategoryDocRef);
        when(() => mockCategoryDocRef.delete()).thenAnswer((_) async {});
        
        // Act
        await repository.deleteCategory(userId, categoryId);
        
        // Assert
        verify(() => mockCategoryDocRef.delete()).called(1);
      });
      
      test('should update category members only', () async {
        // Arrange
        const userId = 'test_user_123';
        const categoryId = 'category_1';
        final memberIds = ['friend_456', 'friend_789'];
        
        // Mock categories subcollection
        final mockCategoriesCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockCategoryDocRef = MockDocumentReference<Map<String, dynamic>>();
        
        // Note: friendCategories is the actual collection name used by the repository
        when(() => mockUserDocRef.collection('friendCategories')).thenReturn(mockCategoriesCollection);
        when(() => mockCategoriesCollection.doc(categoryId)).thenReturn(mockCategoryDocRef);
        when(() => mockCategoryDocRef.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.updateCategoryMembers(userId, categoryId, memberIds);
        
        // Assert
        verify(() => mockCategoryDocRef.update(any())).called(1);
      });
    });
    
    group('Group Invitations', () {
      test('should save new group invitation', () async {
        // Arrange
        final invitation = GroupInvitation(
          id: 'invitation_1',
          groupId: 'group_123',
          groupName: 'Test Group',
          groupEmoji: '🍕',
          fromUserId: 'test_user_123',
          fromUserName: 'Test User',
          toUserId: 'target_user_456',
          status: GroupInvitationStatus.pending,
          sentAt: DateTime.now(),
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        );
        
        // Act
        await repository.saveInvitation(invitation);
        
        // Assert
        // The repository uses doc().set() not add()
        verify(() => mockDocRef.set(any())).called(1);
      });
      
      test('should update invitation status', () async {
        // Arrange
        const invitationId = 'invitation_1';
        final updateData = {'status': 'accepted'};
        
        // Mock the document snapshot for getInvitation
        final mockInvitationSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockInvitationSnapshot.id).thenReturn(invitationId);
        when(() => mockInvitationSnapshot.exists).thenReturn(true);
        when(() => mockInvitationSnapshot.data()).thenReturn({
          'id': invitationId,
          'groupId': 'group_123',
          'groupName': 'Test Group',
          'groupEmoji': '🍕',
          'fromUserId': 'sender_456',
          'fromUserName': 'Sender Name',
          'toUserId': 'test_user_123',
          'status': 'pending',
          'sentAt': Timestamp.now(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockInvitationSnapshot);
        
        // Act
        await repository.updateInvitation(invitationId, updateData);
        
        // Assert
        verify(() => mockDocRef.update(any())).called(1);
      });
      
      test('should check for pending invitation', () async {
        // Arrange
        const groupId = 'group_123';
        const toUserId = 'target_user_456';
        
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDoc.data()).thenReturn({
          'groupId': groupId,
          'toUserId': toUserId,
          'status': 'pending',
        });
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        
        // Act
        final hasPending = await repository.hasPendingInvitation(groupId, toUserId);
        
        // Assert
        expect(hasPending, isTrue);
      });
      
      test('should stream received invitations', () async {
        // Arrange
        const userId = 'test_user_123';
        
        final mockDocs = [
          _createMockQueryDocumentSnapshot({
            'id': 'invitation_1',
            'groupId': 'group_123',
            'groupName': 'Test Group',
            'groupEmoji': '🍕',
            'fromUserId': 'sender_456',
            'fromUserName': 'Sender Name',
            'toUserId': userId,
            'status': 'pending',
            'sentAt': Timestamp.now(),
            'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
          }),
        ];
        
        when(() => mockQuerySnapshot.docs).thenReturn(mockDocs);
        
        // Act
        final stream = repository.receivedInvitationsStream(userId);
        
        // Assert
        await expectLater(
          stream,
          emits(isA<List<GroupInvitation>>()
            .having((list) => list.length, 'length', 1)
            .having((list) => list.first.toUserId, 'toUserId', userId)),
        );
      });
    });
  });
}

// Helper function to create mock query document snapshots
MockQueryDocumentSnapshot<Map<String, dynamic>> _createMockQueryDocumentSnapshot(
  Map<String, dynamic> data,
) {
  final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
  when(() => mockDoc.id).thenReturn(data['id'] ?? 'mock_id');
  when(() => mockDoc.data()).thenReturn(data);
  when(() => mockDoc.exists).thenReturn(true);
  return mockDoc;
}